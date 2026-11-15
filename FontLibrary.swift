import AppKit
import CoreText

enum FontKind: Hashable {
    case serif, sans, script, display, unknown
}

struct FontMember: Identifiable, Hashable {
    let postScriptName: String
    let styleName: String
    let weight: Int        // NSFontManager scale, 5 = regular
    let isItalic: Bool

    var id: String { postScriptName }
}

struct FontFamily: Identifiable, Hashable {
    let name: String
    let members: [FontMember]
    let regular: FontMember
    let kind: FontKind
    let isMonospaced: Bool
    let isVariable: Bool
    let isUserInstalled: Bool
    let isClutter: Bool
    let isHandwritten: Bool

    var hasItalic: Bool { members.contains { $0.isItalic } }
    var id: String { name }
}

enum FontLibrary {

    // MARK: Clutter rules. Edit freely.
    // Only applied to system fonts, never to fonts you installed.

    static let clutterNames: Set<String> = [
        "Apple Braille", "Apple Symbols", "Apple Color Emoji", "Bodoni Ornaments",
        "LastResort", "Symbol", "Webdings", "Wingdings", "Wingdings 2", "Wingdings 3",
        "Zapf Dingbats", "System Font"
    ]

    static let clutterPrefixes: [String] = [
        "Noto ", "Hiragino", "PingFang", "STIX", "Kohinoor", "Apple SD Gothic",
        "Apple LiGothic", "Apple LiSung", "Heiti", "Songti", "Kaiti", "Hannotate",
        "HanziPen", "Lantinghei", "Libian", "Wawati", "Weibei", "Xingkai", "Yuanti",
        "Yuppy", "Klee", "Toppan", "Tsukushi", "YuGothic", "YuMincho", "BiauKai",
        "LiHei", "LiSong", "GB18030", "Sangam"
    ]

    // MARK: Handwritten rules. Edit freely.

    static let handwrittenNames: Set<String> = [
        "Bradley Hand", "Chalkboard", "Chalkboard SE", "Chalkduster", "Comic Sans MS",
        "Marker Felt", "Noteworthy", "Segoe Print", "Ink Free", "Kristen ITC", "Mistral"
    ]

    /// Matched against the start of each word in the family name.
    static let handwrittenKeywords: [String] = [
        "hand", "brush", "marker", "chalk", "crayon", "pencil", "scrawl", "scribbl",
        "doodle", "sketch", "note", "felt", "signature", "autograph", "casual"
    ]

    // MARK: Loading

    static func loadFamilies() -> [FontFamily] {
        let manager = NSFontManager.shared

        let families: [FontFamily] = manager.availableFontFamilies.compactMap { familyName in
            guard !familyName.hasPrefix(".") else { return nil }
            guard let rawMembers = manager.availableMembers(ofFontFamily: familyName) else { return nil }

            // Each raw member is [postScriptName, styleName, weight, traits]
            let members: [FontMember] = rawMembers.compactMap { raw in
                guard raw.count >= 4,
                      let ps = raw[0] as? String,
                      let style = raw[1] as? String else { return nil }
                let weight = (raw[2] as? NSNumber)?.intValue ?? 5
                let traitsRaw = (raw[3] as? NSNumber)?.uintValue ?? 0
                let italic = NSFontTraitMask(rawValue: traitsRaw).contains(.italicFontMask)
                return FontMember(postScriptName: ps, styleName: style, weight: weight, isItalic: italic)
            }

            guard let regular = pickRegular(from: members) else { return nil }

            let ctFont = CTFontCreateWithName(regular.postScriptName as CFString, 12, nil)
            let traits = CTFontGetSymbolicTraits(ctFont).rawValue
            let classBits = (traits >> 28) & 0xF
            let isMono = (traits & (1 << 10)) != 0 || familyName.lowercased().contains("mono")
            let isVariable = ((CTFontCopyVariationAxes(ctFont) as? [Any])?.count ?? 0) > 0
            let userInstalled = isUserInstalled(ctFont)
            let clutter = !userInstalled && isClutter(name: familyName, font: ctFont, classBits: classBits)

            return FontFamily(
                name: familyName,
                members: members,
                regular: regular,
                kind: classify(classBits: classBits, name: familyName),
                isMonospaced: isMono,
                isVariable: isVariable,
                isUserInstalled: userInstalled,
                isClutter: clutter,
                isHandwritten: isHandwritten(name: familyName)
            )
        }

        return families.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Glyph coverage

    /// True if the font has a glyph for every non-whitespace character in text.
    static func covers(_ text: String, font: CTFont) -> Bool {
        let chars = Array(text.filter { !$0.isWhitespace }.utf16)
        guard !chars.isEmpty else { return true }
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        return CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
    }

    static func covers(_ text: String, postScriptName: String) -> Bool {
        covers(text, font: CTFontCreateWithName(postScriptName as CFString, 12, nil))
    }

    // MARK: Helpers

    /// Prefer an upright style literally named Regular, otherwise the upright
    /// style closest to normal weight, otherwise anything.
    private static func pickRegular(from members: [FontMember]) -> FontMember? {
        let upright = members.filter { !$0.isItalic }
        let pool = upright.isEmpty ? members : upright
        if let named = pool.first(where: { $0.styleName.lowercased() == "regular" }) {
            return named
        }
        return pool.min { abs($0.weight - 5) < abs($1.weight - 5) }
    }

    /// Fonts in ~/Library/Fonts or /Library/Fonts, which is where Font Book installs.
    private static func isUserInstalled(_ font: CTFont) -> Bool {
        guard let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL else { return false }
        let path = url.path
        return !path.hasPrefix("/System/") && path.contains("/Library/Fonts/")
    }

    /// Uses the font's own classification bits, then falls back to the name.
    /// Plenty of fonts leave the bits empty, so treat this as approximate.
    private static func classify(classBits: UInt32, name: String) -> FontKind {
        switch classBits {
        case 1...7: return .serif
        case 8: return .sans
        case 9: return .display
        case 10: return .script
        default: break
        }
        let lower = name.lowercased()
        if lower.contains("sans") || lower.contains("grotesk") || lower.contains("gothic") { return .sans }
        if lower.contains("serif") || lower.contains("antiqua") { return .serif }
        if lower.contains("script") || lower.contains("hand") { return .script }
        return .unknown
    }

    private static func isClutter(name: String, font: CTFont, classBits: UInt32) -> Bool {
        if clutterNames.contains(name) { return true }
        if clutterPrefixes.contains(where: { name.hasPrefix($0) || name.contains($0) }) { return true }
        if classBits == 12 { return true }           // symbolic
        return !covers("AaZz", font: font)           // no basic Latin = language-support font
    }

    private static func isHandwritten(name: String) -> Bool {
        if handwrittenNames.contains(name) { return true }
        let words = name.lowercased().split(whereSeparator: { !$0.isLetter })
        return words.contains { word in
            handwrittenKeywords.contains { word.hasPrefix($0) }
        }
    }
}
