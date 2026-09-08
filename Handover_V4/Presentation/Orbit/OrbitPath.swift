// Flow: OrbitGeometry -> OrbitPath -> carousel positions + ring drag projection.
import Foundation
import simd

/// Closed curve through authored control points, sampled independently of the clinical card count.
struct OrbitPath {
    let points: [SIMD3<Float>]
    let cardCount: Int

    func point(at position: Double) -> SIMD3<Float> {
        guard !points.isEmpty, position.isFinite, cardCount > 0 else { return .zero }
        let count = points.count
        let parameter = position.truncatingRemainder(dividingBy: Double(cardCount)) * Double(count) / Double(cardCount)
        let wrapped = parameter < 0 ? parameter + Double(count) : parameter
        let index = Int(floor(wrapped)) % count
        let t = Float(wrapped - floor(wrapped))
        let p0 = points[(index + count - 1) % count]
        let p1 = points[index]
        let p2 = points[(index + 1) % count]
        let p3 = points[(index + 2) % count]
        let a = p1 * 2
        let b = (p2 - p0) * t
        let quadraticStart: SIMD3<Float> = p0 * 2 - p1 * 5
        let quadraticEnd: SIMD3<Float> = p2 * 4 - p3
        let c = (quadraticStart + quadraticEnd) * (t * t)
        let cubicStart: SIMD3<Float> = p1 * 3 - p0
        let cubicEnd: SIMD3<Float> = p3 - p2 * 3
        let d = (cubicStart + cubicEnd) * (t * t * t)
        return (a + b + c + d) * 0.5
    }

    /// Project a scene-space gesture onto the same curve used by the visible ring.
    func position(nearest location: SIMD3<Float>) -> Double {
        let samples = 180
        var bestDistance = Float.infinity
        var bestPosition = 0.0
        for index in 0..<samples {
            let startPosition = Double(index) * Double(cardCount) / Double(samples)
            let endPosition = Double(index + 1) * Double(cardCount) / Double(samples)
            let start = point(at: startPosition)
            let direction = point(at: endPosition) - start
            let lengthSquared = simd_length_squared(direction)
            guard lengthSquared > 0.000001 else { continue }
            let t = max(0, min(1, simd_dot(location - start, direction) / lengthSquared))
            let distance = simd_length_squared(location - (start + t * direction))
            if distance < bestDistance {
                bestDistance = distance
                bestPosition = startPosition + Double(t) * (endPosition - startPosition)
            }
        }
        return bestPosition
    }
}

/// Unwraps drag movement across the closing seam and ignores small pinch jitter.
struct OrbitRingDrag {
    private var previousPosition: Double?
    private var startPosition = 0.0
    private var movement = 0.0
    private(set) var isDragging = false

    mutating func update(pathPosition: Double, position: Double) -> Double? {
        guard pathPosition.isFinite, position.isFinite else { return nil }
        guard let previousPosition else {
            self.previousPosition = pathPosition
            startPosition = position
            return nil
        }
        let count = Double(OrbitCard.allCases.count)
        var delta = pathPosition - previousPosition
        delta -= (delta / count).rounded() * count
        movement += delta
        self.previousPosition = pathPosition
        guard isDragging || abs(movement) > 0.07 else { return nil }
        isDragging = true
        return startPosition - movement
    }
}
