import SwiftUI

struct FontTile: View {
    let family: FontFamily
    let member: FontMember
    let sampleText: String
    let pointSize: Double
    var isSelected: Bool = false
    var isStarred: Bool = false
    var onToggleStar: () -> Void = {}

    @State private var isHovering = false

    private var displayText: String {
        sampleText.isEmpty ? family.name : sampleText
    }

    private var footerName: String {
        member.id == family.regular.id ? family.name : "\(family.name) \(member.styleName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayText)
                .font(.custom(member.postScriptName, fixedSize: pointSize))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(footerName)
                Spacer()
                Text("\(family.members.count)")
                Button(action: onToggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .foregroundStyle(isStarred ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(isStarred || isHovering ? 1 : 0)
                .help(isStarred ? "Unstar" : "Star")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
    }
}
