import AppKit
import CoreGraphics

/// Lists the active displays.
public enum DisplayCatalog {
    public static func activeDisplays() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        let names = screenNames()
        return ids.prefix(Int(count)).map { id in
            let mode = CGDisplayCopyDisplayMode(id)
            return DisplayInfo(
                id: id,
                name: names[id] ?? "Display \(id)",
                bounds: CGDisplayBounds(id),
                pixelWidth: mode?.pixelWidth ?? CGDisplayPixelsWide(id),
                pixelHeight: mode?.pixelHeight ?? CGDisplayPixelsHigh(id),
                isMain: CGDisplayIsMain(id) != 0
            )
        }
    }

    /// The display with the given identifier, or the main display.
    public static func display(withID id: UInt32?) -> DisplayInfo? {
        let displays = activeDisplays()
        if let id, let match = displays.first(where: { $0.id == id }) { return match }
        return displays.first(where: \.isMain) ?? displays.first
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        let work = {
            var names: [CGDirectDisplayID: String] = [:]
            for screen in NSScreen.screens {
                if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                    names[number.uint32Value] = screen.localizedName
                }
            }
            return names
        }
        if Thread.isMainThread { return MainActor.assumeIsolated { work() } }
        return DispatchQueue.main.sync { work() }
    }
}
