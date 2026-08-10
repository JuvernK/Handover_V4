//
//  OrbitLayoutController.swift
//  Handover_V4
//
//  Builds and presents the transient spatial-card carousel.
//

import RealityKit
import RealityKitContent
import UIKit

struct OrbitGeometry {
    let slots: [SIMD3<Float>]
    let patientInformationPosition: SIMD3<Float>
    let worldToLocal: simd_float4x4
}

enum OrbitLayoutController {
    static func geometry(in scene: Entity) -> OrbitGeometry {
        let markers = descendantsWithOrbitSlotComponent(in: scene)
        let cardMarkers = markers.compactMap { entity -> (Int, Entity)? in
            guard let component = entity.components[OrbitSlotComponent.self],
                  component.slotIndex >= 0 else {
                return nil
            }
            return (component.slotIndex, entity)
        }
        let markersByIndex = Dictionary(uniqueKeysWithValues: cardMarkers)
        let authoredSlots = (0..<ImmersiveConfiguration.orbitCardCount).compactMap {
            markersByIndex[$0]?.position(relativeTo: nil)
        }
        let hasCompleteAuthoredOrbit =
            authoredSlots.count == ImmersiveConfiguration.orbitCardCount
        let slots = hasCompleteAuthoredOrbit ? authoredSlots : fallbackSlots()
        let patientMarker = markers.first {
            $0.components[OrbitSlotComponent.self]?.slotIndex == -1
        }
        let patientPosition = patientMarker?.position(relativeTo: nil)
            ?? averagePosition(of: slots)
        let anchor = cardMarkers.first?.1.parent
        let anchorName = anchor?.name ?? "nil"
        let patientMarkerName = patientMarker?.name ?? "nil"

        orbitDebug(
            "Resolved \(markers.count) component-backed markers; "
                + "card indices=\(cardMarkers.map(\.0).sorted()), "
                + "anchor=\(anchorName)"
        )
        for (index, marker) in cardMarkers.sorted(by: { $0.0 < $1.0 }) {
            orbitDebug(
                "Slot \(index): entity=\(marker.name), "
                    + "local=\(marker.position), "
                    + "world=\(marker.position(relativeTo: nil))"
            )
        }
        orbitDebug(
            "Patient marker: entity=\(patientMarkerName), "
                + "world=\(patientPosition)"
        )

        if !hasCompleteAuthoredOrbit {
            let foundIndices = cardMarkers.map(\.0).sorted()
            print(
                "Orbit is missing authored slot components. "
                    + "Expected indices 0...7, found \(foundIndices)."
            )
        } else {
            orbitDebug("Using all eight authored Orbit slots (fallback disabled).")
        }

        return OrbitGeometry(
            slots: slots,
            patientInformationPosition: patientPosition,
            worldToLocal: anchor?.transformMatrix(relativeTo: nil).inverse
                ?? matrix_identity_float4x4
        )
    }

    private static func descendantsWithOrbitSlotComponent(in root: Entity) -> [Entity] {
        var matches: [Entity] = []
        var pending = [root]

        while let entity = pending.popLast() {
            if entity.components[OrbitSlotComponent.self] != nil {
                matches.append(entity)
            }
            pending.append(contentsOf: entity.children)
        }
        return matches
    }

    static func makeRing(for geometry: OrbitGeometry) -> Entity {
        let ring = Entity()
        ring.name = ImmersiveConfiguration.orbitRingEntityName

        let segmentCount = ImmersiveConfiguration.orbitRingSegmentCount
        let pathLength = Float(geometry.slots.count)
        let material = SimpleMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.42),
            isMetallic: true
        )

        for index in 0..<segmentCount {
            let start = sampleClosedPath(
                geometry.slots,
                parameter: Float(index) * pathLength / Float(segmentCount)
            )
            let end = sampleClosedPath(
                geometry.slots,
                parameter: Float(index + 1) * pathLength / Float(segmentCount)
            )
            let direction = end - start
            let segmentLength = simd_length(direction)
            guard segmentLength > 0.0001 else { continue }

            let segment = ModelEntity(
                mesh: .generateCylinder(
                    height: segmentLength * 1.04,
                    radius: ImmersiveConfiguration.orbitRingTubeRadius
                ),
                materials: [material]
            )
            segment.name = "OrbitRingSegment_\(index)"
            segment.position = (start + end) / 2
            segment.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: simd_normalize(direction)
            )
            segment.components.set(InputTargetComponent())
            segment.components.set(HoverEffectComponent())
            segment.components.set(
                CollisionComponent(
                    shapes: [
                        .generateBox(
                            size: SIMD3(
                                ImmersiveConfiguration.orbitCollisionWidth,
                                segmentLength * 1.04,
                                ImmersiveConfiguration.orbitCollisionWidth
                            )
                        )
                    ]
                )
            )
            ring.addChild(segment)
        }

        ring.isEnabled = false
        return ring
    }

    static func isRingEntity(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name == ImmersiveConfiguration.orbitRingEntityName {
                return true
            }
            candidate = current.parent
        }
        return false
    }

    static func apply(
        state: OrbitState,
        geometry: OrbitGeometry,
        orderedCardNames: [String],
        attachments: [Entity],
        homePositions: [ObjectIdentifier: SIMD3<Float>],
        savedPositions: [ClinicalCardID: SIMD3<Float>],
        baseScales: [ObjectIdentifier: SIMD3<Float>],
        ring: Entity?,
        animationDuration: TimeInterval
    ) {
        configureRing(ring, for: state)

        guard state.isActive else {
            restoreNormalLayout(
                attachments: attachments,
                homePositions: homePositions,
                savedPositions: savedPositions,
                baseScales: baseScales,
                animationDuration: animationDuration
            )
            return
        }

        positionPatientInformation(
            in: attachments,
            at: geometry.patientInformationPosition,
            baseScales: baseScales,
            animationDuration: animationDuration
        )

        let orderedAttachments = orderedAttachments(
            from: attachments,
            orderedCardNames: orderedCardNames
        )
        if animationDuration >= 0.4 {
            let discoveredNames = attachments.compactMap {
                $0.components[PointOfInterestRuntimeComponent.self]?.diagnosticName
            }
            orbitDebug(
                "Applying Orbit entry: state=\(state.interactionMode), "
                    + "attachments=\(discoveredNames), "
                    + "orderedClinicalCount=\(orderedAttachments.count)"
            )
        }
        guard !orderedAttachments.isEmpty, !geometry.slots.isEmpty else { return }

        let slotAngle = (2 * Float.pi) / Float(orderedAttachments.count)
        let slotOffset = state.rotation / slotAngle

        for (index, attachment) in orderedAttachments.enumerated() {
            guard let runtimeComponent = attachment.components[
                PointOfInterestRuntimeComponent.self
            ] else { continue }

            guard let cardID = runtimeComponent.cardID else { continue }
            let canonicalName = cardID.canonicalName
            let angleFromFocus = normalizedAngle(
                state.rotation + Float(index) * slotAngle
            )
            let isExpanded = state.expandedCardName == canonicalName
            let isFocused = state.focusedCardName == canonicalName
            let position = isExpanded
                ? geometry.slots[0]
                : sampleClosedPath(
                    geometry.slots,
                    parameter: Float(index) + slotOffset
                )

            if animationDuration >= 0.4 {
                let homePosition = homePositions[
                    runtimeComponent.attachmentTag
                ] ?? .zero
                orbitDebug(
                    "Card \(runtimeComponent.diagnosticName): index=\(index), "
                        + "target=\(position), home=\(homePosition)"
                )
            }

            let baseScale = baseScales[runtimeComponent.attachmentTag] ?? .one
            let distanceFromFocus = abs(angleFromFocus) / Float.pi
            let prominence = isFocused ? 1.06 : max(0.68, 1 - 0.32 * distanceFromFocus)
            let opacity: Float = state.expandedCardName == nil || isExpanded
                ? max(0.46, 1 - 0.54 * distanceFromFocus)
                : 0.16

            attachment.components.set(OpacityComponent(opacity: opacity))
            setInputEnabled(true, for: attachment)
            move(
                attachment,
                to: position,
                scale: baseScale * prominence,
                duration: animationDuration
            )
        }
    }

    private static func positionPatientInformation(
        in attachments: [Entity],
        at position: SIMD3<Float>,
        baseScales: [ObjectIdentifier: SIMD3<Float>],
        animationDuration: TimeInterval
    ) {
        guard let attachment = attachments.first(where: { entity in
            guard let component = entity.components[
                PointOfInterestRuntimeComponent.self
            ] else { return false }
            return component.cardID == .basicInformation
        }), let component = attachment.components[
            PointOfInterestRuntimeComponent.self
        ] else { return }

        attachment.components.set(OpacityComponent(opacity: 1))
        setInputEnabled(true, for: attachment)
        move(
            attachment,
            to: position,
            scale: baseScales[component.attachmentTag] ?? .one,
            duration: animationDuration
        )
    }

    private static func orderedAttachments(
        from attachments: [Entity],
        orderedCardNames: [String]
    ) -> [Entity] {
        let byName = Dictionary(uniqueKeysWithValues: attachments.compactMap { entity in
            entity.components[PointOfInterestRuntimeComponent.self].flatMap {
                $0.cardID.map { ($0.canonicalName, entity) }
            }
        })
        return orderedCardNames.compactMap { byName[$0] }
    }

    private static func restoreNormalLayout(
        attachments: [Entity],
        homePositions: [ObjectIdentifier: SIMD3<Float>],
        savedPositions: [ClinicalCardID: SIMD3<Float>],
        baseScales: [ObjectIdentifier: SIMD3<Float>],
        animationDuration: TimeInterval
    ) {
        for attachment in attachments {
            guard let runtimeComponent = attachment.components[
                PointOfInterestRuntimeComponent.self
            ] else {
                continue
            }
            let position = if let cardID = runtimeComponent.cardID {
                savedPositions[cardID]
                    ?? homePositions[runtimeComponent.attachmentTag]
            } else {
                attachment.position(relativeTo: nil)
            }
            guard let position else { continue }

            attachment.components.set(OpacityComponent(opacity: 1))
            setInputEnabled(true, for: attachment)
            move(
                attachment,
                to: position,
                scale: baseScales[runtimeComponent.attachmentTag] ?? .one,
                duration: animationDuration
            )
        }
    }

    private static func configureRing(_ ring: Entity?, for state: OrbitState) {
        guard let ring else { return }
        ring.isEnabled = state.isActive
        ring.components.set(
            OpacityComponent(
                opacity: state.expandedCardName == nil ? 1 : 0.45
            )
        )
        for segment in ring.children {
            setInputEnabled(state.isActive, for: segment)
        }
    }

    private static func setInputEnabled(_ isEnabled: Bool, for entity: Entity) {
        if isEnabled {
            entity.components.set(InputTargetComponent())
        } else {
            entity.components.remove(InputTargetComponent.self)
        }
    }

    private static func move(
        _ entity: Entity,
        to position: SIMD3<Float>,
        scale: SIMD3<Float>,
        duration: TimeInterval
    ) {
        let transform = Transform(
            scale: scale,
            rotation: entity.orientation,
            translation: position
        )
        if duration > 0 {
            entity.move(
                to: transform,
                relativeTo: nil,
                duration: duration,
                timingFunction: .easeInOut
            )
        } else {
            entity.setTransformMatrix(transform.matrix, relativeTo: nil)
        }
    }

    static func normalizedAngle(_ angle: Float) -> Float {
        atan2(sin(angle), cos(angle))
    }

    private static func sampleClosedPath(
        _ points: [SIMD3<Float>],
        parameter: Float
    ) -> SIMD3<Float> {
        guard points.count > 1 else { return points.first ?? .zero }

        let count = points.count
        let wrappedParameter = parameter.truncatingRemainder(dividingBy: Float(count))
        let positiveParameter = wrappedParameter >= 0
            ? wrappedParameter
            : wrappedParameter + Float(count)
        let index = Int(floor(positiveParameter))
        let t = positiveParameter - Float(index)
        let p0 = points[OrbitMath.positiveModulo(index - 1, count)]
        let p1 = points[index % count]
        let p2 = points[(index + 1) % count]
        let p3 = points[(index + 2) % count]
        let t2 = t * t
        let t3 = t2 * t

        let constantTerm = p1 * 2
        let linearTerm = (p2 - p0) * t
        let quadraticStart: SIMD3<Float> = p0 * 2 - p1 * 5
        let quadraticEnd: SIMD3<Float> = p2 * 4 - p3
        let quadraticCoefficient = quadraticStart + quadraticEnd
        let cubicStart: SIMD3<Float> = p1 * 3 - p0
        let cubicEnd: SIMD3<Float> = p3 - p2 * 3
        let cubicCoefficient = cubicStart + cubicEnd
        let quadraticTerm = quadraticCoefficient * t2
        let cubicTerm = cubicCoefficient * t3
        let result = constantTerm + linearTerm + quadraticTerm + cubicTerm
        return result * 0.5
    }

    private static func fallbackSlots() -> [SIMD3<Float>] {
        let center = ImmersiveConfiguration.orbitFallbackCenter
        let radius = ImmersiveConfiguration.orbitFallbackRadius
        return (0..<ImmersiveConfiguration.orbitCardCount).map { index in
            let angle = Float.pi / 2 + Float(index) * (2 * Float.pi / 8)
            return center + SIMD3(radius * cos(angle), 0, radius * sin(angle))
        }
    }

    private static func averagePosition(of points: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !points.isEmpty else { return .zero }
        return points.reduce(.zero, +) / Float(points.count)
    }


    private static func orbitDebug(_ message: String) {
#if DEBUG
        print("[OrbitDebug] \(message)")
#endif
    }
}
