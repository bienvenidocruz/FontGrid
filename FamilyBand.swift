import SwiftUI
import AppKit

struct FamilyBand: View {
    let family: FontFamily
    let sampleText: String
    let pointSize: Double
    var currentMemberID: String? = nil
    var isStarred: Bool = false
    var onToggleStar: () -> Void = {}
    let onClose: () -> Void

    @State private var copiedName: String?

    private var sortedMembers: [FontMember] {
        family.members.sorted {
            if $0.weight != $1.weight { return $0.weight < $1.weight }
            return !$0.isItalic && $1.isItalic
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(family.name).font(.headline)
                Text("\(family.members.count) styles").foregroundStyle(.secondary)
                Spacer()
                if let copiedName {
                    Text("Copied \(copiedName)")
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Button(action: onToggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .foregroundStyle(isStarred ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(isStarred ? "Unstar" : "Star")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close (Esc)")
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ForEach(sortedMembers) { member in
                StyleRow(
                    member: member,
                    sampleText: sampleText.isEmpty ? family.name : sampleText,
                    pointSize: pointSize,
                    isCurrent: member.id == currentMemberID
                ) {
                    copy(member)
                }
                if member.id != sortedMembers.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.6))
        )
    }

    private func copy(_ member: FontMember) {
        let usePostScript = NSEvent.modifierFlags.contains(.option)
        let name = FontNameCopier.copy(member, familyName: family.name, postScript: usePostScript)

        withAnimation { copiedName = name }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedName == name {
                withAnimation { copiedName = nil }
            }
        }
    }
}

private struct StyleRow: View {
    let member: FontMember
    let sampleText: String
    let pointSize: Double
    let isCurrent: Bool
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(member.styleName)
                .font(.caption)
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(sampleText)
                .font(.custom(member.postScriptName, fixedSize: pointSize))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onCopy)
        .help("Click to copy name, Option-click for PostScript name")
    }
}
