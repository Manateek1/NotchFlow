import AppKit
import SwiftUI

public extension NSImage {
    /// Computes a vibrant dominant color from an album artwork image for dynamic island accents and glows.
    func extractDominantColor() -> NSColor? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = 16
        let height = 16
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &rawData,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var weightSum: Double = 0

        for i in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            let r = Double(rawData[i]) / 255.0
            let g = Double(rawData[i + 1]) / 255.0
            let b = Double(rawData[i + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
            let brightness = maxC

            // Favor saturated, mid-to-bright pixels so dark/white backgrounds don't wash out the accent
            let weight = 0.15 + (saturation * 2.5) * (brightness > 0.15 && brightness < 0.95 ? 1.2 : 0.3)
            totalR += r * weight
            totalG += g * weight
            totalB += b * weight
            weightSum += weight
        }

        guard weightSum > 0 else { return nil }
        var r = totalR / weightSum
        var g = totalG / weightSum
        var b = totalB / weightSum

        // Ensure minimum luminance so the color pops against a black Dynamic Island background
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if lum < 0.38 {
            let boost = 0.38 / max(0.05, lum)
            r = min(1.0, r * boost)
            g = min(1.0, g * boost)
            b = min(1.0, b * boost)
        }

        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
