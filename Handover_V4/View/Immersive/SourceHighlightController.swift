//
//  SourceHighlightController.swift
//  Handover_V4
//
//  Applies Source Highlights: when a card becomes the Active Card, its coupled
//  Source is emphasised — equipment meshes glow (emissive) in the card's identity
//  colour, organ Sources show a tinted SF-Symbol placard on an authored anchor.
//
//  Driven imperatively by ImmersiveView on Active-Card changes (not an ECS
//  System). See docs/adr/0001-source-coupling.md for why.
//

import SwiftUI
import RealityKit
import UIKit

/// Stateful because it must remember original materials to restore them, and
/// which entities are currently highlighted.
@MainActor
final class SourceHighlightController {
    /// A model entity we mutated, plus the materials it had before we did.
    private struct CachedModel {
        let entity: ModelEntity
        let originalMaterials: [any RealityKit.Material]
    }

    /// Equipment entity name -> the models we recoloured (for restore).
    private var glowingEquipment: [String: [CachedModel]] = [:]
    /// Equipment entity name -> the additive halo we added (emissive fallback).
    private var equipmentHalos: [String: Entity] = [:]
    /// Anchor name -> prebuilt organ placard entity (created once, toggled).
    private var organPlacards: [String: ModelEntity] = [:]

    // MARK: - Setup

    /// Builds the organ placards once, parented to their authored anchors and
    /// hidden. `update(activeSections:)` then only toggles their visibility.
    func prepareOrganPlacards(in scene: Entity) {
        for section in SectionID.allCases {
            guard case let .organ(symbol, anchorName) = section.clinicalSource,
                  organPlacards[anchorName] == nil else {
                continue
            }
            guard let anchor = scene.findEntity(named: anchorName) else {
                sourceDebug("organ anchor '\(anchorName)' not found; skipping placard")
                continue
            }
            guard let placard = makeOrganPlacard(
                symbol: symbol,
                color: UIColor(section.identityColor)
            ) else {
                sourceDebug("could not build organ placard for '\(symbol)'")
                continue
            }
            placard.isEnabled = false
            anchor.addChild(placard)
            organPlacards[anchorName] = placard
        }
    }

    // MARK: - Update

    /// Reconciles the current highlights with the set of Active Cards.
    func update(activeSections: Set<SectionID>, in scene: Entity) {
        var desiredEquipment: [String: UIColor] = [:]
        var activeAnchors: Set<String> = []

        for section in activeSections {
            let color = UIColor(section.identityColor)
            switch section.clinicalSource {
            case .equipment(let names):
                for name in names { desiredEquipment[name] = color }
            case .organ(_, let anchor):
                activeAnchors.insert(anchor)
            case .none:
                break
            }
        }

        applyEquipment(desiredEquipment, in: scene)
        applyOrgans(activeAnchors)
    }

    /// Restores every highlight (e.g. when the immersive space closes).
    func clearAll() {
        for name in Array(glowingEquipment.keys) { restoreEquipment(name) }
        for (name, halo) in equipmentHalos { halo.removeFromParent(); equipmentHalos[name] = nil }
        for placard in organPlacards.values { placard.isEnabled = false }
    }

    // MARK: - Equipment

    private func applyEquipment(_ desired: [String: UIColor], in scene: Entity) {
        // Restore anything no longer desired.
        for name in Array(glowingEquipment.keys) where desired[name] == nil {
            restoreEquipment(name)
        }
        for name in Array(equipmentHalos.keys) where desired[name] == nil {
            equipmentHalos[name]?.removeFromParent()
            equipmentHalos[name] = nil
        }

        // Apply anything newly desired (one section owns each name, so an
        // already-highlighted name needs no colour change).
        for (name, color) in desired {
            guard glowingEquipment[name] == nil, equipmentHalos[name] == nil else { continue }
            guard let entity = scene.findEntity(named: name) else {
                sourceDebug("equipment entity '\(name)' not found")
                continue
            }

            let models = modelEntities(in: entity)
            if models.isEmpty {
                let halo = makeHalo(around: entity, color: color)
                entity.addChild(halo)
                equipmentHalos[name] = halo
                sourceDebug("no ModelEntity under '\(name)'; using halo fallback")
            } else {
                glowingEquipment[name] = models.map { model in
                    let cached = CachedModel(
                        entity: model,
                        originalMaterials: model.model?.materials ?? []
                    )
                    applyEmissive(to: model, color: color)
                    return cached
                }
            }
        }
    }

    private func restoreEquipment(_ name: String) {
        guard let cached = glowingEquipment[name] else { return }
        for item in cached {
            guard var modelComponent = item.entity.model else { continue }
            modelComponent.materials = item.originalMaterials
            item.entity.model = modelComponent
        }
        glowingEquipment[name] = nil
    }

    private func applyEmissive(to model: ModelEntity, color: UIColor) {
        guard var modelComponent = model.model else { return }
        modelComponent.materials = modelComponent.materials.map { material in
            guard var pbr = material as? PhysicallyBasedMaterial else { return material }
            pbr.emissiveColor = .init(color: color)
            pbr.emissiveIntensity = ImmersiveConfiguration.sourceHighlightEmissiveIntensity
            return pbr
        }
        model.model = modelComponent
    }

    private func makeHalo(around entity: Entity, color: UIColor) -> ModelEntity {
        let bounds = entity.visualBounds(relativeTo: entity)
        let minExtent = ImmersiveConfiguration.sourceHaloMinimumExtent
        let size = SIMD3<Float>(
            max(bounds.extents.x, minExtent),
            max(bounds.extents.y, minExtent),
            max(bounds.extents.z, minExtent)
        )
        // SimpleMaterial with an alpha colour renders translucent here — the same
        // pattern the Orbit ring uses successfully.
        let material = SimpleMaterial(
            color: color.withAlphaComponent(ImmersiveConfiguration.sourceHaloOpacity),
            isMetallic: false
        )
        let halo = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        halo.name = ImmersiveConfiguration.sourceHaloEntityName
        halo.position = bounds.center
        return halo
    }

    // MARK: - Organs

    private func applyOrgans(_ activeAnchors: Set<String>) {
        for (anchor, placard) in organPlacards {
            placard.isEnabled = activeAnchors.contains(anchor)
        }
    }

    private func makeOrganPlacard(symbol: String, color: UIColor) -> ModelEntity? {
        guard let texture = Self.symbolTexture(symbol, color: color) else { return nil }

        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        // Read the symbol's alpha so the transparent background disappears.
        material.blending = .transparent(opacity: 1.0)

        let size = CGFloat(ImmersiveConfiguration.organPlacardSize)
        let placard = ModelEntity(
            mesh: .generatePlane(width: Float(size), height: Float(size)),
            materials: [material]
        )
        // Always face the viewer regardless of patient/anchor orientation.
        placard.components.set(BillboardComponent())
        return placard
    }

    /// Renders an SF Symbol, tinted, onto a transparent square as a texture.
    private static func symbolTexture(_ symbol: String, color: UIColor) -> TextureResource? {
        let side: CGFloat = 512
        let config = UIImage.SymbolConfiguration(pointSize: side * 0.6, weight: .bold)
        guard let symbolImage = UIImage(systemName: symbol, withConfiguration: config) else {
            return nil
        }
        let tinted = symbolImage.withTintColor(color, renderingMode: .alwaysOriginal)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let canvas = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            let fitted = tinted.size.width > 0 && tinted.size.height > 0
                ? tinted.size
                : canvas
            let scale = min(side / fitted.width, side / fitted.height) * 0.9
            let drawSize = CGSize(width: fitted.width * scale, height: fitted.height * scale)
            let origin = CGPoint(
                x: (side - drawSize.width) / 2,
                y: (side - drawSize.height) / 2
            )
            tinted.draw(in: CGRect(origin: origin, size: drawSize))
        }

        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource.generate(
            from: cgImage,
            options: .init(semantic: .color)
        )
    }

    // MARK: - Helpers

    private func modelEntities(in root: Entity) -> [ModelEntity] {
        var result: [ModelEntity] = []
        var pending: [Entity] = [root]
        while let entity = pending.popLast() {
            if let model = entity as? ModelEntity, model.model != nil {
                result.append(model)
            }
            pending.append(contentsOf: entity.children)
        }
        return result
    }

    private func sourceDebug(_ message: String) {
#if DEBUG
        print("[SourceHighlight] \(message)")
#endif
    }
}
