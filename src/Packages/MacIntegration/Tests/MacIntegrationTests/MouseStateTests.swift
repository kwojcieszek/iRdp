import CoreGraphics
import Testing
@testable import MacIntegration

struct MouseStateTests {
    @Test func countsDoubleAndTripleClicks() {
        var mouse = MouseState(doubleClickInterval: 0.5)
        let point = CGPoint(x: 10, y: 10)
        var counts: [Int] = []
        counts.append(mouse.press(.left, at: point, time: 1.0))
        counts.append(mouse.release(.left))
        counts.append(mouse.press(.left, at: point, time: 1.2))
        counts.append(mouse.release(.left))
        counts.append(mouse.press(.left, at: point, time: 1.4))
        #expect(counts == [1, 1, 2, 2, 3])
    }

    @Test func slowOrDistantClicksStartOver() {
        var mouse = MouseState(doubleClickInterval: 0.5)
        _ = mouse.press(.left, at: .zero, time: 1.0)
        _ = mouse.release(.left)
        let slow = mouse.press(.left, at: .zero, time: 2.0)
        _ = mouse.release(.left)
        let distant = mouse.press(.left, at: CGPoint(x: 50, y: 0), time: 2.1)
        #expect(slow == 1)
        #expect(distant == 1)
    }

    @Test func reportsDragButton() {
        var mouse = MouseState()
        #expect(mouse.dragButton == nil)
        _ = mouse.press(.right, at: .zero, time: 0)
        #expect(mouse.dragButton == .right)
        let released = mouse.releaseAll()
        #expect(released == [.right])
        #expect(mouse.dragButton == nil)
    }
}
