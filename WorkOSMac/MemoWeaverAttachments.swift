import Foundation

// Images are immutable, private application files. The note stores only a
// portable `attachments/<UUID>.png` relative reference, never a user path.
// Old notes, revision history, and JSON backups are never rewritten to import.
enum MemoWeaverAttachments {
    enum Problem: LocalizedError {
        case invalidImage, imageTooLarge, invalidReference, missingAsset(String)
        case invalidBackup, backupTooLarge, conflictingAsset(String)
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "PNG 이미지가 아니거나 이미지 파일이 손상되었습니다."
            case .imageTooLarge: return "이미지 한 장은 최대 8MiB까지 첨부할 수 있습니다."
            case .invalidReference: return "첨부 이미지의 상대경로가 올바르지 않습니다."
            case .missingAsset(let name): return "첨부 이미지 파일이 없습니다: \(name)"
            case .invalidBackup: return "첨부 이미지 백업이 올바르지 않습니다. 기존 자료를 유지했습니다."
            case .backupTooLarge: return "첨부 이미지를 포함한 JSON 백업 제한(512MiB)을 초과했습니다."
            case .conflictingAsset(let name): return "동일한 이름에 다른 이미지가 있어 복원하지 않았습니다: \(name)"
            }
        }
    }

    static let maxImageBytes = 8 * 1024 * 1024
    static let maxBackupImageBytes = 256 * 1024 * 1024
    private static let pngSignature = Data([137,80,78,71,13,10,26,10])
    private static let fileNamePattern = try! NSRegularExpression(
        pattern: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$"#)
    private static let sourceReferencePattern = try! NSRegularExpression(
        pattern: #"attachments/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png"#)
    private static let imageElementPattern = try! NSRegularExpression(
        pattern: #"<img data-mw-attachment='(attachments/[0-9a-f-]{36}\.png)' alt='([^']*)' class='memo-image'>"#)

    // Images are immutable and their UUID references do not change. Cache the
    // expensive base64 encoding for notes refreshed while the user types. The
    // bounded NSCache can evict at any time and does not retain file handles.
    private final class EncodedImage: NSObject {
        let sourceBytes: Int
        let dataURL: String
        init(sourceBytes: Int, dataURL: String) {
            self.sourceBytes = sourceBytes
            self.dataURL = dataURL
        }
    }
    private static let imageCache: NSCache<NSString, EncodedImage> = {
        let cache = NSCache<NSString, EncodedImage>()
        cache.countLimit = 16
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static var defaultStorageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkOS", isDirectory: true)
    }

    static func validRelativePath(_ path: String) -> Bool {
        guard path.hasPrefix("attachments/") else { return false }
        let name = String(path.dropFirst("attachments/".count))
        return fileNamePattern.firstMatch(in: name, range: NSRange(location: 0, length: (name as NSString).length)) != nil
    }

    static func folder(in storageDirectory: URL = defaultStorageDirectory) -> URL {
        storageDirectory.appendingPathComponent("Attachments", isDirectory: true)
    }

    static func pngIsValid(_ data: Data) -> Bool {
        // Guard both compressed input size and decoded canvas size. A 50-byte
        // crafted PNG header could otherwise request a multi-gigabyte bitmap
        // inside WebKit while the stored file appears tiny.
        guard data.count >= 33, data.count <= maxImageBytes,
              data.starts(with: pngSignature),
              Array(data[8..<16]) == [0, 0, 0, 13, 73, 72, 68, 82] else { return false }
        func uint32(_ offset: Int) -> UInt64 {
            (0..<4).reduce(UInt64(0)) { ($0 << 8) | UInt64(data[offset + $1]) }
        }
        let width = uint32(16), height = uint32(20)
        return width > 0 && height > 0 && width <= 8192 && height <= 8192 &&
            width * height <= 32 * 1024 * 1024
    }

    static func storePNG(_ data: Data, in storageDirectory: URL = defaultStorageDirectory) throws -> String {
        guard pngIsValid(data) else {
            throw data.count > maxImageBytes ? Problem.imageTooLarge : Problem.invalidImage
        }
        let directory = folder(in: storageDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString.lowercased() + ".png"
        let destination = directory.appendingPathComponent(name, isDirectory: false)
        // UUID names plus atomic writes: a partially written PNG is never cited.
        try data.write(to: destination, options: [.atomic])
        return "attachments/" + name
    }

    static func read(_ path: String, in storageDirectory: URL = defaultStorageDirectory) -> Data? {
        guard validRelativePath(path) else { return nil }
        let destination = folder(in: storageDirectory)
            .appendingPathComponent(String(path.dropFirst("attachments/".count)))
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
              ((attrs[.size] as? NSNumber)?.intValue ?? 0) <= maxImageBytes,
              let data = try? Data(contentsOf: destination, options: .mappedIfSafe),
              pngIsValid(data) else { return nil }
        return data
    }

    static func referencedPaths(in source: String) -> [String] {
        let ns = source as NSString
        let matches = sourceReferencePattern.matches(in: source, range: NSRange(location: 0, length: ns.length))
        return Array(Set(matches.map { ns.substring(with: $0.range) })).sorted()
    }

    // Safe inline images are transformed into data URLs after Markdown HTML
    // escaping. All other Markdown/image URLs remain plain text; WKWebView
    // never gains arbitrary file://, network or content:// access.
    static func resolvePreviewImages(_ html: String,
                                     storageDirectory: URL = defaultStorageDirectory) -> String {
        let ns = html as NSString
        let matches = imageElementPattern.matches(in: html,
                        range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return html }
        var output = html
        var totalBytes = 0
        for match in matches.reversed() {
            let path = ns.substring(with: match.range(at: 1))
            let alt = ns.substring(with: match.range(at: 2)) // already escaped by the Markdown renderer
            let replacement: String
            let cacheKey = (storageDirectory.standardizedFileURL.path + "/" + path) as NSString
            let encoded: EncodedImage?
            if let cached = imageCache.object(forKey: cacheKey) {
                encoded = cached
            } else if let data = read(path, in: storageDirectory) {
                let url = "data:image/png;base64," + data.base64EncodedString()
                let value = EncodedImage(sourceBytes: data.count, dataURL: url)
                imageCache.setObject(value, forKey: cacheKey, cost: url.utf8.count)
                encoded = value
            } else {
                encoded = nil
            }
            if let encoded, totalBytes + encoded.sourceBytes <= 32 * 1024 * 1024 {
                totalBytes += encoded.sourceBytes
                replacement = "<img class='memo-image' alt='\(alt)' src='\(encoded.dataURL)'>"
            } else {
                replacement = "<span class='memo-image-missing'>첨부 이미지 누락 또는 표시 한도 초과: \(path)</span>"
            }
            if let range = Range(match.range, in: output) { output.replaceSubrange(range, with: replacement) }
        }
        return output
    }

    static func exportMarkdownAssets(from markdown: String, to parent: URL,
                                     storageDirectory: URL = defaultStorageDirectory) throws {
        let paths = referencedPaths(in: markdown)
        guard !paths.isEmpty else { return }
        let output = parent.appendingPathComponent("attachments", isDirectory: true)
        let fm = FileManager.default
        // Read/validate everything before creating any output directory.
        let assets: [(String, Data)] = try paths.map { path in
            guard let contents = read(path, in: storageDirectory) else { throw Problem.missingAsset(path) }
            return (String(path.dropFirst("attachments/".count)), contents)
        }
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, bytes) in assets {
            let destination = output.appendingPathComponent(name)
            if fm.fileExists(atPath: destination.path) {
                guard (try? Data(contentsOf: destination)) == bytes else {
                    throw Problem.conflictingAsset(name)
                }
            } else {
                try bytes.write(to: destination, options: [.atomic])
            }
        }
    }

    static func backupEntries(in storageDirectory: URL) throws -> [[String: String]] {
        let path = folder(in: storageDirectory)
        let fm = FileManager.default
        guard fm.fileExists(atPath: path.path) else { return [] }
        let contents = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [.fileSizeKey])
            .filter { validRelativePath("attachments/" + $0.lastPathComponent) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard contents.count <= 5000 else { throw Problem.backupTooLarge }
        var total = 0
        return try contents.map { asset in
            guard let data = read("attachments/" + asset.lastPathComponent, in: storageDirectory) else {
                throw Problem.missingAsset(asset.lastPathComponent)
            }
            total += data.count
            guard total <= maxBackupImageBytes else { throw Problem.backupTooLarge }
            return ["path": "attachments/" + asset.lastPathComponent, "pngBase64": data.base64EncodedString()]
        }
    }

    static func validatedBackupEntries(_ object: Any?) throws -> [(String, Data)] {
        guard let object else { return [] } // old JSON backups remain readable
        guard let entries = object as? [[String: String]], entries.count <= 5000 else {
            throw Problem.invalidBackup
        }
        var seen = Set<String>()
        var total = 0
        return try entries.map { item in
            guard let path = item["path"], validRelativePath(path), !seen.contains(path),
                  let content = item["pngBase64"], content.utf8.count <= (maxImageBytes * 4 / 3 + 8),
                  let bytes = Data(base64Encoded: content), pngIsValid(bytes) else {
                throw Problem.invalidBackup
            }
            seen.insert(path)
            total += bytes.count
            guard total <= maxBackupImageBytes else { throw Problem.backupTooLarge }
            return (path, bytes)
        }
    }

    // Restore only by a strict generated UUID name. Never overwrite an existing
    // asset; a conflict rejects the import instead of corrupting prior notes.
    // Caller removes returned newly-created paths if DB import rolls back.
    static func installBackupEntries(_ entries: [(String, Data)],
                                     in storageDirectory: URL) throws -> [URL] {
        guard !entries.isEmpty else { return [] }
        let dir = folder(in: storageDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fm = FileManager.default
        var added: [URL] = []
        do {
            for (path, data) in entries {
                guard validRelativePath(path), pngIsValid(data) else { throw Problem.invalidBackup }
                let target = dir.appendingPathComponent(String(path.dropFirst("attachments/".count)))
                if fm.fileExists(atPath: target.path) {
                    guard (try? Data(contentsOf: target)) == data else { throw Problem.conflictingAsset(path) }
                } else {
                    try data.write(to: target, options: [.atomic])
                    added.append(target)
                }
            }
            return added
        } catch {
            for url in added { try? fm.removeItem(at: url) }
            throw error
        }
    }

    static func backupCompanionDirectory(for sqliteBackup: URL) -> URL {
        sqliteBackup.deletingPathExtension().appendingPathExtension("attachments")
    }

    // Snapshot files are immutable, so hard links give constant-space backup
    // companions on the same volume. A copy is used if linking is unavailable.
    // Existing snapshot folders are supplemented for images pasted later in
    // the same 6-hour slot. Old companions are never destructively refreshed.
    static func snapshotCompanion(for sqliteBackup: URL, storageDirectory: URL) throws {
        let fm = FileManager.default
        let source = folder(in: storageDirectory)
        guard fm.fileExists(atPath: source.path) else { return }
        let companion = backupCompanionDirectory(for: sqliteBackup)
        try fm.createDirectory(at: companion, withIntermediateDirectories: true)
        for url in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            guard validRelativePath("attachments/" + url.lastPathComponent),
                  read("attachments/" + url.lastPathComponent, in: storageDirectory) != nil else { continue }
            let target = companion.appendingPathComponent(url.lastPathComponent)
            if !fm.fileExists(atPath: target.path) {
                do { try fm.linkItem(at: url, to: target) }
                catch { try fm.copyItem(at: url, to: target) }
            }
        }
    }
}
