import AppKit
import ImageIO
import OpenDirectory
import RdpServer

/// Builds the logon screen look from the Mac: the wallpaper of the shared display and the account's picture and name.
public enum LogonAppearanceProvider {
    public static func appearance(userName: String?, displayName: String?, displayID: UInt32?, serverName: String?) -> LogonScreenAppearance {
        LogonScreenAppearance(
            wallpaper: wallpaper(displayID: displayID),
            defaultUserName: userName,
            displayName: displayName,
            avatar: userName.flatMap(accountPicture),
            serverName: serverName
        )
    }

    /// The desktop picture of the display (scaled down for speed); dynamic or video wallpapers that cannot be read return nil.
    public static func wallpaper(displayID: UInt32?) -> CGImage? {
        let lookup: () -> URL? = {
            let screens = NSScreen.screens
            let screen = screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID } ?? NSScreen.main ?? screens.first
            return screen.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        }
        let url = Thread.isMainThread ? MainActor.assumeIsolated { lookup() } : DispatchQueue.main.sync { lookup() }
        return url.flatMap { image(at: $0, maximumPixelSize: 1600) }
    }

    /// The account picture stored in the local directory (JPEGPhoto, or the Picture file).
    public static func accountPicture(userName: String) -> CGImage? {
        guard let node = try? ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeLocalNodes)),
              let record = try? node.record(withRecordType: kODRecordTypeUsers, name: userName, attributes: [kODAttributeTypeJPEGPhoto, kODAttributeTypePicture]) else { return nil }
        if let data = (try? record.values(forAttribute: kODAttributeTypeJPEGPhoto))?.first as? Data,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let picture = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return picture
        }
        if let path = (try? record.values(forAttribute: kODAttributeTypePicture))?.first as? String {
            return image(at: URL(fileURLWithPath: path), maximumPixelSize: 512)
        }
        return nil
    }

    static func image(at url: URL, maximumPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
