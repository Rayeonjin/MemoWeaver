import Foundation

// Foundation-only regression for the native slash palette's context caption.
// All enum cases are deliberately enumerated. Adding an enum case without
// updating MarkdownEditingContext.slashPaletteTitle fails this compile step.
@main struct MarkdownSlashPaletteV0944Smoke {
    static func main() {
        let expected: [(MarkdownEditingContext, String)] = [
            (.normal, "메모 삽입"),
            (.math, "수식 코드"),
            (.mermaid, "Mermaid 흐름도"),
            (.mermaidXY, "Mermaid XY 차트"),
            (.mermaidPie, "Mermaid 원형 차트"),
            (.mermaidGantt, "Mermaid Gantt 일정"),
            (.mermaidTimeline, "Mermaid Timeline 이력"),
            (.mermaidSequence, "Mermaid Sequence 순서도"),
            (.markmap, "Markmap 마인드맵"),
            (.code, "코드"),
        ]
        for (context, title) in expected {
            precondition(context.slashPaletteTitle == title,
                         "Unexpected slash palette title for \(context): \(context.slashPaletteTitle)")
        }
        precondition(expected.count == 10)
        print("PASS v0.9.44: all 10 Markdown editing contexts have a slash palette title")
    }
}
