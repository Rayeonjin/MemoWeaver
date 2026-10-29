import Foundation

// Notifications shared by the menu commands and the pane-owned SwiftUI
// headers. Keep this small independent of database and editor internals.
// Guard focus transitions against uncommitted Korean IME marked text and
// failed disk saves. Focus never rewrites note content.
extension Notification.Name {
    static let memoWeaverBeforeLayoutChange = Notification.Name("MemoWeaverBeforeLayoutChange")
    static let memoWeaverOpenQuickSearch = Notification.Name("MemoWeaverOpenQuickSearch")
    static let memoWeaverToggleFocusMode = Notification.Name("MemoWeaverToggleFocusMode")
    static let memoWeaverToggleNoteList = Notification.Name("MemoWeaverToggleNoteList")
    static let memoWeaverToggleRightPane = Notification.Name("MemoWeaverToggleRightPane")
    static let memoWeaverCreateNewNote = Notification.Name("MemoWeaverCreateNewNote")
    static let memoWeaverNativeEditorCommand = Notification.Name("MemoWeaverNativeEditorCommand")
    static let memoWeaverImportArchives = Notification.Name("MemoWeaverImportArchives")
    static let memoWeaverSelectRightPaneTab = Notification.Name("MemoWeaverSelectRightPaneTab")
}

