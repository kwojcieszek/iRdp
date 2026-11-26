import CoreGraphics
import CoreImage
import CoreText
import Foundation

/// Draws a logon screen that looks like the macOS login window: blurred wallpaper, clock, round avatar,
/// the user's name and a capsule password field with an arrow button.
public final class LogonScreenRenderer {
    public let size: DesktopSize
    public let appearance: LogonScreenAppearance
    private let background: CGImage?
    private let now: () -> Date

    public init(size: DesktopSize, appearance: LogonScreenAppearance, now: @escaping () -> Date = Date.init) {
        self.size = size
        self.appearance = appearance
        self.now = now
        background = Self.blurredBackground(appearance.wallpaper ?? Self.abstractBackground(), size: size)
    }

    public func render(_ form: LogonForm) -> ScreenFrame {
        let width = size.width
        let height = size.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            draw(form, in: context)
        }
        return ScreenFrame(width: width, height: height, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    // MARK: - Layout

    private func draw(_ form: LogonForm, in context: CGContext) {
        let width = Double(size.width)
        let height = Double(size.height)
        drawBackground(in: context, width: width, height: height)
        // From here on y grows downwards.
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)

        let scale = max(min(height / 1080, width / 1920), 0.6)
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let date = now()
        drawCentered(Self.format(date, "EEEE, d MMMM"), y: height * 0.11, size: 24 * scale, weight: .semibold, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85), in: context, width: width)
        drawCentered(Self.format(date, "H:mm"), y: height * 0.11 + 108 * scale, size: 104 * scale, weight: .bold, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.82), in: context, width: width)
        drawBranding(in: context, width: width, height: height, scale: scale)

        // Frosted glass card.
        let cardWidth = 360 * scale
        let cardHeight = (form.acceptsInput ? 300 : 230) * scale
        let card = CGRect(x: (width - cardWidth) / 2, y: height * 0.62 - cardHeight / 2, width: cardWidth, height: cardHeight)
        drawGlass(card, cornerRadius: 26 * scale, in: context)

        let centerX = width / 2
        let avatarSize = 72 * scale
        var y = card.minY + 28 * scale
        drawPersonGlyph(CGRect(x: centerX - avatarSize / 2, y: y, width: avatarSize, height: avatarSize), in: context)
        y += avatarSize + 30 * scale
        drawCentered("Sign in to \(appearance.serverName ?? "this Mac")", y: y, size: 17 * scale, weight: .semibold, color: white, in: context, width: width)
        y += 18 * scale

        guard form.acceptsInput else {
            if let message = form.message {
                for (index, line) in Self.wrap(message, maximumCharacters: 46).enumerated() {
                    drawCentered(line, y: y + 24 * scale + Double(index) * 20 * scale, size: 13 * scale, weight: .medium, color: white, in: context, width: width)
                }
            }
            return
        }

        let fieldWidth = cardWidth - 64 * scale
        let fieldHeight = 32 * scale
        let nameField = CGRect(x: centerX - fieldWidth / 2, y: y + 14 * scale, width: fieldWidth, height: fieldHeight)
        drawCapsuleField(nameField, text: form.userName, placeholder: "User Name", isFocused: form.focusedField == .userName, showsArrow: false, scale: scale, in: context)
        let passwordField = CGRect(x: nameField.minX, y: nameField.maxY + 10 * scale, width: fieldWidth, height: fieldHeight)
        drawCapsuleField(passwordField, text: String(repeating: "•", count: form.password.count), placeholder: "Password", isFocused: form.focusedField == .password, showsArrow: true, scale: scale, in: context)
        let detail = form.isVerifying ? "Signing in…" : form.message ?? "Press Enter to sign in · Tab switches fields"
        let detailColor = form.message != nil && !form.isVerifying ? CGColor(srgbRed: 1, green: 0.82, blue: 0.78, alpha: 1) : CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7)
        drawCentered(detail, y: passwordField.maxY + 28 * scale, size: 12 * scale, weight: .medium, color: detailColor, in: context, width: width)
    }

    /// Translucent white card with a light border and a soft shadow, like macOS glass materials.
    private func drawGlass(_ rect: CGRect, cornerRadius: Double, in context: CGContext) {
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 12), blur: 40, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25))
        context.addPath(path)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.16))
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path)
        context.clip()
        let colors = [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.02)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
        context.setLineWidth(1)
        context.strokePath()
    }

    /// Generic account symbol (head and shoulders) instead of any personal picture.
    private func drawPersonGlyph(_ rect: CGRect, in context: CGContext) {
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22))
        context.fillEllipse(in: rect)
        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85))
        let head = rect.width * 0.36
        context.fillEllipse(in: CGRect(x: rect.midX - head / 2, y: rect.minY + rect.height * 0.2, width: head, height: head))
        let body = rect.width * 0.72
        context.fillEllipse(in: CGRect(x: rect.midX - body / 2, y: rect.minY + rect.height * 0.62, width: body, height: body * 0.8))
        context.restoreGState()
    }

    /// iRdp's own mark: a small badge with the app name and the computer name at the bottom.
    private func drawBranding(in context: CGContext, width: Double, height: Double, scale: Double) {
        let title = "iRdp"
        let subtitle = appearance.serverName.map { "Remote Desktop · \($0)" } ?? "Remote Desktop"
        let titleWidth = textWidth(title, size: 15 * scale, weight: .bold)
        let subtitleWidth = textWidth(subtitle, size: 13 * scale, weight: .medium)
        let badge = CGRect(x: 0, y: 0, width: 26 * scale, height: 26 * scale)
        let total = badge.width + 8 * scale + titleWidth + 10 * scale + subtitleWidth
        let left = (width - total) / 2
        let baseline = height - 40 * scale
        let badgeRect = CGRect(x: left, y: baseline - 19 * scale, width: badge.width, height: badge.height)
        context.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 7 * scale, cornerHeight: 7 * scale, transform: nil))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85))
        context.fillPath()
        // A small screen glyph inside the badge.
        let screen = badgeRect.insetBy(dx: 6 * scale, dy: 7 * scale).offsetBy(dx: 0, dy: -1 * scale)
        context.setStrokeColor(CGColor(srgbRed: 0.16, green: 0.25, blue: 0.47, alpha: 1))
        context.setLineWidth(1.6 * scale)
        context.stroke(screen)
        context.move(to: CGPoint(x: screen.midX - 3 * scale, y: screen.maxY + 3 * scale))
        context.addLine(to: CGPoint(x: screen.midX + 3 * scale, y: screen.maxY + 3 * scale))
        context.strokePath()
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9)
        drawText(title, at: CGPoint(x: badgeRect.maxX + 8 * scale, y: baseline), size: 15 * scale, weight: .bold, color: white, in: context)
        drawText(subtitle, at: CGPoint(x: badgeRect.maxX + 8 * scale + titleWidth + 10 * scale, y: baseline), size: 13 * scale, weight: .medium, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7), in: context)
    }


    // MARK: - Drawing

    private func drawBackground(in context: CGContext, width: Double, height: Double) {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if let background {
            context.draw(background, in: bounds)
        }
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12))
        context.fill(bounds)
    }

    private func drawCapsuleField(_ rect: CGRect, text: String, placeholder: String, isFocused: Bool, showsArrow: Bool, scale: Double, in context: CGContext) {
        let path = CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
        context.addPath(path)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: isFocused ? 0.32 : 0.2))
        context.fillPath()
        if isFocused {
            context.addPath(path)
            context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
            context.setLineWidth(1.5)
            context.strokePath()
        }
        let textX = rect.minX + 14 * scale
        let baseline = rect.midY + 5 * scale
        let isSecure = !text.isEmpty && text.allSatisfy { $0 == "•" }
        if isSecure {
            // Password bullets, larger than text like in the macOS password field.
            let dot = 6 * scale
            for index in 0..<min(text.count, Int((rect.width - 50 * scale) / (dot + 4 * scale))) {
                context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
                context.fillEllipse(in: CGRect(x: textX + Double(index) * (dot + 4 * scale), y: rect.midY - dot / 2, width: dot, height: dot))
            }
        } else if text.isEmpty {
            drawText(placeholder, at: CGPoint(x: textX, y: baseline), size: 13 * scale, weight: .regular, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6), in: context)
        } else {
            drawText(text, at: CGPoint(x: textX, y: baseline), size: 13 * scale, weight: .regular, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), in: context)
        }
        if isFocused {
            let contentWidth = isSecure ? Double(text.count) * 10 * scale - 2 * scale : textWidth(text, size: 13 * scale, weight: .regular)
            let caretX = textX + (text.isEmpty ? 0 : contentWidth) + 2
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
            context.fill(CGRect(x: caretX, y: rect.midY - 8 * scale, width: 1.5, height: 16 * scale))
        }
        guard showsArrow else { return }
        let diameter = rect.height - 8 * scale
        let circle = CGRect(x: rect.maxX - diameter - 4 * scale, y: rect.minY + 4 * scale, width: diameter, height: diameter)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: text.isEmpty ? 0.25 : 0.45))
        context.fillEllipse(in: circle)
        let arrow = CGMutablePath()
        let inset = diameter * 0.28
        arrow.move(to: CGPoint(x: circle.minX + inset, y: circle.midY))
        arrow.addLine(to: CGPoint(x: circle.maxX - inset, y: circle.midY))
        arrow.move(to: CGPoint(x: circle.midX + inset * 0.15, y: circle.minY + inset))
        arrow.addLine(to: CGPoint(x: circle.maxX - inset, y: circle.midY))
        arrow.addLine(to: CGPoint(x: circle.midX + inset * 0.15, y: circle.maxY - inset))
        context.addPath(arrow)
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.setLineWidth(1.8 * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    // MARK: - Text

    private static func font(size: Double, weight: CGFloat) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let traits = [kCTFontWeightTrait: weight] as CFDictionary
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), [kCTFontTraitsAttribute: traits] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    private func line(_ text: String, size: Double, weight: CGFloat, color: CGColor) -> CTLine? {
        let attributes = [kCTFontAttributeName: Self.font(size: size, weight: weight), kCTForegroundColorAttributeName: color] as CFDictionary
        guard let string = CFAttributedStringCreate(nil, text as CFString, attributes) else { return nil }
        return CTLineCreateWithAttributedString(string)
    }

    private func textWidth(_ text: String, size: Double, weight: CGFloat) -> Double {
        guard let line = line(text, size: size, weight: weight, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)) else { return 0 }
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    private func drawText(_ text: String, at point: CGPoint, size: Double, weight: CGFloat, color: CGColor, in context: CGContext) {
        guard let line = line(text, size: size, weight: weight, color: color) else { return }
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawCentered(_ text: String, y: Double, size: Double, weight: CGFloat, color: CGColor, in context: CGContext, width: Double) {
        drawText(text, at: CGPoint(x: (width - textWidth(text, size: size, weight: weight)) / 2, y: y), size: size, weight: weight, color: color, in: context)
    }

    private func drawText(_ text: String, centeredIn rect: CGRect, size: Double, weight: CGFloat, color: CGColor, in context: CGContext) {
        let width = textWidth(text, size: size, weight: weight)
        drawText(text, at: CGPoint(x: rect.midX - width / 2, y: rect.midY + size * 0.36), size: size, weight: weight, color: color, in: context)
    }

    // MARK: - Helpers

    static func format(_ date: Date, _ template: String) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// Scales the wallpaper to fill the screen and blurs it like the macOS login window.
    static func blurredBackground(_ wallpaper: CGImage?, size: DesktopSize) -> CGImage? {
        guard let wallpaper else { return nil }
        let target = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let image = CIImage(cgImage: wallpaper)
        let scale = max(target.width / image.extent.width, target.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offset = CGAffineTransform(translationX: (target.width - scaled.extent.width) / 2, y: (target.height - scaled.extent.height) / 2)
        let blurred = scaled.transformed(by: offset).clampedToExtent().applyingGaussianBlur(sigma: Double(size.width) / 60).cropped(to: target)
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(blurred, from: target)
    }

    /// A generic abstract picture of soft color blobs, so the logon screen shows nothing from the Mac.
    static func abstractBackground() -> CGImage? {
        let width = 480
        let height = 270
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0.12, green: 0.2, blue: 0.42, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let blobs: [(Double, Double, Double, CGColor)] = [
            (0.15, 0.8, 0.55, CGColor(srgbRed: 0.33, green: 0.45, blue: 0.95, alpha: 1)),
            (0.85, 0.75, 0.5, CGColor(srgbRed: 0.6, green: 0.33, blue: 0.85, alpha: 1)),
            (0.55, 0.15, 0.6, CGColor(srgbRed: 0.18, green: 0.62, blue: 0.85, alpha: 1)),
            (0.95, 0.1, 0.35, CGColor(srgbRed: 0.85, green: 0.42, blue: 0.62, alpha: 1)),
        ]
        for (x, y, radius, color) in blobs {
            let r = radius * Double(height)
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: x * Double(width) - r, y: y * Double(height) - r, width: r * 2, height: r * 2))
        }
        return context.makeImage()
    }

    static func wrap(_ text: String, maximumCharacters: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if !current.isEmpty, current.count + word.count + 1 > maximumCharacters {
                lines.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}

extension CGFloat {
    static let regular: CGFloat = 0
    static let medium: CGFloat = 0.23
    static let semibold: CGFloat = 0.3
    static let bold: CGFloat = 0.4
}
