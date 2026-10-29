import AppKit

// AppKit exposes screenshots and file drags in several representations.
// Normalize them to one bounded PNG before invoking the note's atomic store.
// Only genuine image pasteboard types and local image file URLs are accepted;
// a pasted string that resembles a path is never silently opened.
enum MemoWeaverEditorImageInput {
    enum Result {
        case notImage
        case png(Data)
        case failed(String)
    }

    private static let rawImageTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff, NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.heif")
    ]
    private static let imageExtensions: Set<String> = [
        "png", "jpeg", "jpg", "tiff", "tif", "gif", "heic", "heif", "webp", "bmp"
    ]
    // Finder image files stay limited to 24MiB. In-memory macOS screenshot
    // TIFFs can be much larger than their eventually saved PNG representation.
    private static let maximumFileBytes = 24 * 1024 * 1024
    private static let maximumClipboardRepresentationBytes = 96 * 1024 * 1024

    private static func fileURL(_ board: NSPasteboard) -> URL? {
        if let urls = board.readObjects(forClasses: [NSURL.self],
                    options: [.urlReadingFileURLsOnly: true]) as? [NSURL],
           let first = urls.first {
            let url = first as URL
            if url.isFileURL && imageExtensions.contains(url.pathExtension.lowercased()) { return url }
        }
        if let raw = board.string(forType: .fileURL),
           let url = URL(string: raw), url.isFileURL,
           imageExtensions.contains(url.pathExtension.lowercased()) { return url }
        return nil
    }

    // Log only Uniform Type Identifiers, never clipboard content. This allows
    // users to distinguish an unsupported clipboard provider from an AppKit
    // responder-chain failure without exposing their actual screenshots.
    static func typeSummary(_ board: NSPasteboard) -> String {
        let types = (board.types ?? []).prefix(8).map { $0.rawValue }
        return types.isEmpty ? "비어 있음" : types.joined(separator: ", ")
    }

    static func containsImage(_ board: NSPasteboard) -> Bool {
        rawImageTypes.contains(where: { board.availableType(from: [$0]) != nil }) || fileURL(board) != nil
    }

    private static func normalizePNG(_ raw: Data) -> Data? {
        guard !raw.isEmpty, raw.count <= maximumClipboardRepresentationBytes else { return nil }
        if MemoWeaverAttachments.pngIsValid(raw) { return raw }
        let bitmap = NSBitmapImageRep(data: raw) ??
            NSImage(data: raw)?.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }
        guard let bitmap,
              bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
              bitmap.pixelsWide <= 8192, bitmap.pixelsHigh <= 8192,
              bitmap.pixelsWide * bitmap.pixelsHigh <= 32 * 1024 * 1024,
              let png = bitmap.representation(using: .png, properties: [:]),
              MemoWeaverAttachments.pngIsValid(png) else { return nil }
        return png
    }

    static func read(_ board: NSPasteboard) -> Result {
        // A clipboard item may advertise BOTH a file URL and direct image
        // bytes. Some providers offer an inaccessible temporary file URL;
        // attempt other representations rather than failing prematurely.
        var offeredImage = false
        if let file = fileURL(board) {
            offeredImage = true
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ??
                ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0)
            if size > 0, size <= maximumFileBytes,
               let raw = try? Data(contentsOf: file, options: .mappedIfSafe),
               let png = normalizePNG(raw) { return .png(png) }
        }
        // Do not abort on the first representation: an app may advertise
        // public.png yet provide only TIFF data until the promised image is
        // materialized. Large uncompressed TIFF captures are allowed if the
        // normalized PNG still meets the original 8MiB / 32MP store limits.
        // A pasteboard can contain multiple items. `board.data(forType:)`
        // returns only the first matching item; check all representations in
        // case the first advertised PNG is unavailable or invalid.
        for item in board.pasteboardItems ?? [] {
            for type in rawImageTypes where item.types.contains(type) {
                offeredImage = true
                if let raw = item.data(forType: type), let png = normalizePNG(raw) {
                    return .png(png)
                }
            }
        }
        for type in rawImageTypes {
            if board.availableType(from: [type]) == nil { continue }
            offeredImage = true
            if let raw = board.data(forType: type), let png = normalizePNG(raw) {
                return .png(png)
            }
        }
        // macOS screenshot and browser providers may be NSImage-readable
        // without returning data for the advertised UTI above.
        if let image = NSImage(pasteboard: board) {
            offeredImage = true
            if let raw = image.tiffRepresentation, let png = normalizePNG(raw) {
                return .png(png)
            }
        }
        if let images = board.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for image in images {
                offeredImage = true
                if let raw = image.tiffRepresentation, let png = normalizePNG(raw) {
                    return .png(png)
                }
            }
        }
        if offeredImage {
            return .failed("클립보드 이미지 변환 실패. PNG 저장 제한은 8MiB·32MP입니다. " +
                           "제공된 형식: " + typeSummary(board))
        }
        return .notImage
    }
}

