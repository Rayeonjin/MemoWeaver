import Foundation

@main
struct MarkdownExperimentSmoke {
    static func main() throws {
        let original = WorkNote.from([
            "id": "legacy-html", "title": "", "body": "<p><strong>기존 노트</strong></p>",
            "legacyCustom": "keep", "revisions": [["body": "<p>older</p>"]]
        ])
        assert(!original.isMarkdown)
        assert(original.bodyHTML == "<p><strong>기존 노트</strong></p>")
        assert(original.plainBody.contains("기존 노트"))
        let newNote = WorkNote.make(markdown: true)
        assert(newNote.isMarkdown)
        assert(newNote.bodyHTML.isEmpty)

        let originalMarkdown = """
        # 프로젝트 업무

        <this is literal markdown, not HTML>
        **중요** and $E=mc^2$

        | 항목 | 값 |
        | --- | --- |
        | 거래량 | 12 |

        ```mermaid
        flowchart TD
          A[시작] --> B[완료]
        ```

        ```markmap
        # 프로젝트
        ## 기획
        - 목표
        ```

        ```vega-lite
        {"data":{"values":[{"month":"7월","value":12}]},"mark":"bar","encoding":{"x":{"field":"month"},"y":{"field":"value"}}}
        ```
        """
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("MarkdownExperiment-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let database = try LocalDatabase(directoryOverride: tmp)
        let created = try database.createNote(typeID: "type-note", markdown: true)
        assert(created.isMarkdown)
        let saved = try database.saveNote(created, title: "", bodyHTML: originalMarkdown,
            typeID: created.typeID, bookID: created.bookID, noteDate: created.noteDate,
            status: created.status, sourceURL: "", pinned: false, archived: false,
            checkpoint: true)
        assert(saved.bodyHTML == originalMarkdown)
        assert(saved.isMarkdown && saved.plainBody.contains("**중요**"))
        assert(saved.visibleTitle == "프로젝트 업무")
        assert((WorkOSJSON.dictionary(saved.rawJSON)["bodyFormat"] as? String) == "markdown")
        assert(saved.revisions.count >= 1)
        let reopened = try LocalDatabase(directoryOverride: tmp)
        let restored = try reopened.notes().first(where: { $0.id == saved.id })!
        assert(restored.isMarkdown && restored.bodyHTML == originalMarkdown)
        assert(restored.plainBody.contains("<this is literal markdown"))
        assert(restored.revisions.count == saved.revisions.count)
        let exported = try database.exportBrowserCompatibleJSON()
        let json = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        let backupNotes = json["notes"] as! [[String: Any]]
        assert(backupNotes.contains(where: { ($0["id"] as? String) == saved.id &&
            ($0["body"] as? String) == originalMarkdown && ($0["bodyFormat"] as? String) == "markdown" }))

        assert(NoteDocuments.markdown(note: restored) == originalMarkdown,
               "Exported Markdown must remain byte-for-byte the original")
        let htmlDocument = NoteDocuments.html(note: restored)
        assert(htmlDocument.contains("Markmap 기본 계층도"))
        assert(htmlDocument.contains("MathML") || htmlDocument.contains("formula-inline"))
        assert(!htmlDocument.contains("<this is literal markdown"))
        let rendered = MarkdownPreviewCore.render(originalMarkdown)
        assert(rendered.hasMath)
        assert(rendered.html.contains("<strong>중요</strong>"))
        assert(rendered.html.contains("<table"))
        assert(rendered.html.contains("formula-inline"))
        assert(rendered.html.contains("<svg"))
        assert(MarkdownPreviewCore.render("본문[^1]\n\n[^1]: 확인 근거").html.contains("<sup>"))
        assert(MarkdownPreviewCore.render("> [!WARNING]\n> 저장 실패에 유의").html.contains("class='callout'"))
        assert(MarkdownPreviewCore.render("```unknown\n<iframe>\n```").html.contains("&lt;iframe&gt;"))
        assert(MarkdownPasteCore.markdownTable(from: "A\tB\n" + String(repeating: "a\tb\n", count: 301)) == nil,
               "Large clipboard must stay literal, never silently truncate rows")
        assert(!rendered.html.contains("<this is literal"))
        assert(rendered.html.contains("&lt;this is literal"))
        let hostile = MarkdownPreviewCore.render("<script>alert('oops')</script>\n\n```javascript\nwindow.location='https://evil.example'\n```")
        assert(!hostile.html.contains("<script>"))
        assert(hostile.html.contains("&lt;script&gt;"))
        let table = MarkdownPasteCore.markdownTable(from: "업무\t담당\t상태\n분석\t김철수\t완료\n점검\t\t진행")!
        assert(table.contains("| 업무 | 담당 | 상태 |"))
        assert(table.contains("| 점검 |  | 진행 |"))
        let escaped = MarkdownPasteCore.markdownTable(from: "제목\t내용\n가\t\"A\tB\"\n나\t\"두\n줄\"")!
        assert(escaped.contains("A<br>") == false)
        assert(escaped.contains("A"))
        assert(escaped.contains("두<br>줄"))
        assert(MarkdownPasteCore.markdownTable(from: "한 줄") == nil)
        assert(MarkdownTemplates.insertion(for: .mermaid).source.contains("```mermaid"))
        assert(MarkdownTemplates.insertion(for: .equation).source.contains("$$"))
        assert(MarkdownTemplates.insertion(for: .markmap).source.contains("```markmap"))
        assert(MarkdownTemplates.insertion(for: .chart).source.contains("```mermaid"))
        assert(MarkdownTemplates.insertion(for: .chart).source.contains("xychart-beta"))
        assert(rendered.html.contains("legacy-chart"), "Historical Vega source must stay visible and unmodified")
        print("PASS Markdown v0.9.0: legacy HTML intact; raw source/metadata/revisions/backup roundtrip; Markdown preview; GFM/LaTeX/Mermaid/Markmap/retired Vega source preserved; Unicode TSV and template insertion")
    }
}
