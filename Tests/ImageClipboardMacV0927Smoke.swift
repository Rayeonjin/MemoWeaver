import AppKit
import Foundation

@main struct ImageClipboardMacV0927Smoke {
    static func check(_ ok: @autoclosure () -> Bool, _ description: String) {
        if !ok() { fputs("FAIL: \(description)\n", stderr); exit(1) }
    }
    static func main() throws {
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aKx8AAAAASUVORK5CYII=")!
        let board = NSPasteboard(name: NSPasteboard.Name("mw-clipboard-0927-\(UUID().uuidString)"))
        board.clearContents()
        board.declareTypes([.png], owner: nil)
        board.setData(png, forType: .png)
        if case .png(let result) = MemoWeaverEditorImageInput.read(board) {
            check(result == png, "PNG from clipboard")
        } else { check(false, "PNG clipboard recognition") }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mw-image-0927-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("screenshot.png")
        try png.write(to: file)
        board.clearContents()
        board.declareTypes([.fileURL], owner: nil)
        board.setString(file.absoluteString, forType: .fileURL)
        if case .png(let result) = MemoWeaverEditorImageInput.read(board) {
            check(result == png, "Finder image file drag normalized")
        } else { check(false, "Finder file drag recognition") }

        board.clearContents()
        board.declareTypes([.string], owner: nil)
        board.setString(file.path, forType: .string)
        if case .notImage = MemoWeaverEditorImageInput.read(board) { /* valid plain text */ }
        else { check(false, "plain path text must never trigger file I/O") }
        print("PASS v0.9.27 macOS: PNG, Finder fileURL, plain path safety")
    }
}
