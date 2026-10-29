import AppKit
import Foundation

@main struct InspectCurrentPasteboardV0933 {
    static func main() {
        // Diagnostics intentionally report ONLY MIME/UTI names and decoded
        // byte size; no source text, image pixels, paths or user notes.
        let board = NSPasteboard.general
        print("Clipboard types:", MemoWeaverEditorImageInput.typeSummary(board))
        switch MemoWeaverEditorImageInput.read(board) {
        case .png(let data):
            print("Image read: SUCCESS, PNG \(data.count) bytes, within attachment limit")
        case .failed(let error):
            print("Image read: FAILED — \(error)")
            exit(2)
        case .notImage:
            print("Image read: NOT AN IMAGE. Copy a screenshot to clipboard and retry.")
            exit(3)
        }
    }
}
