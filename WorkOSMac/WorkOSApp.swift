import AppKit
import SwiftUI

@main
struct WorkOSApp: App {
    @NSApplicationDelegateAdaptor(WorkOSAppDelegate.self) private var appDelegate
    @StateObject private var model = WorkOSModel()
    @AppStorage("workos.appearance") private var appearance = "system"
    @AppStorage("memoryhome.typography.fontSize") private var editorFontSize = EditorTypographyRules.defaultSize

    private var selectedScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        // One primary editing workspace; separate reference readers remain
        // independent NSWindows. Shared model selection must never leak between
        // two editable WindowGroup windows.
        Window("MemoWeaver", id: "main") {
            WorkOSMainView()
                .environmentObject(model)
                .preferredColorScheme(selectedScheme)
                .frame(minHeight: 640)
        }
        .defaultSize(width: 1320, height: 830)
        // Real one-row AppKit toolbar divided by the native split's boundaries.
        // The title, pane toggles, and actions occupy the SAME unified row.
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandMenu("보기") {
                Button("집중 모드 전환") {
                    NotificationCenter.default.post(name: .memoWeaverToggleFocusMode, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                // View-menu commands also work when the editor header's
                // narrow-width actions move into a compact popup menu.
                Button("메모 목록 열기·닫기") {
                    NotificationCenter.default.post(name: .memoWeaverToggleNoteList, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
                Button("보조창 열기·닫기") {
                    NotificationCenter.default.post(name: .memoWeaverToggleRightPane, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(model.currentNote == nil)
                Divider()
                Button("보조창: 미리보기") {
                    NotificationCenter.default.post(name: .memoWeaverSelectRightPaneTab,
                                                    object: nil, userInfo: ["tab": "preview"])
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                Button("보조창: 연결") {
                    NotificationCenter.default.post(name: .memoWeaverSelectRightPaneTab,
                                                    object: nil, userInfo: ["tab": "memory"])
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                Button("보조창: 참고 메모") {
                    NotificationCenter.default.post(name: .memoWeaverSelectRightPaneTab,
                                                    object: nil, userInfo: ["tab": "reference"])
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                Divider()
                Button("글자 크게") { editorFontSize = EditorTypographyRules.zoom(editorFontSize, by: 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("글자 작게") { editorFontSize = EditorTypographyRules.zoom(editorFontSize, by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("기본 글자 크기") { editorFontSize = EditorTypographyRules.defaultSize }
                    .keyboardShortcut("0", modifiers: .command)
            }
            CommandMenu("메모") {
                Button("빠른 검색 · 명령 팔레트") {
                    NotificationCenter.default.post(name: .memoWeaverOpenQuickSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("메모로 이동") { model.selectedPage = .all }
                    .keyboardShortcut("j", modifiers: .command)
                Divider()
                Button("모든 기록 검색") { model.selectedPage = .search }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                // ⌘F remains the native NSTextView Find Panel in the editor.
                Button("새 메모") { model.newNoteFromShortcut() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("새 회의록") { model.createNote(typeID: "type-meeting") }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("변경 이력 체크포인트") { model.checkpoint() }
                    .keyboardShortcut("s", modifiers: .command)
                Divider()
                Button("JSON 전체 복원 (기존 데이터 교체)…") { model.restoreBackupDialog() }
                Button("전체 JSON 백업") { model.exportBackupDialog() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("클립보드 이미지 붙여넣기") {
                    if !NSApp.sendAction(#selector(WorkOSMarkdownTextView.pasteClipboardImage(_:)),
                                         to: nil, from: nil) {
                        model.alertText = "먼저 메모 편집창을 클릭한 뒤 이미지를 붙여넣으세요."
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                Divider()
                Button("현재 Markdown 표 → 탭 구분 텍스트") {
                    NSApp.sendAction(#selector(WorkOSMarkdownTextView.convertMarkdownTableToTSV(_:)),
                                     to: nil, from: nil)
                }
                Button("Markdown 표를 텍스트로 복사") {
                    NSApp.sendAction(#selector(WorkOSMarkdownTextView.copyMarkdownTableAsTSV(_:)),
                                     to: nil, from: nil)
                }
            }
        }
    }
}
