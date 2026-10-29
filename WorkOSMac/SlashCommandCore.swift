import Foundation

/// Discoverable *source* snippets for the native NSTextView editor.
/// The featured menu favors syntax people are unlikely to memorize. Basic
/// Markdown commands remain searchable so existing / workflows keep working.
/// All offsets are UTF-16, as required by NSTextView and Korean input.
enum SlashCommandCore {
    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let keywords: String
        let source: String
        let caretBack: Int
        let symbol: String
        let isBlock: Bool
    }

    struct Trigger: Equatable {
        let range: NSRange // Only slash and its query, never leading whitespace.
        let query: String
    }

    struct Insertion: Equatable {
        let source: String
        let caretBack: Int
    }

    private static func snippet(_ id: String, _ title: String, _ description: String,
                                _ keywords: String, _ source: String, _ symbol: String,
                                focus: String? = nil, isBlock: Bool = true) -> Item {
        let ns = source as NSString
        let match = focus.map { ns.range(of: $0) }
        let back = match?.location == NSNotFound || match == nil ? 0 : ns.length - match!.location
        return Item(id: id, title: title, description: description,
                    keywords: keywords, source: source, caretBack: back,
                    symbol: symbol, isBlock: isBlock)
    }

    /// Suggestions immediately after '/'. No 8-item truncation: the palette
    /// scrolls through the complete set and keeps keyboard selection visible.
    static let featured: [Item] = [
        snippet("table", "표 만들기", "Markdown 표 2열", "table 엑셀 spreadsheet 표", "| 항목 | 내용 |\n| --- | --- |\n| 값 | 설명 |", "tablecells", focus: "값"),
        snippet("code", "코드 블록", "언어가 있는 코드 영역", "code fence 코드 프로그램", "```text\n내용\n```", "chevron.left.forwardslash.chevron.right", focus: "내용"),
        snippet("math", "수식 블록", "LaTeX 수식 영역", "math latex katex equation 수식", "$$\nE = mc^2\n$$", "sum", focus: "E = mc^2"),
        snippet("inline-math", "문장 안 수식", "$...$ 인라인 수식", "inline math 수식 인라인", "$x^2$", "function", focus: "x^2", isBlock: false),
        snippet("mermaid", "Mermaid 흐름도", "조건·분기 다이어그램", "mermaid flowchart graph 흐름도", "```mermaid\nflowchart TD\n  A[시작] --> B{조건}\n  B -->|예| C[처리]\n  B -->|아니오| D[종료]\n```", "point.3.connected.trianglepath.dotted", focus: "시작"),
        snippet("mermaid-sequence", "Mermaid 시퀀스", "주고받는 메시지 흐름", "mermaid sequence 시퀀스 메시지", "```mermaid\nsequenceDiagram\n  participant A as 요청자\n  participant B as 담당자\n  A->>B: 검토 요청\n  B-->>A: 검토 결과\n```", "arrow.left.arrow.right", focus: "요청자"),
        snippet("mermaid-gantt", "Mermaid 간트", "업무 일정 다이어그램", "mermaid gantt 간트 일정", "```mermaid\ngantt\n  title 프로젝트 일정\n  dateFormat YYYY-MM-DD\n  section 준비\n  조사 :a1, 2026-10-23, 3d\n```", "calendar", focus: "프로젝트 일정"),
        snippet("mermaid-timeline", "Mermaid 타임라인", "사건·기억의 시간 흐름", "mermaid timeline 타임라인 시계열", "```mermaid\ntimeline\n  title 업무의 변화\n  2024 : 문제 발견\n  2025 : 원인 검토\n  2026 : 결과 확인\n```", "clock.arrow.circlepath", focus: "업무의 변화"),
        snippet("markmap", "마인드맵", "주제별 가지 구조", "markmap mindmap 마인드맵", "```markmap\n# 중심 주제\n## 첫 번째 가지\n- 세부 사항\n## 두 번째 가지\n- 다음 할 일\n```", "circle.hexagongrid", focus: "중심 주제"),
        snippet("chart", "Mermaid 막대그래프", "XY 범주형 막대 차트 · 한글 축 지원", "mermaid chart xychart-beta bar 막대그래프 차트", "```mermaid\nxychart-beta\n  title \"월별 업무량\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  bar [12, 28, 21, 40]\n```", "chart.bar", focus: "1월"),
        snippet("chart-line", "Mermaid 선그래프", "XY 시간 흐름 선 차트", "mermaid chart xychart-beta line 선그래프 차트", "```mermaid\nxychart-beta\n  title \"월별 추이\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  line [12, 28, 21, 40]\n```", "chart.xyaxis.line", focus: "1월"),
        snippet("chart-mixed", "Mermaid 혼합그래프", "XY 막대 + 선 그래프", "mermaid chart xychart-beta bar line 혼합 차트", "```mermaid\nxychart-beta\n  title \"실적과 추이\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  bar [12, 28, 21, 40]\n  line [10, 19, 29, 35]\n```", "chart.xyaxis.line", focus: "1월"),
        snippet("chart-pie", "Mermaid 원형 차트", "구성 비율과 숫자", "mermaid pie chart 원형 파이 차트", "```mermaid\npie showData\n  title 업무 구성\n  \"기획\" : 40\n  \"실행\" : 35\n  \"검토\" : 25\n```", "chart.pie", focus: "기획"),
        snippet("note", "안내 박스", "[!NOTE] 강조", "callout note 안내 노트", "> [!NOTE]\n> 내용을 적으세요.", "info.circle", focus: "내용을"),
        snippet("tip", "팁 박스", "[!TIP] 강조", "callout tip 팁 도움", "> [!TIP]\n> 유용한 내용을 적으세요.", "lightbulb", focus: "유용한"),
        snippet("important", "중요 박스", "[!IMPORTANT] 강조", "callout important 중요 강조", "> [!IMPORTANT]\n> 중요한 내용을 적으세요.", "exclamationmark.circle", focus: "중요한"),
        snippet("warning", "경고 박스", "[!WARNING] 강조", "callout warning 경고 주의", "> [!WARNING]\n> 주의할 내용을 적으세요.", "exclamationmark.triangle", focus: "주의할"),
        snippet("caution", "주의 박스", "[!CAUTION] 강조", "callout caution 위험 주의", "> [!CAUTION]\n> 위험 요소를 적으세요.", "hand.raised", focus: "위험"),
        snippet("footnote", "각주", "원문 근거·출처 표기", "footnote citation 각주 출처", "본문의 근거[^1]\n\n[^1]: 출처를 적으세요.", "text.book.closed", focus: "출처"),
        snippet("link", "링크", "[표시 글자](URL)", "link url 링크", "[텍스트](https://)", "link", focus: "https://", isBlock: false)
    ]

    /// Existing keyboard shortcuts remain searchable, but do not crowd the
    /// no-query menu with syntax a Markdown user already knows.
    static let basics: [Item] = [
        snippet("h1", "제목 1", "큰 제목", "heading h1 제목", "# ", "textformat.size.larger"),
        snippet("h2", "제목 2", "소제목", "heading h2 소제목", "## ", "textformat.size"),
        snippet("bullet", "글머리 목록", "- 항목", "bullet list 목록", "- ", "list.bullet"),
        snippet("number", "번호 목록", "1. 항목", "number ordered 목록", "1. ", "list.number"),
        snippet("check", "체크 항목", "완료 표시", "task todo checklist 체크", "- [ ] ", "checklist"),
        snippet("quote", "인용문", "> 인용", "quote 인용", "> ", "text.quote"),
        snippet("divider", "구분선", "---", "divider separator 구분", "---\n", "minus")
    ]

    static let advanced: [Item] = {
        let markdownItems = MemoWeaverMarkdownExtras.Group.allCases.flatMap(MemoWeaverMarkdownExtras.items)
            .map { entry in
                let req = entry.insertion()
                return Item(id: "extra-" + entry.id, title: entry.title,
                    description: "추가 Markdown 문법", keywords: entry.title + " markdown",
                    source: entry.source, caretBack: req.caretBack,
                    symbol: "text.badge.plus", isBlock: !entry.inline)
            }
        let codeItems = MemoWeaverCodeTemplates.allCases.map { language in
            let req = language.insertion()
            return Item(id: "code-" + language.rawValue, title: language.title + " 코드 블록",
                description: "언어 지정 코드 펜스", keywords: "code fence " + language.rawValue,
                source: req.source, caretBack: req.caretBack,
                symbol: "chevron.left.forwardslash.chevron.right", isBlock: true)
        }
        let diagrams = MermaidDiagramTemplates.Kind.allCases.map { kind in
            let req = MermaidDiagramTemplates.insertion(for: kind)
            return Item(id: "diagram-" + kind.rawValue, title: kind.title,
                description: "Mermaid 도식 템플릿", keywords: "mermaid diagram " + kind.rawValue,
                source: req.source, caretBack: req.caretBack,
                symbol: "square.stack.3d.up", isBlock: true)
        }
        let quadrant = MermaidChartTemplates.insertion(for: .quadrant)
        let quadrantItem = Item(id: "chart-quadrant", title: "Mermaid 사분면 차트",
            description: "2차원 우선순위 매트릭스", keywords: "mermaid quadrant chart 사분면",
            source: quadrant.source, caretBack: quadrant.caretBack,
            symbol: "square.grid.2x2", isBlock: true)
        return markdownItems + codeItems + diagrams + [quadrantItem]
    }()

    static let items: [Item] = featured + advanced + basics

    /// Trigger only at a word boundary; preserve URLs, file paths, escapes,
    /// double slashes and normal prose. No source is changed until selection.
    static func trigger(in source: String, caretUTF16: Int, selectionLength: Int = 0) -> Trigger? {
        let ns = source as NSString
        guard selectionLength == 0, caretUTF16 > 0, caretUTF16 <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: caretUTF16, length: 0))
        let prefix = ns.substring(with: NSRange(location: line.location,
                                                 length: caretUTF16 - line.location))
        guard let slash = prefix.range(of: "/", options: .backwards) else { return nil }
        let before = String(prefix[..<slash.lowerBound])
        let query = String(prefix[slash.upperBound...])
        guard before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\t") else { return nil }
        guard !before.hasSuffix("\\") && query.utf16.count <= 28,
              !query.contains(where: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" || $0 == "/" }) else { return nil }
        let offset = line.location + (before as NSString).length
        return Trigger(range: NSRange(location: offset,
                                      length: (("/" + query) as NSString).length), query: query)
    }

    static func filter(_ candidates: [Item], query: String, limit: Int = Int.max) -> [Item] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = candidates.filter { item in
            needle.isEmpty || (item.title + " " + item.description + " " + item.keywords + " " + item.id)
                .lowercased().localizedStandardContains(needle)
        }
        return Array(matching.prefix(max(0, limit)))
    }

    static func matches(_ query: String, limit: Int = Int.max) -> [Item] {
        // Empty query shows *all featured* commands; querying also searches
        // familiar Markdown commands rather than removing existing workflows.
        filter(query.isEmpty ? featured : items, query: query, limit: limit)
    }

    /// A snippet can start within existing prose. Fenced/block templates are
    /// separated from that prose; inline snippets do not add a paragraph.
    /// Mermaid multiline snippets inherit the indentation of the '/' line.
    static func prepare(_ item: Item, contextIsNormal: Bool,
                        linePrefix: String) -> Insertion {
        let original = item.source as NSString
        let focus = max(0, min(original.length, original.length - item.caretBack))
        var source = item.source
        var caret = focus
        if !contextIsNormal {
            let indentation = String(linePrefix.prefix(while: { $0 == " " || $0 == "\t" }))
            if !indentation.isEmpty && source.contains("\n") {
                let before = original.substring(to: focus)
                caret += before.filter { $0 == "\n" }.count * (indentation as NSString).length
                source = source.replacingOccurrences(of: "\n", with: "\n" + indentation)
            }
        } else if item.isBlock && !linePrefix.trimmingCharacters(in: .whitespaces).isEmpty {
            source = "\n\n" + source
            caret += 2
        }
        return Insertion(source: source, caretBack: (source as NSString).length - caret)
    }
}
