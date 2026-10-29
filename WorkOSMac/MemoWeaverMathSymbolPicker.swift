import SwiftUI

/// Readable math symbols without changing the original seven-category workflow.
/// Only the current category is visible. The ordinary 30pt toolbar, NSTextView,
/// snippet source, caret, Undo and autosave pipeline remain unchanged.
struct MemoWeaverMathSymbolPicker: View {
    let onInsert: (MarkdownAssistSnippet) -> Void

    @State private var selectedSectionIndex = 0
    @State private var hoveredSymbol: MarkdownAssistSnippet?

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(minimum: 58), spacing: 5), count: 4)

    private var sections: [MemoWeaverMathSymbolCatalog.Section] {
        MemoWeaverMathSymbolCatalog.sections
    }

    private var selectedSection: MemoWeaverMathSymbolCatalog.Section {
        sections[min(max(selectedSectionIndex, 0), sections.count - 1)]
    }

    private func selectSection(_ index: Int) {
        guard sections.indices.contains(index) else { return }
        if selectedSectionIndex != index {
            selectedSectionIndex = index
            hoveredSymbol = nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("기호 도구")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(sections.count)개 분류 / \(MemoWeaverMathSymbolCatalog.allSymbols.count)개 기호")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 3)

            Divider()

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sections.indices, id: \.self) { index in
                        let selected = selectedSectionIndex == index
                        Button {
                            selectSection(index)
                        } label: {
                            HStack(spacing: 5) {
                                Text(sections[index].title)
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                            }
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .padding(.horizontal, 8)
                            .frame(height: 29)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selected ? Color.primary.opacity(0.075) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        // Like the old cascading native Menu, pointer hover
                        // moves between categories without an extra click.
                        .onHover { inside in
                            if inside { selectSection(index) }
                        }
                        .accessibilityLabel(sections[index].title)
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 124, height: 248)

                Divider()

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(selectedSection.title)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(selectedSection.symbols.count)개")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 2)

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(selectedSection.symbols, id: \.self) { snippet in
                                Button {
                                    onInsert(snippet)
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(snippet.title)
                                            .font(.system(size: 25, weight: .medium, design: .serif))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                            .frame(height: 29)
                                        Text(snippet.source)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 53)
                                    .background(
                                        hoveredSymbol == snippet
                                            ? Color.primary.opacity(0.075) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .onHover { isInside in
                                    if isInside { hoveredSymbol = snippet }
                                    else if hoveredSymbol == snippet { hoveredSymbol = nil }
                                }
                                .help("\(snippet.title) \u{00B7} \(snippet.source)")
                                .accessibilityLabel("\(snippet.title), \(snippet.source) 삽입")
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .id(selectedSectionIndex) // reset symbol scroll on category switch
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 248)

            Divider()

            HStack(spacing: 8) {
                Text(hoveredSymbol?.title ?? "기호 선택")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .lineLimit(1)
                Text(hoveredSymbol?.source ?? "LaTeX 원문 삽입 · Esc 닫기")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 24)
            .padding(.horizontal, 3)
        }
        .padding(11)
        .frame(width: 444, height: 352)
    }
}
