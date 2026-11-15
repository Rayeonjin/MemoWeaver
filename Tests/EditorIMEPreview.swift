import AppKit
import SwiftUI

/// Human-input acceptance window. Never opens the real application database.
@MainActor enum EditorIMEPreview {
    final class Delegate: NSObject, NSWindowDelegate {
        @objc func quit() { NSApplication.shared.stop(nil) }
        func windowWillClose(_ notification: Notification) { quit() }
    }
    static func run() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mw-editor-ime-" + UUID().uuidString)
        let suite = "mw-editor-ime-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("manual", forKey: MemoryIdlePolicy.defaultsKey)
        let model = WorkOSModel(directoryOverride: directory, seedWelcome: false, preferences: defaults)
        let db = model.database!
        var note = try db.createNote(typeID: "type-note", markdown: true)
        for body in ["# 이전 본문\n\n한글 메모와 **강조**.", "# 편집기 검사\n\n여기에 한글을 입력하세요: \n\n| 항목 | 내용 | 상태 |\n| --- | --- | --- |\n| 한글😀 | `a|b` | 확인 |\n\n$$\nx^2 + y^2 = z^2\n$$\n"] {
            note = try db.saveNote(note, title: "격리된 편집기 검사", bodyHTML: body, typeID: note.typeID, bookID: "", noteDate: note.noteDate, status: note.status, sourceURL: "", pinned: false, archived: false, checkpoint: true)
        }
        try model.refresh(); model.selectedNoteID = note.id
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate()
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        let quit = NSMenuItem(title: "QA 종료", action: #selector(Delegate.quit), keyEquivalent: "q")
        quit.target = delegate; appMenu.addItem(quit); appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem(title: "편집", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(NSMenuItem(title: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "다시 실행", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]; editMenu.addItem(redo)
        editItem.submenu = editMenu; menu.addItem(editItem); app.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 70, y: 90, width: 1320, height: 830), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.delegate = delegate
        window.title = "MemoWeaver QA — 한글 '한' 입력 후 잠시 기다려 주세요"
        let host = NSHostingView(rootView: WorkOSMainView().environmentObject(model).defaultAppStorage(defaults))
        window.contentView = host; window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        UsabilityNativeSmoke.pump(1)
        guard let editor = UsabilityNativeSmoke.findEditor(host) else { fatalError("QA editor missing") }
        window.makeFirstResponder(editor)
        let caret = (editor.string as NSString).range(of: "입력하세요: ").location + ("입력하세요: " as NSString).length
        editor.setSelectedRange(NSRange(location: caret, length: 0))
        var observed = false
        var lastSignature = ""
        func inspectComposition() {
            guard let current = UsabilityNativeSmoke.findEditor(host) else { return }
            let signature = "\(ObjectIdentifier(current)) / \(current.hasMarkedText()) / \(current.markedRange()) / \((current.string as NSString).length)"
            if signature != lastSignature {
                print("IME_OBSERVATION: " + signature)
                lastSignature = signature
            }
            guard current.hasMarkedText(), !observed else { return }
            observed = true
            let before = current.string, marked = current.markedRange()
            precondition(!MemoWeaverLayoutSwitchSafety.prepare(editor: current))
            precondition(!current.replaceSourceUndoably("REFUSED", range: NSRange(location: 0, length: (before as NSString).length)))
            precondition(current.string == before && current.markedRange() == marked)
            print("HUMAN_IME_MARKED_PASS: physical input produced marked text; navigation and full-body replacement refused; source and marked range intact")
            window.title = "MemoWeaver QA — 조합 보호 확인. Space로 확정 후 실행 취소·다시 실행"
        }
        var ticks = 0
        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in
            ticks += 1
            if ticks == 1 { print("IME_WATCH_ACTIVE") }
            inspectComposition()
        }
        RunLoop.main.add(timer, forMode: .common)
        let textObserver = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: nil, queue: .main) { _ in inspectComposition() }
        let selectionObserver = NotificationCenter.default.addObserver(forName: NSTextView.didChangeSelectionNotification, object: nil, queue: .main) { _ in inspectComposition() }
        print("IME_QA_READY: isolated note and preferences; no synthetic marked text")
        inspectComposition()
        app.run()
        window.orderOut(nil)
        timer.invalidate()
        NotificationCenter.default.removeObserver(textObserver)
        NotificationCenter.default.removeObserver(selectionObserver)
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}
