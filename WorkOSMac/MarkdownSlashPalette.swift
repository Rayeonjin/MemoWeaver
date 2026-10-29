import SwiftUI

/// Native, read-only completion menu. NSTextView keeps keyboard focus, undo,
/// Korean IME state and all raw Markdown source; the popover never edits text.
struct MarkdownSlashPalette: View {
    let query: String
    let context: MarkdownEditingContext
    let items: [SlashCommandCore.Item]
    let selectedIndex: Int
    let onSelect: (SlashCommandCore.Item) -> Void
    @State private var hoveredIndex: Int?

    init(query: String, context: MarkdownEditingContext,
         items: [SlashCommandCore.Item], selectedIndex: Int,
         onSelect: @escaping (SlashCommandCore.Item) -> Void) {
        self.query = query
        self.context = context
        self.items = items
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    private var contextTitle: String { context.slashPaletteTitle }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: context == .math ? "function" : "command")
                    .foregroundStyle(.secondary)
                Text(contextTitle + (query.isEmpty ? " · 추천" : " · /" + query))
                    .font(.caption.bold()).lineLimit(1)
                Spacer()
                Text("\(items.count)개")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("Esc 닫기")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            if items.isEmpty {
                Text("일치하는 명령이 없습니다. Esc로 닫거나 계속 입력하세요.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 12)
            } else {
                ScrollViewReader { reader in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(items.indices, id: \.self) { index in
                                let item = items[index]
                                Button { onSelect(item) } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: item.symbol)
                                            .frame(width: 21).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                            Text(item.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 9).padding(.vertical, 6)
                                    .background((index == selectedIndex || index == hoveredIndex)
                                                ? Color.accentColor.opacity(0.13) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .onHover { inside in
                                    if inside { hoveredIndex = index }
                                    else if hoveredIndex == index { hoveredIndex = nil }
                                }
                                .accessibilityLabel(item.title + " · " + item.description)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                    .frame(height: min(CGFloat(items.count) * 49, 330))
                    .onChange(of: selectedIndex) { _, index in
                        if items.indices.contains(index) { reader.scrollTo(index, anchor: .center) }
                    }
                }
            }
            Text(context == .normal
                 ? "↑ ↓ 탐색 · Enter 또는 클릭 삽입 · Esc 닫기"
                 : "↑ ↓ 탐색 · Enter 또는 클릭 삽입 · 원본 보존")
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.horizontal, 9).padding(.top, 5).padding(.bottom, 8)
        }
        .padding(5)
        .frame(width: 320)
    }
}
