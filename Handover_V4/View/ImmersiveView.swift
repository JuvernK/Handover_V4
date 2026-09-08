//
//  ImmersiveView.swift
//  Handover_V4
//
//  Created by Juvern Khor on 29/4/2026.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(HandoverViewModel.self) var handoverViewModel

    @State private var attachmentsProvider = AttachmentsProvider()
    @State private var subscriptions = [EventSubscription]()
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var attachmentEntities: [Entity] = [] // Track attachment entities to update their collision shapes on resize

    // Query to find all entities that have been processed as a Point of Interest
    static let poiRuntimeQuery = EntityQuery(where: .has(PointOfInterestRuntimeComponent.self))

    var body: some View {
        RealityView { content, _ in
            do {
                let entity = try await Entity(named: "Immersive", in: realityKitContentBundle)
                content.add(entity)

                // (Currently changed to 0 )Offset the scene so it doesn't appear underneath the user or conflict with the main window.
                entity.position = SIMD3<Float>(0, 0, 0)

                // Listen for when points of interest are added
                subscriptions.append(content.subscribe(to: ComponentEvents.DidAdd.self, componentType: PointOfInterestComponent.self, { event in
                    createExpandAttachment(for: event.entity)
                }))

                // Setup Audio
                do {
                    let audioEntity = Entity()
                    let resource = try await AudioFileResource(
//                        named: "icu_ambience",
                        named: "icu_ambience",
                        configuration: .init(shouldLoop: true)
                    )
                    audioEntity.components.set(AmbientAudioComponent()) // For audio

                    let audioController = audioEntity.prepareAudio(resource)
                    audioController.play()

                    // Add audio entity to ICU entity
                    entity.addChild(audioEntity)
                } catch {
                    print("Failed to load audio: \(error.localizedDescription)")
                    print("Detailed: \(error)")
                }
            } catch {
                print("Error in RealityView's make: \(error)")
            }

        } update: {content, attachments in
            // Safely access the active RealityKit scene
            guard let scene = content.entities.first?.scene else { return }

            // Iterate over the entities with runtime query
            for entity in scene.performQuery(Self.poiRuntimeQuery) {
                guard let runtimeComponent = entity.components[PointOfInterestRuntimeComponent.self] else { continue }

                // Retrieve the RealityKit entity representation of the SwiftUI View using its tag
                if let attachmentEntity = attachments.entity(for: runtimeComponent.attachmentTag) {

                    // If it hasn't been added to the scene yet, add it to the ROOT content
                    if attachmentEntity.parent == nil {
                        // Add to root to bypass inherited scale (ICU has 0.01 scale, making it child will make attachment shrink heavily)
                        content.add(attachmentEntity)

                        // Feature: Add Billboard so the card automatically pivots to face the user
                        let billboard = BillboardComponent()
                        attachmentEntity.components.set(billboard)

                        // Feature: Draggable. First make the UI card interactable and allow collision
                        attachmentEntity.components.set(InputTargetComponent())

                        attachmentEntity.components.set(HoverEffectComponent())
                        attachmentEntity.components.set(runtimeComponent) // to use the id generated at runtime

                        // Track entities to dynamically resize their collision boxes later
                        Task { @MainActor in
                            if !attachmentEntities.contains(attachmentEntity) {
                                attachmentEntities.append(attachmentEntity)
                            }
                        }

                        // Poll for visual bounds instead of sleeping a fixed amount.
                        // Wait until SwiftUI actually calculates geometry. (for drag to work)
                        Task { @MainActor in
                            for _ in 0..<20 { // Try up to 2 seconds
                                try? await Task.sleep(for: .milliseconds(100))

                                let bounds = attachmentEntity.visualBounds(relativeTo: nil)

                                // Wait until SwiftUI has actually given the view a width and height
                                if bounds.extents.x > 0 && bounds.extents.y > 0 {

                                    // Create a custom bounding box with 5cm of physical depth (Z-axis)
                                    let thickShape = ShapeResource.generateBox(
                                        width: bounds.extents.x,
                                        height: bounds.extents.y,
                                        depth: 0.05
                                    )
                                    attachmentEntity.components.set(CollisionComponent(shapes: [thickShape]))

                                    //                                    print("DEBUG: Thick 3D collision generated successfully.")
                                    break
                                }
                            }
                        }

                        // Set the attachment's location to the last synced position if
                        // this participant joined after another user moved it.
                        let worldPos = entity.position(relativeTo: nil)
                        // Add 0m vertical offset so the expanded card sits above the anchor (zero offset for now as it seem better in Immersive space)
                        let offsetPosition = worldPos + SIMD3<Float>(0, 0, 0)
                        let syncedPosition = appModel.cardPositions[runtimeComponent.cardName]
                        attachmentEntity.setPosition(syncedPosition ?? offsetPosition, relativeTo: nil)

                        // Dashboard mode hides spatial cards; match current mode as soon as this attaches.
                        attachmentEntity.isEnabled = appModel.presentationMode != .dashboard
                    }
                }
            }

        } attachments: {
            ForEach(attachmentsProvider.sortedTagViewPairs, id: \.tag) { pair in
                Attachment(id: pair.tag) {
                    pair.view
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    //                    print("DEBUG: SpatialTapGesture fired!")

                    // Read the card name 3D entity component
                    if let runtimeComp = value.entity.components[PointOfInterestRuntimeComponent.self] {
                        let name = runtimeComp.cardName
                        //                        print("DEBUG: Found component! Toggling state for card: \(name)")

                        let currentState = appModel.cardStates[name] ?? true

                        // Toggle the SwiftUI state
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            appModel.setCardState(name: name, isExpanded: !currentState, syncChanges: true)
                        }
                    } else {
                        print("DEBUG ERROR: Tapped entity has no runtime component!")
                    }
                }
        )
        // Billboard to let card facing the user
        .gesture(
            DragGesture(minimumDistance: 10)
                .targetedToAnyEntity()
                .onChanged { value in
                    if dragStartPosition == nil {
                        dragStartPosition = value.entity.position
                        // value.entity.components.remove(BillboardComponent.self).      // Notes: If we remove the billboard during drag, the card will stop facing the user and stay fixed in its original orientation. This can make it easier to drag in a straight line, but may feel less natural.
                    }
                    guard let startPos = dragStartPosition else { return }

                    let translation = value.convert(value.translation3D, from: .local, to: .scene)
                    value.entity.position = startPos + translation
                }
                .onEnded { value in
                    dragStartPosition = nil
                    // value.entity.components.set(BillboardComponent())

                    // Broadcast the final position to other users
                    if let runtimeComp = value.entity.components[PointOfInterestRuntimeComponent.self] {
                        appModel.setCardPosition(name: runtimeComp.cardName, position: value.entity.position, syncChanges: true)
                    }
                }
        )
        .onChange(of: appModel.cardStates) { _, _ in
            // When a card expands, the view gets taller, but RealityKit's physical collision shape
            // stays the same. The capsule moves out of bounds and becomes untouchable.
            // We wait for the spring animation to settle, then resize the physical bounds.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600)) // Time for 0.5s SwiftUI spring animation
                for entity in attachmentEntities {
                    entity.generateCollisionShapes(recursive: true)
                }
            }
        }
        .onChange(of: appModel.presentationMode) { _, newMode in
            for entity in attachmentEntities {
                entity.isEnabled = newMode != .dashboard
            }
        }
        .onChange(of: appModel.cardPositions) { _, newPositions in
            for entity in attachmentEntities {
                guard let runtimeComp = entity.components[PointOfInterestRuntimeComponent.self] else { continue }

                // If there is a synced position for this specific card, update its physical location
                if let syncedPosition = newPositions[runtimeComp.cardName] {
                    // Animate the movement so it looks smooth when remote users drag it
                    entity.move(to: Transform(scale: entity.scale, rotation: entity.orientation, translation: syncedPosition), relativeTo: nil, duration: 0.3)
                }
            }
        }
    }

    private func createExpandAttachment(for entity: Entity) {
        // Skip if already processed
        guard entity.components[PointOfInterestRuntimeComponent.self] == nil else { return }
        guard let pointOfInterest = entity.components[PointOfInterestComponent.self] else { return }
        let tag: ObjectIdentifier = entity.id

        // We need a patient to render the cards. If none is loaded yet, bail —
        // the POI will simply have no attachment until a patient is selected.
        guard let patient = handoverViewModel.patient else {
            print("⚠️ POI '\(pointOfInterest.name)' detected but no patient loaded yet")
            return
        }

        let view = AnyView(
            SpatialCardView(poiName: pointOfInterest.name, patient: patient)
                .tag(tag)
        )

        entity.components[PointOfInterestRuntimeComponent.self] = PointOfInterestRuntimeComponent(
            attachmentTag: tag,
            cardName: pointOfInterest.name
        )

        attachmentsProvider.attachments[tag] = view
    }
}

#Preview(immersionStyle: .full) {
    let appModel = AppModel()
    ImmersiveView()
        .environment(appModel)
        .environment(appModel.handoverViewModel)
}
