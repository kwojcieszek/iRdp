import CoreGraphics
import Foundation
import RdpProtocol
import RdpServer

/// Injects remote keyboard and mouse input into macOS using Quartz events (needs Accessibility permission).
public final class CoreGraphicsInputInjector: InputSink, @unchecked Sendable {
    private let geometry: CaptureGeometry
    private let allowsKeyboard: Bool
    private let allowsMouse: Bool
    private let queue = DispatchQueue(label: "com.irdp.input", qos: .userInteractive)
    // State below is only accessed on `queue`.
    private var keyboard: KeyboardState
    private var mouse = MouseState()
    private var location: CGPoint
    private let source = CGEventSource(stateID: .hidSystemState)

    public init(geometry: CaptureGeometry, allowsKeyboard: Bool, allowsMouse: Bool, swapControlAndCommand: Bool) {
        self.geometry = geometry
        self.allowsKeyboard = allowsKeyboard
        self.allowsMouse = allowsMouse
        keyboard = KeyboardState(swapControlAndCommand: swapControlAndCommand)
        location = CGPoint(x: geometry.displayBounds.midX, y: geometry.displayBounds.midY)
    }

    public func handle(_ event: RdpInputEvent) {
        queue.async { self.process(event) }
    }

    public func releaseAll() {
        queue.async {
            for key in self.keyboard.releaseAll() { self.postKey(key, isDown: false) }
            for button in self.mouse.releaseAll() { self.postButton(button, isDown: false, clickCount: 1) }
        }
    }

    private func process(_ event: RdpInputEvent) {
        switch event {
        case .keyboard(let scancode, let isExtended, let isRelease):
            guard allowsKeyboard, let mapped = ScancodeKeyMap.keyCode(scancode: scancode, isExtended: isExtended) else { return }
            let key = keyboard.translate(mapped)
            guard keyboard.record(keyCode: key, isDown: !isRelease) else { return }
            postKey(key, isDown: !isRelease)
        case .unicodeKeyboard(let codeUnit, let isRelease):
            guard allowsKeyboard, let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: !isRelease) else { return }
            var unit = codeUnit
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
            event.flags = keyboard.flags
            event.post(tap: .cghidEventTap)
        case .synchronize(let toggles):
            guard allowsKeyboard else { return }
            for key in keyboard.releaseAll() { postKey(key, isDown: false) }
            keyboard.setCapsLock(toggles.contains(.capsLock))
        case .mouse(let flags, let x, let y):
            guard allowsMouse else { return }
            handleMouse(flags: flags, point: geometry.screenPoint(x: Int(x), y: Int(y)))
        case .extendedMouse(let flags, let x, let y):
            guard allowsMouse else { return }
            location = geometry.screenPoint(x: Int(x), y: Int(y))
            let button = CGMouseButton(rawValue: flags.contains(.xButton1) ? 3 : 4) ?? .center
            let isDown = flags.contains(.down)
            let count = isDown ? mouse.press(button, at: location, time: ProcessInfo.processInfo.systemUptime) : mouse.release(button)
            postButton(button, isDown: isDown, clickCount: count)
        case .relativeMouse(_, let deltaX, let deltaY):
            guard allowsMouse else { return }
            let bounds = geometry.displayBounds
            location = CGPoint(x: min(max(location.x + Double(deltaX), bounds.minX), bounds.maxX - 1), y: min(max(location.y + Double(deltaY), bounds.minY), bounds.maxY - 1))
            postMove()
        }
    }

    private func handleMouse(flags: PointerFlags, point: CGPoint) {
        if flags.contains(.wheel) {
            postScroll(vertical: flags.wheelRotation, horizontal: 0)
            return
        }
        if flags.contains(.horizontalWheel) {
            postScroll(vertical: 0, horizontal: -flags.wheelRotation)
            return
        }
        location = point
        let button: CGMouseButton? = if flags.contains(.button1) { .left } else if flags.contains(.button2) { .right } else if flags.contains(.button3) { .center } else { nil }
        guard let button else {
            postMove()
            return
        }
        let isDown = flags.contains(.down)
        let count = isDown ? mouse.press(button, at: point, time: ProcessInfo.processInfo.systemUptime) : mouse.release(button)
        postButton(button, isDown: isDown, clickCount: count)
    }

    private func postMove() {
        let type: CGEventType
        let button = mouse.dragButton ?? .left
        switch mouse.dragButton {
        case .left?: type = .leftMouseDragged
        case .right?: type = .rightMouseDragged
        case .some: type = .otherMouseDragged
        case nil: type = .mouseMoved
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: button) else { return }
        event.flags = keyboard.flags
        event.post(tap: .cghidEventTap)
    }

    private func postButton(_ button: CGMouseButton, isDown: Bool, clickCount: Int) {
        let type: CGEventType = switch button {
        case .left: isDown ? .leftMouseDown : .leftMouseUp
        case .right: isDown ? .rightMouseDown : .rightMouseUp
        default: isDown ? .otherMouseDown : .otherMouseUp
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        event.flags = keyboard.flags
        event.post(tap: .cghidEventTap)
    }

    private func postScroll(vertical: Int, horizontal: Int) {
        func pixels(_ rotation: Int) -> Int32 {
            guard rotation != 0 else { return 0 }
            let value = rotation / 3
            return Int32(value == 0 ? (rotation > 0 ? 1 : -1) : value)
        }
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: pixels(vertical), wheel2: pixels(horizontal), wheel3: 0) else { return }
        event.location = location
        event.flags = keyboard.flags
        event.post(tap: .cghidEventTap)
    }

    private func postKey(_ key: UInt16, isDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { return }
        if ModifierKey(keyCode: key) != nil { event.type = .flagsChanged }
        event.flags = keyboard.flags
        event.post(tap: .cghidEventTap)
    }
}
