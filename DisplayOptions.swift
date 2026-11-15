import SwiftUI
import AppKit

enum DisplayWeight: String, CaseIterable, Identifiable {
    case thin, light, regular, medium, semibold, bold, black

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Target on NSFontManager's 0–15 weight scale
    var target: Int {
        switch self {
        case .thin: 3
        case .light: 4
        case .regular: 5
        case .medium: 6
        case .semibold: 8
        case .bold: 9
        case .black: 11
        }
    }
}

enum TextCase: String, CaseIterable, Identifiable {
    case asTyped, upper, lower, title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .asTyped: "As typed"
        case .upper: "UPPERCASE"
        case .lower: "lowercase"
        case .title: "Title Case"
        }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .asTyped: text
        case .upper: text.uppercased()
        case .lower: text.lowercased()
        case .title: text.capitalized
        }
    }
}

enum PreviewTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var help: String {
        switch self {
        case .system: "Match system"
        case .light: "Dark on light"
        case .dark: "Light on dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

extension FontFamily {
    /// The style closest to the requested weight. Falls back to upright
    /// styles when the family has no italics.
    func member(weight: DisplayWeight, italic: Bool) -> FontMember {
        if weight == .regular && !italic { return regular }
        let matching = members.filter { $0.isItalic == italic }
        let pool = matching.isEmpty ? members : matching
        return pool.min { abs($0.weight - weight.target) < abs($1.weight - weight.target) } ?? regular
    }
}

enum FontNameCopier {
    /// Copies the display name (or PostScript name) and returns what was copied.
    @discardableResult
    static func copy(_ member: FontMember, familyName: String, postScript: Bool) -> String {
        let name: String
        if postScript {
            name = member.postScriptName
        } else {
            name = NSFont(name: member.postScriptName, size: 12)?.displayName
                ?? "\(familyName) \(member.styleName)"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(name, forType: .string)
        return name
    }
}
