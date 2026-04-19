import SwiftUI

public extension Color {

    /// Decodes a `#RRGGBB` or `RRGGBB` hex string into a sRGB `Color`.
    ///
    /// - Parameter hex: A 6-digit hex string, optionally prefixed with `#`.
    /// - Returns: `nil` if the string doesn't parse to six hex digits.
    ///
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: value).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    /// Serializes this color (via its sRGB components) as `#RRGGBB`.
    ///
    /// Colors with non-sRGB color spaces are converted via the platform color system.
    ///
    var hexString: String {
        #if canImport(AppKit)
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(Double(ns.redComponent) * 255))
        let g = Int(round(Double(ns.greenComponent) * 255))
        let b = Int(round(Double(ns.blueComponent) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(round(Double(r) * 255)),
            Int(round(Double(g) * 255)),
            Int(round(Double(b) * 255))
        )
        #endif
    }
}

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
