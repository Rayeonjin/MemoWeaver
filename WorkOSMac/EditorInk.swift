import AppKit

// The default ink is always an appearance-aware AppKit color. Preset colors
// are semantic system colors; custom colors can be selected in the palette.
enum WorkOSInkPreset: String, CaseIterable, Identifiable {
    case automatic, red, orange, green, blue, purple, pink
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: return "기본 글자색 (자동)"
        case .red: return "빨강"
        case .orange: return "주황"
        case .green: return "초록"
        case .blue: return "파랑"
        case .purple: return "보라"
        case .pink: return "분홍"
        }
    }
    var color: NSColor {
        switch self {
        case .automatic: return .labelColor
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        }
    }
}

// A pasted Office/HTML document can carry hard-coded black (or white) font
// colors without a contrasting background. Convert only neutral, potentially
// invisible ink to a dynamic default; preserve colored highlights, readable
// foreground/background pairs, fonts, and all other attributes.
enum EditorInk {
    static func adapt(_ content: NSMutableAttributedString, range: NSRange) -> Bool {
        guard range.location != NSNotFound, range.location >= 0,
              range.length > 0, range.location <= content.length,
              range.length <= content.length - range.location else { return false }
        var replacements: [(NSRange, NSColor)] = []
        content.enumerateAttributes(in: range, options: []) { attrs, segment, _ in
            let ink = attrs[.foregroundColor] as? NSColor
            let background = attrs[.backgroundColor] as? NSColor
            let replacement: NSColor?
            if let ink, isDefaultLike(ink) {
                if let background, contrast(ink, background) >= 4.5 {
                    replacement = nil // e.g. a legitimate black-on-white Excel cell
                } else {
                    replacement = attrs[.link] != nil ? .linkColor : .labelColor
                }
            } else if ink == nil {
                replacement = attrs[.link] != nil ? .linkColor : .labelColor
            } else {
                replacement = nil // explicit colored text, including user-chosen accents
            }
            if let replacement { replacements.append((segment, replacement)) }
        }
        for (segment, color) in replacements {
            content.addAttribute(.foregroundColor, value: color, range: segment)
        }
        return !replacements.isEmpty
    }

    private static func isDefaultLike(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return false }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let upper = max(r, g, b), lower = min(r, g, b)
        // Avoid changing intentionally colored red/green/blue/yellow/purple ink.
        guard upper - lower < 0.105 else { return false }
        return upper < 0.32 || lower > 0.82
    }

    private static func contrast(_ foreground: NSColor, _ background: NSColor) -> CGFloat {
        guard let f = foreground.usingColorSpace(.deviceRGB),
              let b = background.usingColorSpace(.deviceRGB) else { return 0 }
        let a = luminance(f), c = luminance(b)
        return (max(a, c) + 0.05) / (min(a, c) + 0.05)
    }

    private static func luminance(_ color: NSColor) -> CGFloat {
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : CGFloat(pow(Double((component + 0.055) / 1.055), 2.4))
        }
        return 0.2126 * linear(color.redComponent) +
               0.7152 * linear(color.greenComponent) +
               0.0722 * linear(color.blueComponent)
    }

    static func customColor(hex: String) -> NSColor? {
        let source = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.count == 7, source.first == "#",
              let hexValue = UInt32(source.dropFirst(), radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((hexValue >> 16) & 255) / 255,
                       green: CGFloat((hexValue >> 8) & 255) / 255,
                       blue: CGFloat(hexValue & 255) / 255, alpha: 1)
    }
}
