import SwiftUI
import AppKit

struct GridLayout {
    let columns: Int
    let tileWidth: CGFloat

    init(availableWidth: CGFloat, pointSize: Double, spacing: CGFloat) {
        // Tile width tracks type size. Tweak the 160 floor and 5.5 multiplier to taste.
        let minTile = CGFloat(max(160, pointSize * 5.5))
        let cols = max(1, Int((availableWidth + spacing) / (minTile + spacing)))
        columns = cols
        tileWidth = max(0, (availableWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols))
    }
}

struct ContentView: View {
    @State private var families: [FontFamily] = FontLibrary.loadFamilies()

    // Remembered between launches
    @AppStorage("sampleText") private var sampleText = "Hello World"
    @AppStorage("pointSize") private var pointSize: Double = 36
    @AppStorage("displayWeight") private var displayWeight: DisplayWeight = .regular
    @AppStorage("displayItalic") private var displayItalic = false
    @AppStorage("textCase") private var textCase: TextCase = .asTyped
    @AppStorage("previewTheme") private var theme: PreviewTheme = .system
    @AppStorage("starredFamilies") private var starredRaw = ""

    @State private var searchText = ""
    @State private var selectedFamilyID: String?
    @State private var isBandOpen = false
    @State private var activeFilters: Set<FontFilter> = [.hideClutter]
    @State private var unsupported: Set<String> = []
    @State private var columns = 1
    @State private var copiedMessage: String?
    @FocusState private var gridFocused: Bool

    private let spacing: CGFloat = 12
    private let padding: CGFloat = 16

    // MARK: Derived

    private var displayText: String {
        textCase.apply(sampleText)
    }

    private var starred: Set<String> {
        Set(starredRaw.split(separator: "\n").map(String.init))
    }

    private var visibleFamilies: [FontFamily] {
        let kinds = activeFilters.intersection(FontFilter.kindFilters)
        let starredSet = starred
        return families.filter { passesFilters($0, kinds: kinds, starredSet: starredSet) }
    }

    private func passesFilters(_ f: FontFamily, kinds: Set<FontFilter>, starredSet: Set<String>) -> Bool {
        if !searchText.isEmpty && !f.name.localizedCaseInsensitiveContains(searchText) { return false }
        if activeFilters.contains(.hideClutter) && f.isClutter { return false }
        if activeFilters.contains(.installed) && !f.isUserInstalled { return false }
        if activeFilters.contains(.supportsText) && unsupported.contains(f.id) { return false }
        if activeFilters.contains(.starred) && !starredSet.contains(f.id) { return false }
        if activeFilters.contains(.italics) && !f.hasItalic { return false }
        if activeFilters.contains(.large) && f.members.count < 6 { return false }
        if activeFilters.contains(.variable) && !f.isVariable { return false }
        if !kinds.isEmpty && !kinds.contains(where: { $0.matchesKind(f) }) { return false }
        return true
    }

    // MARK: Body

    var body: some View {
        let visible = visibleFamilies

        VStack(spacing: 0) {
            header
            optionsBar(visibleCount: visible.count)
            FilterBar(active: $activeFilters)
            Divider()
            content(visible)
        }
        .onChange(of: displayText, initial: true) { _, newText in
            updateUnsupported(for: newText)
        }
        .onChange(of: theme, initial: true) { _, newTheme in
            NSApp.appearance = newTheme.appearance
        }
    }

    @ViewBuilder
    private func content(_ visible: [FontFamily]) -> some View {
        if visible.isEmpty {
            ContentUnavailableView(
                "No fonts match",
                systemImage: "textformat",
                description: Text("Try turning off a filter or clearing the search.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            grid(visible)
        }
    }

    // MARK: Grid

    private func grid(_ visible: [FontFamily]) -> some View {
        GeometryReader { geo in
            let layout = GridLayout(
                availableWidth: geo.size.width - padding * 2,
                pointSize: pointSize,
                spacing: spacing
            )
            ScrollViewReader { proxy in
                ScrollView {
                    gridRows(visible, layout: layout)
                        .padding(padding)
                }
                .focusable()
                .focused($gridFocused)
                .focusEffectDisabled()
                .onKeyPress(phases: [.down, .repeat]) { press in
                    handleKey(press)
                }
                .onChange(of: layout.columns, initial: true) { _, cols in
                    columns = cols
                }
                .onChange(of: selectedFamilyID) { _, _ in
                    scrollToSelection(in: visible, columns: layout.columns, proxy: proxy)
                }
                .onChange(of: isBandOpen) { _, _ in
                    scrollToSelection(in: visible, columns: layout.columns, proxy: proxy)
                }
            }
        }
    }

    private func gridRows(_ visible: [FontFamily], layout: GridLayout) -> some View {
        let cols = layout.columns
        let rowCount = (visible.count + cols - 1) / cols
        let starredSet = starred

        return LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                let start = row * cols
                let end = min(start + cols, visible.count)
                gridRow(Array(visible[start..<end]), layout: layout, starredSet: starredSet)
                    .id(row)
            }
        }
    }

    // One container per row: the tiles, plus the band if open
    private func gridRow(_ rowFamilies: [FontFamily], layout: GridLayout, starredSet: Set<String>) -> some View {
        let selected: FontFamily? = isBandOpen
            ? rowFamilies.first(where: { $0.id == selectedFamilyID })
            : nil

        return VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(rowFamilies) { family in
                    tile(for: family, width: layout.tileWidth, starredSet: starredSet)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if let selected {
                band(for: selected, starredSet: starredSet)
            }
        }
    }

    private func tile(for family: FontFamily, width: CGFloat, starredSet: Set<String>) -> some View {
        FontTile(
            family: family,
            member: family.member(weight: displayWeight, italic: displayItalic),
            sampleText: displayText,
            pointSize: pointSize,
            isSelected: family.id == selectedFamilyID,
            isStarred: starredSet.contains(family.id),
            onToggleStar: { toggleStar(family) }
        )
        .frame(width: width)
        .onTapGesture { select(family) }
    }

    private func band(for family: FontFamily, starredSet: Set<String>) -> some View {
        FamilyBand(
            family: family,
            sampleText: displayText,
            pointSize: pointSize,
            currentMemberID: family.member(weight: displayWeight, italic: displayItalic).id,
            isStarred: starredSet.contains(family.id),
            onToggleStar: { toggleStar(family) },
            onClose: closeBand
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            TextField("Type something", text: $sampleText)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            Slider(value: $pointSize, in: 8...200)
                .frame(width: 200)

            Text("\(Int(pointSize)) pt")
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)

            // Invisible button so Esc closes the band
            Button("Close", action: closeBand)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, padding)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func optionsBar(visibleCount: Int) -> some View {
        HStack(spacing: 12) {
            TextField("Search families", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)

            weightPicker

            Toggle("Italic", isOn: $displayItalic)
                .toggleStyle(.button)

            casePicker
            themePicker

            Spacer()

            if let copiedMessage {
                Text("Copied \(copiedMessage)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Text("\(visibleCount) of \(families.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, padding)
        .padding(.bottom, 2)
    }

    private var weightPicker: some View {
        Picker("Weight", selection: $displayWeight) {
            ForEach(DisplayWeight.allCases) { weight in
                Text(weight.label).tag(weight)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .help("Weight shown in the grid")
    }

    private var casePicker: some View {
        Picker("Case", selection: $textCase) {
            ForEach(TextCase.allCases) { textCase in
                Text(textCase.label).tag(textCase)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .help("Case")
    }

    private var themePicker: some View {
        Picker("Appearance", selection: $theme) {
            ForEach(PreviewTheme.allCases) { theme in
                Image(systemName: theme.symbol)
                    .help(theme.help)
                    .tag(theme)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    // MARK: Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        // Space and Return shouldn't fire repeatedly when held
        let isRepeat = press.phase == .repeat

        switch press.key {
        case .leftArrow:
            moveCursor(by: -1)
        case .rightArrow:
            moveCursor(by: 1)
        case .upArrow:
            moveCursor(by: -columns)
        case .downArrow:
            moveCursor(by: columns)
        case .space:
            if !isRepeat { toggleBandAtCursor() }
        case .return:
            if !isRepeat { copyAtCursor(postScript: press.modifiers.contains(.option)) }
        default:
            return .ignored
        }
        return .handled
    }

    private func moveCursor(by offset: Int) {
        let visible = visibleFamilies
        guard !visible.isEmpty else { return }

        guard let current = selectedFamilyID,
              let index = visible.firstIndex(where: { $0.id == current })
        else {
            selectedFamilyID = visible[0].id
            return
        }

        let newIndex = index + offset
        guard visible.indices.contains(newIndex) else { return }
        withAnimation(.snappy(duration: 0.2)) {
            selectedFamilyID = visible[newIndex].id
        }
    }

    private func toggleBandAtCursor() {
        guard selectedFamilyID != nil else {
            moveCursor(by: 0)
            return
        }
        withAnimation(.snappy(duration: 0.25)) {
            isBandOpen.toggle()
        }
    }

    private func copyAtCursor(postScript: Bool) {
        guard let id = selectedFamilyID,
              let family = families.first(where: { $0.id == id })
        else { return }
        let member = family.member(weight: displayWeight, italic: displayItalic)
        let name = FontNameCopier.copy(member, familyName: family.name, postScript: postScript)
        showCopied(name)
    }

    // MARK: Actions

    private func select(_ family: FontFamily) {
        gridFocused = true
        withAnimation(.snappy(duration: 0.25)) {
            if selectedFamilyID == family.id {
                isBandOpen.toggle()
            } else {
                selectedFamilyID = family.id
                isBandOpen = true
            }
        }
    }

    /// First Esc closes the band, second Esc clears the selection.
    private func closeBand() {
        withAnimation(.snappy(duration: 0.25)) {
            if isBandOpen {
                isBandOpen = false
            } else {
                selectedFamilyID = nil
            }
        }
    }

    private func toggleStar(_ family: FontFamily) {
        var set = starred
        if set.contains(family.id) { set.remove(family.id) } else { set.insert(family.id) }
        starredRaw = set.sorted().joined(separator: "\n")
    }

    private func showCopied(_ name: String) {
        withAnimation { copiedMessage = name }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedMessage == name {
                withAnimation { copiedMessage = nil }
            }
        }
    }

    private func updateUnsupported(for text: String) {
        var result = Set<String>()
        for family in families where !FontLibrary.covers(text, postScriptName: family.regular.postScriptName) {
            result.insert(family.id)
        }
        unsupported = result
    }

    private func scrollToSelection(in visible: [FontFamily], columns: Int, proxy: ScrollViewProxy) {
        guard let id = selectedFamilyID,
              let index = visible.firstIndex(where: { $0.id == id })
        else { return }
        let row = index / columns
        Task {
            await Task.yield()
            withAnimation(.snappy) {
                proxy.scrollTo(row, anchor: nil)
            }
        }
    }
}
