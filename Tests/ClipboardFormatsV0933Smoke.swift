import AppKit
import Foundation

@main struct ClipboardFormatsV0933Smoke {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        guard ok() else { fputs("FAIL v0.9.33 pasteboard: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        let board = NSPasteboard(name: NSPasteboard.Name("mw-v0.9.33-" + UUID().uuidString))
        defer { board.releaseGlobally() }
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 60,
            pixelsHigh: 40, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let png = bitmap.representation(using: .png, properties: [:]),
            let tiff = bitmap.representation(using: .tiff, properties: [:]) else {
            fputs("FAIL could not construct bitmap\n", stderr); exit(1)
        }
        board.clearContents()
        board.declareTypes([.tiff, NSPasteboard.PasteboardType("public.tab-separated-values-text")], owner: nil)
        check(board.setData(tiff, forType: .tiff), "write TIFF")
        check(board.setString("placeholder\nnot cells", forType:
             NSPasteboard.PasteboardType("public.tab-separated-values-text")), "write advertised fake TSV")
        check(!MemoWeaverPasteSelection.containsActualTable(
            tabular: board.string(forType: NSPasteboard.PasteboardType("public.tab-separated-values-text")),
            html: nil, plain: nil), "fake TSV should not override screenshot")
        switch MemoWeaverEditorImageInput.read(board) {
        case .png(let result): check(MemoWeaverAttachments.pngIsValid(result), "normalize TIFF")
        default: check(false, "cannot decode TIFF with extra text type")
        }
        board.clearContents()
        board.declareTypes([.png, .string], owner: nil)
        check(board.setData(png, forType: .png), "write PNG")
        check(board.setString("image with description", forType: .string), "write accompanying text")
        switch MemoWeaverEditorImageInput.read(board) {
        case .png(let result): check(MemoWeaverAttachments.pngIsValid(result), "PNG with text")
        default: check(false, "cannot decode PNG with accompanying text")
        }
        check(!MemoWeaverEditorImageInput.typeSummary(board).isEmpty, "type diagnostic empty")
        print("PASS v0.9.33 native image pasteboard: TIFF+fake TSV, PNG+text, type diagnostics")
    }
}
