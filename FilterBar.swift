import SwiftUI

enum FontFilter: String, CaseIterable, Identifiable {
    case installed, supportsText, starred
    case serif, sans, mono, script, handwritten
    case italics, large, variable
    case hideClutter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .installed: "Installed by me"
        case .supportsText: "Supports text"
        case .starred: "Starred"
        case .serif: "Serif"
        case .sans: "Sans"
        case .mono: "Mono"
        case .script: "Script"
        case .handwritten: "Handwritten"
        case .italics: "Italics"
        case .large: "Large families"
        case .variable: "Variable"
        case .hideClutter: "Hide clutter"
        }
    }

    /// These are OR'd together. Every other filter is AND'd.
    static let kindFilters: Set<FontFilter> = [.serif, .sans, .mono, .script, .handwritten]

    func matchesKind(_ family: FontFamily) -> Bool {
        switch self {
        case .serif: family.kind == .serif
        case .sans: family.kind == .sans
        case .mono: family.isMonospaced
        case .script: family.kind == .script
        case .handwritten: family.isHandwritten
        default: true
        }
    }
}

struct FilterBar: View {
    @Binding var active: Set<FontFilter>

    private static let groups: [[FontFilter]] = [
        [.installed, .supportsText, .starred],
        [.serif, .sans, .mono, .script, .handwritten],
        [.italics, .large, .variable],
        [.hideClutter]
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(Self.groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider()
                            .frame(height: 16)
                            .padding(.horizontal, 6)
                    }
                    ForEach(group) { filter in
                        Toggle(filter.label, isOn: binding(for: filter))
                            .toggleStyle(.button)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func binding(for filter: FontFilter) -> Binding<Bool> {
        Binding(
            get: { active.contains(filter) },
            set: { isOn in
                if isOn { active.insert(filter) } else { active.remove(filter) }
            }
        )
    }
}
