import AppKit
import SwiftUI

struct MemoWeaverBacklink: Identifiable {
    let sourceID: String
    let targetID: String
    let line: Int
    let context: String
    let offset: Int
    var id: String { sourceID + ":" + String(offset) }
}

@MainActor
extension WorkOSModel {
    func wikiCandidates(_ query: String, excluding: String = "") -> [MemoWeaverWikiCandidate] {
        Array(notes.lazy.filter { $0.deletedAt.isEmpty && $0.id != excluding &&
            (query.isEmpty || $0.visibleTitle.localizedCaseInsensitiveContains(query)) }
            .prefix(12).map { .init(id: $0.id, title: $0.visibleTitle) })
    }
    private func references(for note: WorkNote, candidates: [MemoWeaverWikiCandidate]) -> [MemoWeaverBacklink] {
        guard note.deletedAt.isEmpty, note.isMarkdown else { return [] }
        let bindings = MemoWeaverWikiLinks.bindings(note)
        return MemoWeaverWikiLinks.references(in: note.bodyHTML).compactMap { reference in
            guard let target = MemoWeaverWikiLinks.resolve(reference.target, bindings: bindings, candidates: candidates) else { return nil }
            return .init(sourceID: note.id, targetID: target, line: reference.line, context: reference.context, offset: reference.range.location)
        }
    }
    func rebuildWikiLinks() {
        let candidates = notes.filter { $0.deletedAt.isEmpty }.map { MemoWeaverWikiCandidate(id: $0.id, title: $0.visibleTitle) }
        var rebuilt: [String: [MemoWeaverBacklink]] = [:]
        for note in notes {
            for reference in references(for: note, candidates: candidates) { rebuilt[reference.targetID, default: []].append(reference) }
        }
        wikiBacklinks = rebuilt
    }
    func updateWikiLinks(_ note: WorkNote) {
        var updated = wikiBacklinks
        for key in Array(updated.keys) {
            updated[key]?.removeAll { $0.sourceID == note.id }
            if updated[key]?.isEmpty == true { updated.removeValue(forKey: key) }
        }
        let candidates = notes.filter { $0.deletedAt.isEmpty }.map { MemoWeaverWikiCandidate(id: $0.id, title: $0.visibleTitle) }
        for reference in references(for: note, candidates: candidates) { updated[reference.targetID, default: []].append(reference) }
        wikiBacklinks = updated
    }
    func openWikiLink(_ target: String, sourceID: String? = nil) {
        guard MemoWeaverLayoutSwitchSafety.prepare() else {
            alertText = "입력 조합 또는 저장이 끝난 뒤 연결을 열어 주세요."
            return
        }
        let source = notes.first { $0.id == (sourceID ?? selectedNoteID) }
        let bindings = source.map(MemoWeaverWikiLinks.bindings) ?? [:]
        let candidates = notes.filter { $0.deletedAt.isEmpty }.map { MemoWeaverWikiCandidate(id: $0.id, title: $0.visibleTitle) }
        guard let id = MemoWeaverWikiLinks.resolve(target, bindings: bindings, candidates: candidates) else {
            alertText = "연결할 메모가 없거나 같은 제목의 메모가 여러 개입니다. [[를 입력하고 목록에서 선택해 주세요."
            return
        }
        openNote(id)
    }
}

struct MemoWeaverWikiLinksSection: View {
    @EnvironmentObject private var model: WorkOSModel
    let noteID: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("메모 연결 · 직접 작성", systemImage: "link").font(.subheadline.bold())
            Text("[[를 입력해 메모 선택 · 본문의 연결은 ⌘클릭으로 열기")
                .font(.caption).foregroundStyle(.secondary)
            let outgoing = model.wikiBacklinks.values.flatMap { $0 }.filter { $0.sourceID == noteID }
            Text("이 메모의 연결 (\(outgoing.count))").font(.caption.bold())
            ForEach(outgoing.sorted { $0.offset < $1.offset }) { reference in
                Button { model.openWikiLink(reference.targetID, sourceID: noteID) } label: {
                    Label(model.notes.first { $0.id == reference.targetID }?.visibleTitle ?? "삭제된 메모", systemImage: "arrow.up.right")
                }.buttonStyle(.plain)
            }
            let incoming = model.wikiBacklinks[noteID] ?? []
            Text("역방향 링크 (\(incoming.count))").font(.caption.bold())
            ForEach(incoming.sorted { $0.id < $1.id }) { reference in
                Button {
                    guard MemoWeaverLayoutSwitchSafety.prepare() else { return }
                    model.openNote(reference.sourceID, focusLine: reference.line)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.notes.first { $0.id == reference.sourceID }?.visibleTitle ?? "메모").font(.caption.bold())
                        Text("\(reference.line)행 · \(reference.context)").font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(7)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
            if incoming.isEmpty { Text("아직 이 메모를 참조하는 메모가 없습니다.").font(.caption).foregroundStyle(.secondary) }
            Divider()
        }
    }
}

// A read-only completion popover; NSTextView retains focus, IME and native undo.
@MainActor
final class MemoWeaverWikiCompletion {
    var candidates: (String) -> [MemoWeaverWikiCandidate] = { _ in [] }
    private var popup: NSPopover?
    private var host: NSHostingController<MemoWeaverWikiCompletionList>?
    private var items: [MemoWeaverWikiCandidate] = []
    private var replacement = NSRange(location: 0, length: 0)
    private var selected = 0
    private var suppressedOffset: Int?
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }
    var isPresented: Bool { popup?.isShown == true }
    func close() {
        popup?.close(); popup = nil; host = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver); self.resignObserver = nil }
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
    func update(in editor: WorkOSMarkdownTextView, allowed: Bool) {
        guard allowed, editor.isNavigationActive, !editor.hasMarkedText(), editor.selectedRange().length == 0,
              editor.window?.firstResponder === editor else { close(); return }
        let ns = editor.string as NSString
        let caret = min(editor.selectedRange().location, ns.length)
        guard suppressedOffset != caret else { return }
        let line = ns.lineRange(for: NSRange(location: caret, length: 0))
        let prefix = ns.substring(with: NSRange(location: line.location, length: caret-line.location))
        guard let start = prefix.range(of: "[[", options: .backwards) else { close(); return }
        let query = String(prefix[start.upperBound...])
        guard query.count <= 120, !query.contains("]"), !query.contains("["), !query.contains("|"),
              !prefix[..<start.lowerBound].hasSuffix("\\"),
              !prefix[..<start.lowerBound].contains("`") else { close(); return }
        let found = candidates(query)
        guard !found.isEmpty else { close(); return }
        replacement = NSRange(location: line.location + (String(prefix[..<start.lowerBound]) as NSString).length,
                              length: (String(prefix[start.lowerBound...]) as NSString).length)
        if items != found { selected = 0 }
        items = found
        if popup == nil {
            resignObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.close() }
            let panel = NSPopover(); panel.animates = false; panel.behavior = .applicationDefined
            let controller = NSHostingController(rootView: content(editor))
            panel.contentViewController = controller; host = controller; popup = panel
            var rect = editor.firstRect(forCharacterRange: NSRange(location: caret, length: 0), actualRange: nil)
            if let window = editor.window { rect = editor.convert(window.convertFromScreen(rect), from: nil) }
            panel.show(relativeTo: rect, of: editor, preferredEdge: .maxY)
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                if let window = self.host?.view.window, let target = event.window, target !== window { self.close() }
                return event
            }
        }
        render(editor)
    }
    private func content(_ editor: WorkOSMarkdownTextView) -> MemoWeaverWikiCompletionList {
        .init(items: items, selected: selected) { [weak self, weak editor] item in
            DispatchQueue.main.async {
                guard let self, let editor else { return }
                self.insert(item, in: editor)
            }
        }
    }
    private func render(_ editor: WorkOSMarkdownTextView) {
        host?.rootView = content(editor)
        popup?.contentSize = NSSize(width: 330, height: CGFloat(48 + items.count * 32))
    }
    func handle(_ event: NSEvent, in editor: WorkOSMarkdownTextView) -> Bool {
        guard editor.isNavigationActive, popup?.isShown == true else { return false }
        switch event.keyCode {
        case 53: suppressedOffset = editor.selectedRange().location; close(); return true
        case 125: selected = min(items.count - 1, selected + 1); render(editor); return true
        case 126: selected = max(0, selected - 1); render(editor); return true
        case 36, 76:
            guard items.indices.contains(selected) else { return false }
            insert(items[selected], in: editor); return true
        default: return false
        }
    }
    private func insert(_ item: MemoWeaverWikiCandidate, in editor: WorkOSMarkdownTextView) {
        guard editor.isNavigationActive, popup?.isShown == true, !editor.hasMarkedText(), NSMaxRange(replacement) <= (editor.string as NSString).length else { close(); return }
        var range = replacement
        if (editor.string as NSString).substring(from: NSMaxRange(range)).hasPrefix("]]") { range.length += 2 }
        let text = MemoWeaverWikiLinks.source(item)
        close()
        editor.insertText(text, replacementRange: range)
        editor.setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        editor.window?.makeFirstResponder(editor)
        // Native programmatic edits publish through the same fallback as templates.
        editor.didChangeText()
    }
}

private struct MemoWeaverWikiCompletionList: View {
    let items: [MemoWeaverWikiCandidate]
    let selected: Int
    let choose: (MemoWeaverWikiCandidate) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("메모 연결 · ↑↓ 선택 · Enter 삽입 · Esc 닫기").font(.caption2).foregroundStyle(.secondary).padding(8)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { choose(item) } label: {
                    Text(item.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).frame(height: 32)
                        .background(index == selected ? Color.accentColor.opacity(0.15) : .clear)
                }.buttonStyle(.plain)
            }
        }.padding(4).frame(width: 330)
    }
}
