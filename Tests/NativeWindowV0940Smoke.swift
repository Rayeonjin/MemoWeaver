import AppKit
import SwiftUI

// Run on macOS only. Mount a real NSWindow + NSSplitView and verify that
// no empty native toolbar occupies the height above the three pane headers.
@MainActor
private final class TitlebarZoneState: ObservableObject {
    @Published var listVisible = true
    @Published var rightVisible = true
}

private struct TitlebarZoneRoot: View {
    @ObservedObject var state: TitlebarZoneState

    var body: some View {
        HStack(spacing: 0) {
            Color(nsColor: .controlBackgroundColor).frame(width: 52)
            Divider()
            MemoWeaverPinnedSplitView(
                list: zone("내 메모", color: .controlBackgroundColor),
                editor: zone("메모 편집", color: .windowBackgroundColor),
                right: zone("미리보기 · 연결 · 참고 메모", color: .windowBackgroundColor),
                listVisible: state.listVisible, rightVisible: state.rightVisible,
                listPreferred: 245, rightPreferred: 340,
                saveListWidth: { _ in }, saveRightWidth: { _ in })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(MemoWeaverNativeWindowChrome()
            .frame(width: 1, height: 1).allowsHitTesting(false))
    }

    private func zone(_ title: String, color: NSColor) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: color))
    }
}

@MainActor
@main
struct NativeWindowV0940Smoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let state = TitlebarZoneState()
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1280, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: TitlebarZoneRoot(state: state))
        window.makeKeyAndOrderFront(nil)

        func settle() {
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.24))
            window.layoutIfNeeded()
        }
        func findSplit(_ view: NSView) -> NSSplitView? {
            if let split = view as? NSSplitView,
               split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit" { return split }
            for subview in view.subviews {
                if let result = findSplit(subview) { return result }
            }
            return nil
        }
        func verify(list: Bool, right: Bool) {
            settle()
            guard let content = window.contentView,
                  let split = findSplit(content) else { fatalError("Real NSSplitView missing") }
            precondition(window.toolbar == nil, "An empty NSToolbar must not reserve a separate row")
            precondition(window.styleMask.contains(.fullSizeContentView), "Titlebar must host full-size content")
            precondition(window.titleVisibility == .hidden, "Do not repeat a window title above note title")
            precondition(window.titlebarAppearsTransparent, "Titlebar must share pane surface")
            precondition(split.arrangedSubviews.count == 1 + (list ? 1 : 0) + (right ? 1 : 0),
                         "Closed pane must be physically removed from NSSplitView")
            // The pane root reaches the top of the full-size contentView.
            // A second native toolbar would place it lower than this edge.
            let paneRect = split.convert(split.bounds, to: content)
            precondition(abs(content.bounds.maxY - paneRect.maxY) < 4,
                         "Pane headers are not reaching the full-size window titlebar")
        }
        verify(list: true, right: true)
        state.rightVisible = false
        verify(list: true, right: false)
        state.listVisible = false
        state.rightVisible = true
        verify(list: false, right: true)
        state.rightVisible = false
        verify(list: false, right: false)
        state.listVisible = true
        state.rightVisible = true
        verify(list: true, right: true)
        window.close()
        print("PASS v0.9.40 real AppKit: full-height panes / no native toolbar row / all pane states")
    }
}
