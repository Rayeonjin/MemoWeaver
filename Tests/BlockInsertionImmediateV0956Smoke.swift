import Foundation

@main
struct BlockInsertionImmediateV0956Smoke {
    static func check(_ source: String, caretBack: Int,
                      expected: MarkdownEditingContext, name: String) {
        let prefix = "오늘의 업무\n\n"
        let combined = prefix + source + "\n마지막 일반 문장"
        let caret = (prefix as NSString).length + (source as NSString).length - caretBack
        precondition(caret >= 0 && caret <= (combined as NSString).length, name + " caret range")
        let actual = MarkdownContextCore.context(in: combined, utf16Offset: caret)
        precondition(actual == expected,
                     "\(name) inserted caret context: expected \(expected) but got \(actual)")
        let after = MarkdownContextCore.context(in: combined,
            utf16Offset: (combined as NSString).length)
        precondition(after == .normal, name + " must leave block after insertion")
    }

    static func main() {
        let builtins: [(MarkdownTemplates.Kind, MarkdownEditingContext)] = [
            (.equation, .math), (.mermaid, .mermaid),
            (.markmap, .markmap), (.chart, .mermaidXY),
            (.diagram, .mermaidGantt)
        ]
        for (kind, expected) in builtins {
            let request = MarkdownTemplates.insertion(for: kind)
            check(request.source, caretBack: request.caretBack,
                  expected: expected, name: "toolbar \(kind.rawValue)")
        }
        for (key, expected) in [("math", MarkdownEditingContext.math),
                                 ("mermaid", .mermaid), ("markmap", .markmap)] {
            guard let found = SlashCommandCore.matches(key).first(where: { $0.id == key }) else {
                fatalError("slash template not found \(key)")
            }
            check(found.source, caretBack: found.caretBack,
                  expected: expected, name: "slash \(key)")
        }
        print("PASS v0.9.56: toolbar/Slash 8 block insertion caret contexts before any extra click")
    }
}
