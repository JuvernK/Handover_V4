//
//  ImmersiveView.swift
//  Handover_V4
//
//  Coordinates the RealityKit scene, spatial attachments, and shared state.
//

import SwiftUI
import RealityKit
import RealityKitContent

/// Mutable RealityKit bookkeeping that must not invalidate SwiftUI while a
/// `RealityView.update` closure is executing.
private final class ImmersiveAttachmentRegistry {
    var entities: [Entity] = []
    var homePositions: [String: SIMD3<Float>] = [:]
    var baseScales: [String: SIMD3<Float>] = [:]

    @discardableResult
    func register(_ entity: Entity) -> Bool {
        guard !entities.contains(entity) else { return false }
        entities.append(entity)
        return true
    }
}

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HandoverViewModel.self) private var handoverViewModel

    @State private var attachmentsProvider = AttachmentsProvider()
    @State private var subscriptions: [EventSubscription] = []
    @State private var attachmentRegistry = ImmersiveAttachmentRegistry()
    @State private var orbitGeometry: OrbitGeometry?
    @State private var orbitRing: Entity?
    @State private var sceneRoot: Entity?
    @State private var sourceHighlightController = SourceHighlightController()
    @State private var collisionResizeTask: Task<Void, Never>?

    var body: some View {
        RealityView { content, _ in
            do {
                let scene = try await ImmersiveSceneLoader.load()
                content.add(scene)

                let geometry = OrbitLayoutController.geometry(in: scene)
                let ring = OrbitLayoutController.makeRing(for: geometry)
                content.add(ring)
                orbitGeometry = geometry
                orbitRing = ring
                sceneRoot = scene
                appModel.orbitGestureWorldToLocal = geometry.worldToLocal
                sourceHighlightController.prepareOrganPlacards(in: scene)
                sourceHighlightController.update(
                    activeSections: activeSections(),
                    in: scene
                )
#if DEBUG
                print(
                    "[OrbitDebug] Immersive scene loaded; "
                        + "slotCount=\(geometry.slots.count), "
                        + "patientTarget=\(geometry.patientInformationPosition)"
                )
#endif

                let subscription = content.subscribe(
                    to: ComponentEvents.DidAdd.self,
                    componentType: PointOfInterestComponent.self
                ) { event in
                    ImmersiveAttachmentFactory.createAttachment(
                        for: event.entity,
                        patient: handoverViewModel.patient,
                        provider: attachmentsProvider
                    )
                }
                subscriptions.append(subscription)
            } catch {
                print("Failed to load the immersive scene: \(error.localizedDescription)")
            }
        } update: { content, attachments in
            guard let scene = content.entities.first?.scene else { return }

            for pointOfInterest in scene.performQuery(ImmersiveAttachmentConfigurator.runtimeQuery) {
                // The same runtime component is copied onto the attachment.
                // Only source POIs should drive attachment registration/home data.
                guard pointOfInterest.components[PointOfInterestComponent.self] != nil else {
                    continue
                }
                guard let runtimeComponent = pointOfInterest.components[
                    PointOfInterestRuntimeComponent.self
                ] else {
                    continue
                }

                guard let attachment = attachments.entity(
                    for: runtimeComponent.attachmentTag
                ) else {
                    continue
                }

                attachmentRegistry.homePositions[runtimeComponent.cardName] =
                    pointOfInterest.position(relativeTo: nil)
                attachmentRegistry.baseScales[runtimeComponent.cardName] = .one

                // Always recover the live attachment reference, even after it
                // has already been parented to the RealityView root.
                if attachmentRegistry.register(attachment) {
#if DEBUG
                    let parentName = attachment.parent?.name ?? "nil"
                    print(
                        "[OrbitDebug] Registered card \(runtimeComponent.cardName); "
                            + "parent=\(parentName), "
                            + "total=\(attachmentRegistry.entities.count)"
                    )
#endif
                }

                guard attachment.parent == nil else { continue }

                // Attach to the root to avoid inheriting the ICU scene's scale.
                content.add(attachment)
                ImmersiveAttachmentConfigurator.configure(
                    attachment,
                    anchoredAt: pointOfInterest,
                    runtimeComponent: runtimeComponent,
                    syncedPosition: appModel.cardPositions[runtimeComponent.cardName]
                )

#if DEBUG
                let homePosition =
                    attachmentRegistry.homePositions[runtimeComponent.cardName] ?? .zero
                print(
                    "[OrbitDebug] Configured card \(runtimeComponent.cardName); "
                        + "home=\(homePosition)"
                )
#endif
            }


            applyCurrentLayout()
        } attachments: {
            ForEach(attachmentsProvider.sortedTagViewPairs, id: \.tag) { pair in
                Attachment(id: pair.tag) {
                    pair.view
                        .environment(appModel)
                }
            }
        }
        .spatialCardGestures()
        .onChange(of: appModel.cardStates) { _, _ in
            updateSourceHighlights()
            scheduleCollisionShapeRegeneration()
        }
        .onChange(of: appModel.abbreviationSelections) { _, _ in
            scheduleCollisionShapeRegeneration()
        }
        .onChange(of: appModel.cardPositions) { _, newPositions in
            if appModel.orbitState.isActive {
                applyCurrentLayout()
            } else {
                ImmersiveAttachmentConfigurator.applySyncedPositions(
                    newPositions,
                    to: resolvedAttachmentEntities()
                )
            }
        }
        .onChange(of: appModel.orbitState) { oldState, newState in
#if DEBUG
            let focusedCardName = newState.focusedCardName ?? "nil"
            let expandedCardName = newState.expandedCardName ?? "nil"
            let liveAttachmentCount = resolvedAttachmentEntities().count
            print(
                "[OrbitDebug] Orbit state changed: "
                    + "\(oldState.interactionMode) -> \(newState.interactionMode), "
                    + "rotation=\(newState.rotation), "
                    + "focus=\(focusedCardName), "
                    + "expanded=\(expandedCardName), "
                    + "attachmentCount=\(liveAttachmentCount)"
            )
#endif
            applyCurrentLayout()
            updateSourceHighlights()

            if oldState.interactionMode != newState.interactionMode
                || oldState.expandedCardName != newState.expandedCardName {
                scheduleCollisionShapeRegeneration(reapplyLayout: true)
            }
        }
    }

    private func scheduleCollisionShapeRegeneration(
        reapplyLayout: Bool = false
    ) {
        collisionResizeTask?.cancel()
        collisionResizeTask = Task { @MainActor in
            try? await Task.sleep(
                for: ImmersiveConfiguration.collisionResizeDelay
            )
            guard !Task.isCancelled else { return }
            ImmersiveAttachmentConfigurator.regenerateCollisionShapes(
                for: resolvedAttachmentEntities()
            )
            if reapplyLayout {
                applyCurrentLayout()
            }
        }
    }

    private func applyCurrentLayout() {
        guard let orbitGeometry else { return }
        let liveAttachments = resolvedAttachmentEntities()
        OrbitLayoutController.apply(
            state: appModel.orbitState,
            geometry: orbitGeometry,
            orderedCardNames: appModel.orbitCardNames,
            attachments: liveAttachments,
            homePositions: attachmentRegistry.homePositions,
            savedPositions: appModel.cardPositions,
            baseScales: attachmentRegistry.baseScales,
            ring: orbitRing,
            animationDuration: appModel.orbitAnimationDuration
        )
    }

    /// The cards the user is currently attending to (see CONTEXT.md: Active Card).
    /// In Orbit, the settled front card — driven by `expandedCardName`, which is
    /// nil mid-spin, so highlighting suppresses during rotation and reappears on
    /// snap. In normal mode, every expanded card.
    private func activeSections() -> Set<SectionID> {
        let orbitState = appModel.orbitState
        if orbitState.isActive {
            guard let expanded = orbitState.expandedCardName,
                  let section = SectionID(rawValue: expanded) else {
                return []
            }
            return [section]
        }

        // Cards default to expanded (SpatialCardView uses `?? true`), so treat
        // every section as active unless it has been explicitly collapsed.
        var sections = Set(SectionID.allCases)
        for (cardName, isExpanded) in appModel.cardStates where !isExpanded {
            if let section = SectionID(
                rawValue: PointOfInterestMapper.normalize(cardName)
            ) {
                sections.remove(section)
            }
        }
        return sections
    }

    private func updateSourceHighlights() {
        guard let sceneRoot else { return }
        sourceHighlightController.update(activeSections: activeSections(), in: sceneRoot)
    }

    private func resolvedAttachmentEntities() -> [Entity] {
        guard let scene = orbitRing?.scene else {
            return attachmentRegistry.entities
        }

        let queriedAttachments = scene.performQuery(
            ImmersiveAttachmentConfigurator.runtimeQuery
        ).filter { entity in
            entity.components[PointOfInterestComponent.self] == nil
        }
        return queriedAttachments.isEmpty
            ? attachmentRegistry.entities
            : Array(queriedAttachments)
    }
}

#Preview(immersionStyle: .full) {
    let appModel = AppModel()
    ImmersiveView()
        .environment(appModel)
        .environment(appModel.handoverViewModel)
}
