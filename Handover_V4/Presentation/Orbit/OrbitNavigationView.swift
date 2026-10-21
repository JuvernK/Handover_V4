// Flow: LauncherView -> OrbitNavigationView -> AppModel.orbit -> immersive carousel.
import SwiftUI

/// Window controls provide an accessible alternative to dragging the immersive ring.
struct OrbitNavigationView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { appModel.orbit.step(-1) } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                Spacer()
                Button { appModel.orbit.step(1) } label: {
                    Label("Next", systemImage: "chevron.right")
                }
            }
            Text("\(appModel.orbit.state.frontIndex + 1) of \(OrbitCard.allCases.count) · \(appModel.orbit.state.frontCard.title)")
                .font(.subheadline)
            Slider(value: Binding(
                get: {
                    let count = Double(OrbitCard.allCases.count)
                    let position = appModel.orbit.state.position.truncatingRemainder(dividingBy: count)
                    return min(count - 1, position < 0 ? position + count : position)
                },
                set: { appModel.orbit.scrub(to: $0) }
            ), in: 0...Double(OrbitCard.allCases.count - 1)) { editing in
                if !editing { appModel.orbit.snap() }
            }
            .accessibilityLabel("Orbit position")
            .accessibilityValue(appModel.orbit.state.frontCard.title)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: appModel.orbit.step(1)
                case .decrement: appModel.orbit.step(-1)
                @unknown default: break
                }
            }
        }
    }
}
