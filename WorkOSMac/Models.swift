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
    var updatedAt: String
    var rawJSON: String

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
        return WorkNote(
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
    }

    var notebookIDs: [String] {
        NotebookMembershipCore.from(WorkOSJSON.dictionary(rawJSON))
    }

    var isMarkdown: Bool { WorkOSJSON.string(WorkOSJSON.dictionary(rawJSON), "bodyFormat") == "markdown" }
    var workosBlocks: [WorkBlock] { WorkBlock.read(WorkOSJSON.items(WorkOSJSON.dictionary(rawJSON), "workosBlocks")) }
    var revisions: [[String: Any]] { WorkOSJSON.items(WorkOSJSON.dictionary(rawJSON), "revisions") }
    var progress: [[String: Any]] { WorkOSJSON.items(WorkOSJSON.dictionary(rawJSON), "progress") }
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
