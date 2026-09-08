// Flow: AppModel + patient -> ImmersiveView -> ImmersiveSceneController + SpatialCardView.
import SwiftUI
import RealityKit
import RealityKitContent

/// Mounts the ICU and patient attachments, routing clinical taps separately from ring dragging.
struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HandoverViewModel.self) private var handoverViewModel
    @State private var runtime = ImmersiveSceneController()
    @State private var frameSubscription: EventSubscription?
    @State private var ringDrag = OrbitRingDrag()
    @State private var loadError: String?

    var body: some View {
        RealityView { content, _ in
            do {
                let room = try await Entity(named: "Immersive", in: realityKitContentBundle)
                content.add(room)
                content.add(runtime.prepare(room))
                frameSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated {
                        runtime.update(deltaTime: event.deltaTime, appModel: appModel)
                    }
                }
                do {
                    let audioEntity = Entity()
                    let resource = try await AudioFileResource(named: "icu_ambience", configuration: .init(shouldLoop: true))
                    audioEntity.components.set(AmbientAudioComponent())
                    room.addChild(audioEntity)
                    audioEntity.prepareAudio(resource).play()
                } catch {
                    print("ICU audio unavailable: \(error.localizedDescription)")
                }
            } catch {
                loadError = error.localizedDescription
            }
        } update: { content, attachments in
            for point in runtime.pointsOfInterest {
                guard let component = point.components[PointOfInterestRuntimeComponent.self],
                      let attachment = attachments.entity(for: component.attachmentTag) else { continue }
                if attachment.parent == nil {
                    content.add(attachment)
                    attachment.components.set(component)
                    runtime.register(attachment, name: component.cardName)
                }
            }
            runtime.update(deltaTime: 0, appModel: appModel)
        } attachments: {
            if let patient = handoverViewModel.patient {
                ForEach(runtime.pointsOfInterest, id: \.id) { point in
                    if let component = point.components[PointOfInterestRuntimeComponent.self] {
                        Attachment(id: component.attachmentTag) {
                            SpatialCardView(poiName: component.cardName, patient: patient)
                        }
                    }
                }
            }
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            guard !ringDrag.isDragging,
                  let component = value.entity.components[PointOfInterestRuntimeComponent.self],
                  component.cardName != "Basic_Information" else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if appModel.presentationMode == .orbit, let card = OrbitCard(rawValue: component.cardName) {
                    appModel.orbit.select(card)
                } else if appModel.presentationMode == .spatial {
                    appModel.setCardState(name: component.cardName,
                                          isExpanded: !appModel.isCardExpanded(component.cardName), syncChanges: true)
                }
            }
        })
        .simultaneousGesture(DragGesture(minimumDistance: 0).targetedToAnyEntity()
            .onChanged { value in
                guard appModel.presentationMode == .orbit, OrbitGeometry.isRing(value.entity) else { return }
                let point = value.convert(value.location3D, from: .local, to: .scene)
                if let position = ringDrag.update(point: point, position: appModel.orbit.state.position) {
                    appModel.orbit.scrub(to: position)
                }
            }
            .onEnded { _ in
                if ringDrag.isDragging && appModel.presentationMode == .orbit { appModel.orbit.snap() }
                ringDrag = OrbitRingDrag()
            })
        .onChange(of: appModel.presentationMode) { _, _ in ringDrag = OrbitRingDrag() }
        .onAppear {
            if appModel.presentationMode == .orbit { appModel.orbit.enter() }
        }
        .onDisappear {
            frameSubscription?.cancel()
            frameSubscription = nil
            appModel.orbit.leave()
            runtime.clear()
        }
        .alert("Unable to load ICU", isPresented: Binding(
            get: { loadError != nil }, set: { if !$0 { loadError = nil } }
        )) {
            Button("OK") { loadError = nil }
        } message: { Text(loadError ?? "") }
    }
}
