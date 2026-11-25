import CoreGraphics
import CoreText
import Foundation

/// Draws the logon screen into a BGRA screen frame.
public enum LogonScreenRenderer {
    public static func render(_ form: LogonForm, size: DesktopSize, serverName: String) -> ScreenFrame {
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
            draw(form, in: context, width: Double(width), height: Double(height), serverName: serverName)
        }
        return ScreenFrame(width: width, height: height, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    private static func draw(_ form: LogonForm, in context: CGContext, width: Double, height: Double, serverName: String) {
        // Flip so that y grows downwards like the screen.
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(srgbRed: 0.11, green: 0.13, blue: 0.18, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let panelWidth = min(420, width - 40)
        let panelHeight = form.acceptsInput ? 300.0 : 200.0
        let panel = CGRect(x: (width - panelWidth) / 2, y: (height - panelHeight) / 2, width: panelWidth, height: panelHeight)
        context.setFillColor(CGColor(srgbRed: 0.19, green: 0.21, blue: 0.27, alpha: 1))
        context.addPath(CGPath(roundedRect: panel, cornerWidth: 14, cornerHeight: 14, transform: nil))
        context.fillPath()

        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let secondary = CGColor(srgbRed: 0.72, green: 0.75, blue: 0.82, alpha: 1)
        let left = panel.minX + 30
        drawText("iRdp", at: CGPoint(x: left, y: panel.minY + 48), size: 26, bold: true, color: white, in: context)
        drawText(serverName, at: CGPoint(x: left, y: panel.minY + 74), size: 14, bold: false, color: secondary, in: context)

        var y = panel.minY + 100
        if form.acceptsInput {
            let fieldWidth = panelWidth - 60
            drawField(label: "User name", value: form.userName, isFocused: form.focusedField == .userName, rect: CGRect(x: left, y: y + 18, width: fieldWidth, height: 32), in: context)
            y += 64
            drawField(label: "Password", value: String(repeating: "•", count: form.password.count), isFocused: form.focusedField == .password, rect: CGRect(x: left, y: y + 18, width: fieldWidth, height: 32), in: context)
            y += 70
            let hint = form.isVerifying ? "Signing in…" : "Press Enter to sign in, Tab to switch fields"
            drawText(hint, at: CGPoint(x: left, y: y + 14), size: 12, bold: false, color: secondary, in: context)
            y += 24
        }
        if let message = form.message {
            let color = CGColor(srgbRed: 1, green: 0.62, blue: 0.4, alpha: 1)
            for (index, line) in wrap(message, maximumCharacters: Int((panelWidth - 60) / 7.5)).enumerated() {
                drawText(line, at: CGPoint(x: left, y: y + 16 + Double(index) * 18), size: 13, bold: false, color: color, in: context)
            }
        }
    }

    private static func drawField(label: String, value: String, isFocused: Bool, rect: CGRect, in context: CGContext) {
        drawText(label, at: CGPoint(x: rect.minX, y: rect.minY - 6), size: 12, bold: false, color: CGColor(srgbRed: 0.72, green: 0.75, blue: 0.82, alpha: 1), in: context)
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.11, blue: 0.15, alpha: 1))
        context.fill(rect)
        context.setStrokeColor(isFocused ? CGColor(srgbRed: 0.35, green: 0.6, blue: 1, alpha: 1) : CGColor(srgbRed: 0.35, green: 0.38, blue: 0.45, alpha: 1))
        context.setLineWidth(isFocused ? 2 : 1)
        context.stroke(rect)
        let text = isFocused ? value + "|" : value
        drawText(text, at: CGPoint(x: rect.minX + 8, y: rect.midY + 5), size: 15, bold: false, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), in: context)
    }

    private static func drawText(_ text: String, at point: CGPoint, size: Double, bold: Bool, color: CGColor, in context: CGContext) {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
        guard let string = CFAttributedStringCreate(nil, text as CFString, attributes) else { return }
        let line = CTLineCreateWithAttributedString(string)
        context.saveGState()
        // Text must be drawn unflipped: undo the flip locally around the baseline.
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
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
