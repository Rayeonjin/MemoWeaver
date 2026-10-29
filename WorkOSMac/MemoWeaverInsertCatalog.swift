import Foundation

// Each action inserts portable Markdown source. No private rich-text format,
// no network access and no stored-note migration. The editor's normal undo,
// auto-save and preview events are used for every insertion.
struct MemoWeaverSourceTemplate: Identifiable {
    let id: String
    let title: String
    let source: String
    let focus: String
    let inline: Bool
    let wrapsSelection: Bool
    let beginsOnNewLine: Bool

    init(_ id: String, _ title: String, _ source: String, focus: String,
         inline: Bool = false, wraps: Bool = false, newline: Bool = false) {
        self.id = id
        self.title = title
        self.source = source
        self.focus = focus
        self.inline = inline
        self.wrapsSelection = wraps
        self.beginsOnNewLine = newline
    }

    func insertion() -> MarkdownInsertRequest {
        let ns = source as NSString
        let range = ns.range(of: focus)
        return MarkdownInsertRequest(source: source,
            caretBack: range.location == NSNotFound ? 0 : ns.length - range.location,
            inlineSnippet: inline, wrapsSelection: wrapsSelection,
            beginsOnNewLine: beginsOnNewLine)
    }
}

// Standard/CommonMark/GFM first; extended syntax is included ONLY when the
// MemoWeaver preview explicitly implements it (e.g. ==highlight==, callouts).
enum MemoWeaverMarkdownExtras {
    enum Group: String, CaseIterable {
        case text = "본문·서식"
        case blocks = "블록·참고"
        case math = "수식"
    }

    static func items(_ group: Group) -> [MemoWeaverSourceTemplate] {
        switch group {
        case .text:
            return [
                .init("inline-code", "인라인 코드", "`x`", focus: "x", inline: true, wraps: true),
                .init("strike", "취소선", "~~x~~", focus: "x", inline: true, wraps: true),
                .init("highlight", "형광 강조 (확장)", "==x==", focus: "x", inline: true, wraps: true),
                .init("link", "링크", "[링크명](https://example.com)", focus: "링크명", inline: true),
                .init("checkbox", "체크리스트", "- [ ] 해야 할 일\n- [ ] 다음 할 일\n", focus: "해야 할 일"),
                .init("quote", "인용 블록", "> 인용 내용을 적으세요.\n", focus: "인용 내용을")
            ]
        case .blocks:
            return [
                .init("table-align", "정렬 표 (좌·우)", "| 왼쪽 | 오른쪽 |\n| :--- | ---: |\n| 내용 | 100 |\n", focus: "내용"),
                .init("footnote", "각주·출처", "주장에 대한 근거[^1]\n\n[^1]: 출처를 적으세요.\n", focus: "출처를"),
                .init("callout-note", "메모 강조", "> [!NOTE]\n> 참고 내용을 적으세요.\n", focus: "참고 내용"),
                .init("callout-tip", "팁 강조", "> [!TIP]\n> 유용한 내용을 적으세요.\n", focus: "유용한"),
                .init("callout-warning", "경고 강조", "> [!WARNING]\n> 주의할 내용을 적으세요.\n", focus: "주의할"),
                .init("callout-fold", "접을 수 있는 메모 (확장)", "> [!NOTE]- 접기 제목\n> 접힌 내용을 적으세요.\n", focus: "접기 제목")
            ]
        case .math:
            return [
                .init("inline-math", "인라인 수식", "$x^2$", focus: "x^2", inline: true),
                .init("math-gathered", "여러 줄 수식", "$$\n\\begin{gathered}\na+b=c \\\\\nd+e=f\n\\end{gathered}\n$$\n", focus: "a+b=c"),
                .init("math-aligned", "등호 정렬 수식", "$$\n\\begin{aligned}\na &= b+c \\\\\nd &= e+f\n\\end{aligned}\n$$\n", focus: "a &=")
            ]
        }
    }
}

enum MemoWeaverCodeTemplates: String, CaseIterable {
    case text, swift, python, javascript, typescript, json, sql, bash, zsh,
         html, css, yaml, markdown, diff, rust, go, java, kotlin, cpp, c, ruby

    var title: String {
        switch self {
        case .text: return "일반 텍스트"
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .sql: return "SQL"
        case .bash: return "Bash"
        case .zsh: return "Zsh"
        case .html: return "HTML"
        case .css: return "CSS"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .diff: return "Diff"
        case .rust: return "Rust"
        case .go: return "Go"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .cpp: return "C++"
        case .c: return "C"
        case .ruby: return "Ruby"
        }
    }
    var language: String { rawValue }
    func insertion() -> MarkdownInsertRequest {
        let source = "```\(language)\n코드를 입력하세요\n```\n"
        let ns = source as NSString
        let range = ns.range(of: "코드를 입력하세요")
        return MarkdownInsertRequest(source: source, caretBack: ns.length - range.location)
    }
}

// Contextual editing helpers are deliberately per dialect, so selecting an
// ER snippet cannot insert a flowchart-only arrow into an ER diagram.
enum MemoWeaverDiagramExtraTools {
    static func items(for context: MarkdownEditingContext) -> [MemoWeaverSourceTemplate] {
        switch context {
        case .math:
            return [
                .init("math-boxed", "박스 수식", #"\boxed{x+y=z}"#, focus: "x+y=z", inline: true),
                .init("math-underbrace", "아래 묶음", #"\underbrace{a+b}_{설명}"#, focus: "a+b", inline: true),
                .init("math-overbrace", "위 묶음", #"\overbrace{a+b}^{설명}"#, focus: "a+b", inline: true),
                .init("math-array", "3열 배열", "\\begin{array}{ccc}a & b & c \\\\ d & e & f\\end{array}", focus: "a &", inline: true)
            ]
        case .mermaid:
            return [
                .init("flow-left-right", "좌→우 방향", "flowchart LR", focus: "LR", inline: true, newline: true),
                .init("flow-top-down", "위→아래 방향", "flowchart TD", focus: "TD", inline: true, newline: true),
                .init("flow-stadium", "시작·끝 노드", "S([시작/완료])", focus: "시작", inline: true, newline: true),
                .init("flow-edges", "점선·레이블 연결", "A -. 설명 .-> B", focus: "설명", inline: true, newline: true),
                .init("flow-style", "노드 색상", "style A fill:#e0ecff,stroke:#6282bb,stroke-width:2px", focus: "#e0ecff", inline: true, newline: true),
                .init("flow-class", "노드 스타일 클래스", "classDef primary fill:#e0ecff,stroke:#6282bb,color:#182b4d\nclass A primary", focus: "primary", inline: true, newline: true)
            ]
        case .mermaidClass:
            return [
                .init("class-new", "클래스 추가", "class NewClass {\n  +String name\n  +save()\n}", focus: "NewClass", inline: true, newline: true),
                .init("class-inherit", "상속 관계", "Parent <|-- Child", focus: "Parent", inline: true, newline: true),
                .init("class-compose", "합성 관계", "Owner *-- Item", focus: "Owner", inline: true, newline: true),
                .init("class-card", "다중성", "Notebook \"1\" --> \"*\" Note : contains", focus: "Notebook", inline: true, newline: true)
            ]
        case .mermaidState:
            return [
                .init("state-new", "상태", "state \"검토 중\" as Review", focus: "검토 중", inline: true, newline: true),
                .init("state-start", "시작 전이", "[*] --> Draft", focus: "Draft", inline: true, newline: true),
                .init("state-link", "상태 전이", "Draft --> Review: 제출", focus: "제출", inline: true, newline: true),
                .init("state-end", "종료 상태", "Done --> [*]", focus: "Done", inline: true, newline: true)
            ]
        case .mermaidER:
            return [
                .init("er-entity", "엔터티 필드", "NOTE {\n  string id\n  string title\n}", focus: "NOTE", inline: true, newline: true),
                .init("er-relation", "일대다 관계", "NOTEBOOK ||--o{ NOTE : contains", focus: "contains", inline: true, newline: true),
                .init("er-one-one", "일대일 관계", "USER ||--|| PROFILE : owns", focus: "owns", inline: true, newline: true)
            ]
        case .mermaidGit:
            return [
                .init("git-commit", "커밋", "commit id: \"변경 내용\"", focus: "변경 내용", inline: true, newline: true),
                .init("git-branch", "브랜치", "branch feature", focus: "feature", inline: true, newline: true),
                .init("git-switch", "브랜치 이동", "checkout feature", focus: "feature", inline: true, newline: true),
                .init("git-merge", "병합", "merge feature", focus: "feature", inline: true, newline: true)
            ]
        case .mermaidJourney:
            return [
                .init("journey-section", "단계", "section 사용 단계", focus: "사용 단계", inline: true, newline: true),
                .init("journey-task", "사용자 행동·점수", "메모 작성: 5: 사용자", focus: "메모 작성", inline: true, newline: true)
            ]
        case .mermaidQuadrant:
            return [
                .init("quadrant-axis", "X축", "x-axis 낮은 효과 --> 높은 효과", focus: "낮은 효과", inline: true, newline: true),
                .init("quadrant-y", "Y축", "y-axis 낮은 비용 --> 높은 비용", focus: "낮은 비용", inline: true, newline: true),
                .init("quadrant-point", "좌표 점", "선택 A: [0.7, 0.3]", focus: "선택 A", inline: true, newline: true)
            ]
        case .markmap:
            return [
                .init("map-multi", "두 단계 가지", "## 하위 주제\n- 세부 항목", focus: "하위 주제", inline: true, newline: true),
                .init("map-check", "체크 항목", "- [ ] 확인할 일", focus: "확인할 일", inline: true, newline: true),
                .init("map-link", "링크 항목", "- [관련 자료](https://example.com)", focus: "관련 자료", inline: true, newline: true),
                .init("map-code", "인라인 코드", "- `코드`", focus: "코드", inline: true, newline: true)
            ]
        case .mermaidXY:
            return [
                .init("xy-title", "차트 제목", "title \"성과 추이\"", focus: "성과 추이", inline: true, newline: true),
                .init("xy-range", "수치 축 범위", "y-axis \"점수\" 0 --> 100", focus: "점수", inline: true, newline: true),
                .init("xy-line", "선 데이터", "line [10, 20, 28, 43]", focus: "10", inline: true, newline: true)
            ]
        case .mermaidPie:
            return [
                .init("pie-slice", "데이터 항목", "\"새 항목\" : 25", focus: "새 항목", inline: true, newline: true),
                .init("pie-title", "제목", "title 업무 분포", focus: "업무 분포", inline: true, newline: true)
            ]
        case .mermaidGantt:
            return [
                .init("gantt-section", "작업 구간", "section 검토", focus: "검토", inline: true, newline: true),
                .init("gantt-task", "후속 작업", "점검 :check1, after task1, 2d", focus: "점검", inline: true, newline: true)
            ]
        case .mermaidTimeline:
            return [
                .init("timeline-item", "시간 사건", "2026 : 주요 결정", focus: "주요 결정", inline: true, newline: true),
                .init("timeline-section", "시간 구간", "section 기획", focus: "기획", inline: true, newline: true)
            ]
        case .mermaidSequence:
            return [
                .init("seq-message", "요청 메시지", "A->>B: 확인 요청", focus: "확인 요청", inline: true, newline: true),
                .init("seq-activate", "활성화", "activate B\nB-->>A: 결과\ndeactivate B", focus: "결과", inline: true, newline: true)
            ]
        case .normal, .code: return []
        }
    }
}
