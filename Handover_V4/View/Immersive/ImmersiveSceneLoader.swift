//
//  ImmersiveSceneLoader.swift
//  Handover_V4
//

import Foundation
import RealityKit
import RealityKitContent

enum ImmersiveSceneLoader {
    static func load() async throws -> Entity {
        let scene = try await Entity(
            named: ImmersiveConfiguration.sceneName,
            in: realityKitContentBundle
        )
        scene.position = .zero

        do {
            try await addAmbientAudio(to: scene)
        } catch {
            // The scene remains usable when optional ambient audio is unavailable.
            print("Failed to load immersive audio: \(error.localizedDescription)")
        }

        return scene
    }

    private static func addAmbientAudio(to scene: Entity) async throws {
        let resource = try await AudioFileResource(
            named: ImmersiveConfiguration.ambienceResourceName,
            configuration: .init(shouldLoop: true)
        )
        let audioEntity = Entity()
        audioEntity.components.set(AmbientAudioComponent())
        audioEntity.prepareAudio(resource).play()
        scene.addChild(audioEntity)
    }
}
