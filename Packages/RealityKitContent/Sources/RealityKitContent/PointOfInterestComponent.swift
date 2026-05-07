import RealityKit

// Ensure you register this component in your app’s delegate using:
// PointOfInterestComponent.registerComponent()

// Design-time component
public struct PointOfInterestComponent: Component, Codable {
    // This is an example of adding a variable to the component.
    public var name: String = ""
    public var description: String = ""
    
    public init() {}
}
