// Flow: ImmersiveSceneController -> SourceOutlineController -> equipment silhouette shells.
import RealityKit
import UIKit

/// Caches front-culled shells without changing equipment materials or interaction components.
/// Standard depth testing lets nearer equipment and cards occlude the outlines naturally.
@MainActor
final class SourceOutlineController {
    private var shells: [String: [Entity]] = [:]

    /// Resolve every matching apparatus, including meshes nested below its named transform.
    func prepare(in root: Entity) {
        clear()
        let names = Set(OrbitCard.allCases.flatMap(\.equipmentNames))
        let entities = descendants(of: root)
        for name in names {
            let sources = entities.filter { $0.name == name }
            var models: [Entity] = []
            var seen = Set<ObjectIdentifier>()
            for source in sources {
                for entity in descendants(of: source) where entity.components[ModelComponent.self] != nil {
                    if seen.insert(entity.id).inserted { models.append(entity) }
                }
            }
            shells[name] = models.compactMap { makeShell(for: $0) }
            if shells[name]?.isEmpty != false {
                print("Source outline unavailable: \(name)")
            }
        }
    }

    func show(_ equipmentNames: Set<String>) {
        for (name, entities) in shells {
            for entity in entities { entity.isEnabled = equipmentNames.contains(name) }
        }
    }

    func clear() {
        for entity in shells.values.flatMap({ $0 }) { entity.removeFromParent() }
        shells.removeAll()
    }

    private func makeShell(for entity: Entity) -> Entity? {
        guard let model = entity.components[ModelComponent.self] else { return nil }
        let bounds = model.mesh.bounds
        let extents = bounds.extents
        let worldScale = entity.scale(relativeTo: nil)
        guard extents.x > 0, extents.y > 0, extents.z > 0 else { return nil }

        // Expand around the mesh's own center, accounting for the imported ICU's 0.01 scale.
        // The front faces are culled; the unchanged equipment hides the shell's interior.
        let thickness: Float = 0.003
        let padding = SIMD3<Float>(repeating: thickness * 2) / simd_abs(worldScale)
        let scale = SIMD3<Float>(repeating: 1) + padding / extents
        guard scale.x.isFinite, scale.y.isFinite, scale.z.isFinite else { return nil }
        var material = UnlitMaterial(color: .systemCyan)
        material.faceCulling = .front
        let shell = ModelEntity(mesh: model.mesh, materials: Array(repeating: material, count: max(1, model.materials.count)))
        shell.name = "SourceOutline_\(entity.name)"
        shell.scale = scale
        shell.position = bounds.center * (SIMD3<Float>(repeating: 1) - scale)
        shell.isEnabled = false
        entity.addChild(shell)
        return shell
    }

    private func descendants(of root: Entity) -> [Entity] {
        var result = [Entity]()
        var pending = [root]
        while let entity = pending.popLast() {
            result.append(entity)
            pending.append(contentsOf: entity.children)
        }
        return result
    }
}
