import Foundation

// The legacy schema remains exportable so browser data can be moved without discarding unknown fields.
enum WorkOSJSON {
    static func dictionary(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return [:] }
        return dict
    }

    static func encode(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
        return String(decoding: data, as: UTF8.self)
    }

    static func string(_ dict: [String: Any], _ key: String, default fallback: String = "") -> String {
        dict[key] as? String ?? fallback
    }

    static func bool(_ dict: [String: Any], _ key: String) -> Bool {
        if let value = dict[key] as? Bool { return value }
        if let value = dict[key] as? NSNumber { return value.boolValue }
        return false
    }

    static func items(_ dict: [String: Any], _ key: String) -> [[String: Any]] {
        dict[key] as? [[String: Any]] ?? []
    }
}

enum WorkOSDate {
    static func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    static func day(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func parseDay(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date()
    }
    static func display(_ value: String) -> String {
        String(value.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }
    static func localDay(_ iso: String, calendar: Calendar = .current) -> String? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = parser.date(from: iso) ?? {
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: iso)
        }()
        guard let date = parsed else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func localTime(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date: Date? = parser.date(from: iso) ?? {
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: iso)
        }()
        guard let date else { return String(display(iso).suffix(5)) }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct WorkNote: Identifiable, Hashable {
    var id: String
    var title: String
    var bodyHTML: String
    var plainBody: String
    var typeID: String
    var bookID: String
    var noteDate: String
    var status: String
    var sourceURL: String
    var pinned: Bool
    var archived: Bool
    var deletedAt: String
    var createdAt: String
    var updatedAt: String {
        didSet {
            cachedLocalUpdatedDay = WorkOSDate.localDay(updatedAt) ?? String(updatedAt.prefix(10))
            cachedUpdateTimeZone = .current
        }
    }
    var rawJSON: String {
        didSet { decodedPayload = WorkOSJSON.dictionary(rawJSON) }
    }
    // Decode once per immutable database snapshot, not once per UI property read.
    // rawJSON remains canonical for unknown fields and backward-compatible exports.
    private var decodedPayload: [String: Any] = [:]
    private var cachedLocalUpdatedDay = ""
    private var cachedUpdateTimeZone = TimeZone.current
    var localUpdatedDay: String {
        if cachedUpdateTimeZone == .current { return cachedLocalUpdatedDay }
        return WorkOSDate.localDay(updatedAt) ?? String(updatedAt.prefix(10))
    }

    static func == (lhs: WorkNote, rhs: WorkNote) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.bodyHTML == rhs.bodyHTML &&
        lhs.plainBody == rhs.plainBody && lhs.typeID == rhs.typeID && lhs.bookID == rhs.bookID &&
        lhs.noteDate == rhs.noteDate && lhs.status == rhs.status && lhs.sourceURL == rhs.sourceURL &&
        lhs.pinned == rhs.pinned && lhs.archived == rhs.archived && lhs.deletedAt == rhs.deletedAt &&
        lhs.createdAt == rhs.createdAt && lhs.updatedAt == rhs.updatedAt && lhs.rawJSON == rhs.rawJSON
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id); hasher.combine(title); hasher.combine(bodyHTML)
        hasher.combine(plainBody); hasher.combine(typeID); hasher.combine(bookID)
        hasher.combine(noteDate); hasher.combine(status); hasher.combine(sourceURL)
        hasher.combine(pinned); hasher.combine(archived); hasher.combine(deletedAt)
        hasher.combine(createdAt); hasher.combine(updatedAt); hasher.combine(rawJSON)
    }

    static func make(typeID: String = "type-note", markdown: Bool = false) -> WorkNote {
        let timestamp = WorkOSDate.now()
        let noteID = UUID().uuidString
        var raw: [String: Any] = [
            "id": noteID, "title": "", "body": "", "typeId": typeID, "bookId": "", "notebookIds": [],
            "noteDate": WorkOSDate.day(), "status": "진행 중", "createdAt": timestamp,
            "updatedAt": timestamp, "revisions": [], "progress": [], "links": [],
            "sourceUrl": "", "archived": false, "pinned": false
        ]
        if markdown {
            raw["bodyFormat"] = "markdown"
            if typeID == "type-meeting" {
                raw["body"] = "## 회의 목적\n\n## 논의 내용\n\n## 결정 및 후속 업무\n"
            } else if typeID == "type-task" {
                raw["body"] = "- [ ] 할 일\n"
            }
        } else if typeID == "type-meeting" {
            raw["body"] = "<h2>회의 목적</h2><p></p><h2>논의 내용</h2><p></p><h2>결정 및 후속 업무</h2><p></p>"
        } else if typeID == "type-task" {
            raw["body"] = "<p>☐ 할 일</p>"
        }
        return from(raw)
    }

    static func from(_ dict: [String: Any]) -> WorkNote {
        let html = WorkOSJSON.string(dict, "body")
        let id = WorkOSJSON.string(dict, "id", default: UUID().uuidString)
        var note = WorkNote(
            id: id,
            title: WorkOSJSON.string(dict, "title"),
            bodyHTML: html,
            plainBody: ((WorkOSJSON.string(dict, "bodyFormat") == "markdown" ? html : HTMLText.plain(html)) + "\n" + WorkBlock.read(WorkOSJSON.items(dict, "workosBlocks")).map(\.source).joined(separator: "\n")).trimmingCharacters(in: .whitespacesAndNewlines),
            typeID: WorkOSJSON.string(dict, "typeId", default: "type-note"),
            bookID: NotebookMembershipCore.from(dict).first ?? "",
            noteDate: WorkOSJSON.string(dict, "noteDate", default: WorkOSDate.day()),
            status: WorkOSJSON.string(dict, "status", default: "진행 중"),
            sourceURL: WorkOSJSON.string(dict, "sourceUrl"),
            pinned: WorkOSJSON.bool(dict, "pinned"),
            archived: WorkOSJSON.bool(dict, "archived"),
            deletedAt: WorkOSJSON.string(dict, "deletedAt"),
            createdAt: WorkOSJSON.string(dict, "createdAt", default: WorkOSDate.now()),
            updatedAt: WorkOSJSON.string(dict, "updatedAt", default: WorkOSDate.now()),
            rawJSON: (try? WorkOSJSON.encode(dict)) ?? "{}"
        )
        note.decodedPayload = dict
        note.cachedLocalUpdatedDay = WorkOSDate.localDay(note.updatedAt) ?? String(note.updatedAt.prefix(10))
        return note
    }

    var wikiLinkTargets: [String: String] { decodedPayload["wikiLinkTargets"] as? [String: String] ?? [:] }

    var notebookIDs: [String] {
        NotebookMembershipCore.from(decodedPayload)
    }

    var isMarkdown: Bool { WorkOSJSON.string(decodedPayload, "bodyFormat") == "markdown" }
    var workosBlocks: [WorkBlock] { WorkBlock.read(WorkOSJSON.items(decodedPayload, "workosBlocks")) }
    var revisions: [[String: Any]] { WorkOSJSON.items(decodedPayload, "revisions") }
    var progress: [[String: Any]] { WorkOSJSON.items(decodedPayload, "progress") }
    var visibleTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        if isMarkdown && !plainBody.isEmpty {
            let first = WorkOSQuickCapture.inferredTitle(plainBody)
            let cleaned = first.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            return cleaned.isEmpty ? "새 메모" : cleaned
        }
        if WorkOSQuickCapture.isNewCapture(self) { return WorkOSQuickCapture.inferredTitle(plainBody) }
        if !plainBody.isEmpty { return WorkOSQuickCapture.inferredTitle(plainBody) }
        return "새 메모"
    }
}

struct WorkCategory: Identifiable, Hashable {
    var id: String
    var name: String
    var template: String
    var icon: String
    var rawJSON: String

    static func from(_ dict: [String: Any]) -> WorkCategory {
        WorkCategory(
            id: WorkOSJSON.string(dict, "id", default: UUID().uuidString),
            name: WorkOSJSON.string(dict, "name", default: "이름 없음"),
            template: WorkOSJSON.string(dict, "template", default: "blank"),
            icon: WorkOSJSON.string(dict, "icon", default: "folder"),
            rawJSON: (try? WorkOSJSON.encode(dict)) ?? "{}"
        )
    }
}

struct WorkArchive: Identifiable, Hashable {
    var id: String
    var name: String
    var lineCount: Int
    var addedAt: String
}

struct WorkChunk: Identifiable {
    var id: Int64
    var sourceID: String
    var title: String
    var text: String
    var fromLine: Int
    var toLine: Int
}

struct MemorySource: Identifiable, Hashable {
    var id: String
    var kind: String     // note | archive | progress | revision
    var sourceID: String
    var title: String
    var subtitle: String
    var text: String
    var fromLine: Int
    var toLine: Int
    var score: Int
}

enum HTMLText {
    // Display/search text is derived from rich HTML on every read. Keep the
    // original HTML (including its style sheet) unchanged in raw_json.
    // Cocoa's HTML writer puts p.p1 / span.s1 CSS rules inside <head>/<style>;
    // without removing these non-visible sections, untitled notes display CSS
    // as their inferred title and in the note-list preview.
    static func plain(_ html: String) -> String {
        var text = html
        for pattern in [
            #"(?is)<!--.*?-->"#,
            #"(?is)<head\b[^>]*>.*?</head\s*>"#,
            #"(?is)<(style|script|noscript|template)\b[^>]*>.*?</\1\s*>"#
        ] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: #"(?i)<br\b[^>]*>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)</(p|div|li|h[1-6]|tr)\s*>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
        for (from, to) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"),
                           ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Wiki links remain plain Markdown. A saved title-to-ID binding preserves a
// manually typed [[title]] through renames; picker links carry an explicit ID.
struct MemoWeaverWikiCandidate: Identifiable, Hashable {
    let id: String
    let title: String
}
struct MemoWeaverWikiReference {
    let target: String
    let label: String
    let range: NSRange
    let line: Int
    let context: String
}
enum MemoWeaverWikiLinks {
    private static let expression = try! NSRegularExpression(pattern: #"(?<!\\)\[\[([^\[\]\n]{1,500})\]\]"#)
    private static let inlineCode = try! NSRegularExpression(pattern: #"(`+).*?\1"#)
    private static let inlineMath = try! NSRegularExpression(pattern: #"(?<!\\)\$([^$\n]+)\$"#)
    static func references(in text: String) -> [MemoWeaverWikiReference] {
        guard text.contains("[[") else { return [] }
        var result: [MemoWeaverWikiReference] = []
        var fence: Character?
        var fenceCount = 0
        var displayMath = false
        var offset = 0
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            defer { offset += (line as NSString).length + 1 }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if displayMath {
                if trimmed == "$$" { displayMath = false }
                continue
            }
            let character = trimmed.first
            let run = trimmed.prefix { $0 == character }.count
            if let character, (character == "`" || character == "~"), run >= 3 {
                if fence == nil { fence = character; fenceCount = run }
                else if fence == character && run >= fenceCount && trimmed.dropFirst(run).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fence = nil }
                continue
            }
            guard fence == nil else { continue }
            // Match the preview's display-math blocks, including an unclosed
            // block (which is displayed as math through the end of the note).
            if trimmed.hasPrefix("$$") {
                displayMath = trimmed == "$$"
                continue
            }
            let ns = line as NSString
            // Protect code before math, as the preview does. Equal UTF-16
            // length keeps original link ranges and source-line jumps intact.
            var masked = line
            for protected in [inlineCode, inlineMath] {
                let value = masked as NSString
                for match in protected.matches(in: masked, range: NSRange(location: 0, length: value.length)).reversed() {
                    if let range = Range(match.range, in: masked) { masked.replaceSubrange(range, with: String(repeating: " ", count: match.range.length)) }
                }
            }
            for match in expression.matches(in: masked, range: NSRange(location: 0, length: (masked as NSString).length)) {
                let content = ns.substring(with: match.range(at: 1))
                let parts = content.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                let target = parts[0].trimmingCharacters(in: .whitespaces)
                guard !target.isEmpty else { continue }
                result.append(.init(target: target, label: parts.count == 2 ? parts[1] : target,
                    range: NSRange(location: offset + match.range.location, length: match.range.length),
                    line: index + 1, context: String(line.prefix(240))))
            }
        }
        return result
    }
    static func bindings(_ note: WorkNote) -> [String: String] {
        note.wikiLinkTargets
    }
    static func resolve(_ target: String, bindings: [String: String], candidates: [MemoWeaverWikiCandidate]) -> String? {
        // A bound title must never be reinterpreted as another note's ID.
        // If the bound note is unavailable, keep the link unresolved.
        if let id = bindings[target] { return candidates.contains(where: { $0.id == id }) ? id : nil }
        if candidates.contains(where: { $0.id == target }) { return target }
        let matches = candidates.filter { $0.title == target }
        return matches.count == 1 ? matches[0].id : nil
    }
    // Read-only exports/reference readers cannot depend on the active editor's
    // identity when opening a renamed title link. Expand saved bindings only
    // in the rendered copy, leaving the authored Markdown untouched.
    static func previewSource(_ note: WorkNote) -> String {
        var text = note.bodyHTML
        let bound = note.wikiLinkTargets
        for reference in references(in: text).reversed() {
            guard let id = bound[reference.target], let range = Range(reference.range, in: text) else { continue }
            text.replaceSubrange(range, with: source(.init(id: id, title: reference.label)))
        }
        return text
    }
    static func source(_ candidate: MemoWeaverWikiCandidate) -> String {
        let title = candidate.title.replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")").replacingOccurrences(of: "|", with: "·")
            .replacingOccurrences(of: "\n", with: " ")
        return "[[\(candidate.id)|\(title)]]"
    }
}
