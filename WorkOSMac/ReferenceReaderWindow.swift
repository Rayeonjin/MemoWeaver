import AppKit
import SwiftUI

// Independent, non-modal read-only windows. The current NSTextView remains
// mounted and its selectedNoteID, cursor, undo stack and autosave are untouched.
@MainActor
final class MemoryReferenceWindowCoordinator {
    private var windows: [String: NSWindow] = [:]

    func show(_ snapshot: MemoryReferenceSnapshot, onEdit: @escaping () -> Void) {
        // A closed window can be reused; refresh the snapshot in case the
        // original record has changed since it was last displayed.
        let existing = windows[snapshot.id]
        let window = existing ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "참고 기록 · " + snapshot.title
        window.minSize = NSSize(width: 430, height: 340)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView:
            MemoryReferenceReaderView(snapshot: snapshot, onEdit: onEdit))
        if existing == nil { window.center() }
        // Avoid retaining an unlimited number of closed windows.
        if windows.count >= 6 && existing == nil {
            if let key = windows.first(where: { !$0.value.isVisible })?.key {
                windows.removeValue(forKey: key)
            }
        }
        windows[snapshot.id] = window
        window.makeKeyAndOrderFront(nil)
    }
}

private struct MemoryReferenceReaderView: View {
    let snapshot: MemoryReferenceSnapshot
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.title).font(.title3.bold()).lineLimit(2)
                    Text(snapshot.caption).font(.caption).foregroundStyle(.secondary)
                    Label("읽기 전용 · 작성 중인 메모는 그대로 유지", systemImage: "lock")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("편집기에서 열기") { onEdit() }
                    .memoTooltip("이 버튼을 누를 때만 작업 중인 편집 메모를 전환합니다.")
            }
            .padding(18)
            Divider()
            ScrollView {
                Text(snapshot.body.isEmpty ? "(본문 없음)" : snapshot.body)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(20)
            }
        }
        .frame(minWidth: 430, minHeight: 340)
    }
}
