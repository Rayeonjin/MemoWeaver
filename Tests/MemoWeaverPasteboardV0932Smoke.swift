import AppKit
import Foundation

@main struct MemoWeaverPasteboardV0932Smoke {
    static func verify(_ okay: @autoclosure () -> Bool, _ message: String) {
        if !okay() { fputs("FAIL clipboard v0.9.32: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        let name = NSPasteboard.Name("MemoWeaver-ImageClipboard-V0932-" + UUID().uuidString)
        let board = NSPasteboard(name: name)
        defer { board.releaseGlobally() }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 48, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        let tiff = bitmap.representation(using: .tiff, properties: [:])!
        board.clearContents()
        board.declareTypes([.tiff], owner: nil)
        verify(board.setData(tiff, forType: .tiff), "could not create TIFF clipboard")
        if case .png(let content) = MemoWeaverEditorImageInput.read(board) {
            verify(MemoWeaverAttachments.pngIsValid(content), "TIFF not normalized")
        } else { verify(false, "TIFF clipboard not recognized") }
        board.clearContents()
        board.declareTypes([.png, .tiff], owner: nil)
        verify(board.setData(png, forType: .png), "could not create PNG clipboard")
        verify(board.setData(tiff, forType: .tiff), "could not create fallback TIFF")
        if case .png(let content) = MemoWeaverEditorImageInput.read(board) {
            verify(MemoWeaverAttachments.pngIsValid(content), "PNG not read")
        } else { verify(false, "PNG clipboard not recognized") }
        board.clearContents()
        board.declareTypes([.string], owner: nil)
        verify(board.setString("not an image", forType: .string), "could not create text clipboard")
        if case .notImage = MemoWeaverEditorImageInput.read(board) {} else {
            verify(false, "plain text clipboard was mistaken for an image")
        }
        print("PASS macOS clipboard: TIFF, PNG, multi-format and plain text discrimination")
    }
}
