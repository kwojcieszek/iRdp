import CoreGraphics
import Foundation

/// Tracks pressed mouse buttons and click counts for double and triple clicks.
public struct MouseState: Sendable {
    public private(set) var pressedButtons: Set<CGMouseButton> = []
    private var lastClick: (button: CGMouseButton, time: TimeInterval, location: CGPoint, count: Int)?
    public var doubleClickInterval: TimeInterval
    public var doubleClickDistance: Double = 4

    public init(doubleClickInterval: TimeInterval = 0.5) {
        self.doubleClickInterval = doubleClickInterval
    }

    /// Records a button press and returns its click count (1, 2, 3...).
    public mutating func press(_ button: CGMouseButton, at location: CGPoint, time: TimeInterval) -> Int {
        pressedButtons.insert(button)
        var count = 1
        if let last = lastClick, last.button == button, time - last.time <= doubleClickInterval,
           abs(last.location.x - location.x) <= doubleClickDistance, abs(last.location.y - location.y) <= doubleClickDistance {
            count = last.count + 1
        }
        lastClick = (button, time, location, count)
        return count
    }

    /// Records a release and returns the click count of the matching press.
    public mutating func release(_ button: CGMouseButton) -> Int {
        pressedButtons.remove(button)
        return lastClick?.button == button ? lastClick?.count ?? 1 : 1
    }

    /// The button whose drag event type should be used while moving.
    public var dragButton: CGMouseButton? {
        if pressedButtons.contains(.left) { return .left }
        if pressedButtons.contains(.right) { return .right }
        return pressedButtons.first
    }

    public mutating func releaseAll() -> [CGMouseButton] {
        defer { pressedButtons.removeAll() }
        return Array(pressedButtons)
    }
}
