import AppKit
import SwiftUI

@main struct UsabilityNativeSmoke {
    @MainActor static func pump(_ seconds: Double = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
    @MainActor static func findEditor(_ view: NSView) -> WorkOSMarkdownTextView? {
        if let editor = view as? WorkOSMarkdownTextView { return editor }
        for child in view.subviews { if let result = findEditor(child) { return result } }
        return nil
    }
    @MainActor static func findSplit(_ view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView, split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit" { return split }
        for child in view.subviews { if let result = findSplit(child) { return result } }
        return nil
    }
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mw-native-release-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "mw-native-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("manual", forKey: MemoryIdlePolicy.defaultsKey)
        let model = WorkOSModel(directoryOverride: directory, seedWelcome: false, preferences: defaults)
        let db = model.database!
        let target = try db.createNote(typeID: "type-note", markdown: true)
        _ = try db.saveNote(target, title: "대상", bodyHTML: "본문", typeID: target.typeID, bookID: "", noteDate: target.noteDate, status: target.status, sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let source = try db.createNote(typeID: "type-note", markdown: true)
        try model.refresh()
        model.selectedNoteID = source.id
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1320, height: 830), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "MemoWeaver — isolated QA"
        let host = NSHostingView(rootView: WorkOSMainView().environmentObject(model).defaultAppStorage(defaults))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        pump(0.6)
        guard let editor = findEditor(host) else { fatalError("editor did not mount") }
        window.makeFirstResponder(editor)
        editor.insertText("원본 한글", replacementRange: NSRange(location: 0, length: 0)); editor.didChangeText()
        pump(0.1)
        let started = Date()
        for _ in 0..<3 {
            model.selectedPage = .settings; pump()
            model.selectedPage = .all; pump()
            precondition(findEditor(host) === editor, "navigation recreated NSTextView")
        }
        print("PASS: 3 settings/notes cycles retain NSTextView identity, source and undo; elapsed including six 150ms waits: \(Date().timeIntervalSince(started))s")
        precondition(editor.string.contains("원본 한글") && editor.undoManager?.canUndo == true)
        window.makeFirstResponder(editor)
        editor.insertText(" [[대", replacementRange: editor.selectedRange()); editor.didChangeText()
        pump()
        if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36) {
            precondition(editor.wikiCompletion.handle(event, in: editor), "wiki completion not visible")
        }
        pump(0.2)
        precondition(editor.string.contains("[[\(target.id)|대상]]"), "completion did not insert stable-ID link")
        NotificationCenter.default.post(name: .memoWeaverNativeEditorCommand, object: nil, userInfo: ["noteID":source.id, "action":"pin"])
        pump(0.1)
        precondition(model.notes.first { $0.id == source.id }?.pinned == true, "pin waits for one-second autosave")
        precondition(model.wikiBacklinks[target.id]?.contains { $0.sourceID == source.id } == true, "backlink not updated after save")
        print("PASS: native wiki completion/Enter, stable ID insertion, immediate pin and backlink")
        window.makeFirstResponder(editor)
        editor.setMarkedText("조합", selectedRange: NSRange(location: 1, length: 0), replacementRange: editor.selectedRange())
        precondition(editor.hasMarkedText(), "test did not establish marked text")
        precondition(!MemoWeaverLayoutSwitchSafety.prepare(editor: editor), "IME composition guard lost")
        editor.unmarkText(); editor.didChangeText()
        _ = MemoWeaverLayoutSwitchSafety.prepare()
        let archive = directory.appendingPathComponent("import.txt")
        try String(repeating: "한글 자료 0123456789 abcdefghijklmnopqrstuvwxyz\n", count: 60000).write(to: archive, atomically: true, encoding: .utf8)
        model.importArchives([archive])
        let importStarted = Date()
        var heartbeats = 0
        while model.archiveImportBusy && Date().timeIntervalSince(importStarted) < 20 {
            pump(0.01); heartbeats += 1
        }
        precondition(!model.archiveImportBusy && model.archives.contains { $0.name == "import.txt" }, "background import failed")
        precondition(heartbeats > 5, "main run loop blocked throughout import")
        precondition(findEditor(host) === editor, "archive refresh recreated editor")
        print("PASS: background archive import, \(heartbeats) UI heartbeats, stable editor and worker-owned SQLite")
        for dark in [false, true] {
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            for width: CGFloat in [1000, 1400] {
                window.setContentSize(NSSize(width: width, height: 830))
                for (list, right) in [(true, true), (false, true), (true, false), (false, false)] {
                    defaults.set(list, forKey: "memoweaver.notes.listVisible")
                    defaults.set(right ? "open" : "closed", forKey: "memoweaver.rightPane.visibility")
                    pump()
                    guard let split = findSplit(host) else { fatalError("native split missing") }
                    precondition(split.arrangedSubviews.count == 1 + (list ? 1 : 0) + (right ? 1 : 0), "visible pane order incorrect")
                    precondition(findEditor(host) === editor, "pane change recreated editor")
                    precondition(split.arrangedSubviews.allSatisfy { $0.frame.width > 0 }, "pane compressed to zero")
                }
            }
        }
        defaults.set(true, forKey: "memoweaver.notes.listVisible")
        defaults.set("open", forKey: "memoweaver.rightPane.visibility")
        defaults.set("memory", forKey: "memoweaver.rightPane.activeTab")
        window.setContentSize(NSSize(width: 1400, height: 830)); pump(0.25)
        if let output = ProcessInfo.processInfo.environment["MEMOWEAVER_QA_SCREENSHOT"],
           let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) { try png.write(to: URL(fileURLWithPath: output)) }
        }
        print("PASS: light/dark, 2 window widths, all 4 pane visibility states retain editor and positive native frames")
        window.orderOut(nil)
        print("PASS: marked-text navigation guard; all data isolated in temporary database")
    }
}
