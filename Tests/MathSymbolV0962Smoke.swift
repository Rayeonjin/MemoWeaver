import Foundation

@main
struct MathSymbolV0962Smoke {
    static func main() {
        let sections = MemoWeaverMathSymbolCatalog.sections
        let symbols = MemoWeaverMathSymbolCatalog.allSymbols
        let expected = MarkdownAssistSnippet.allCases.filter { $0.group == .mathSymbols }
        precondition(sections.count == 7)
        precondition(!sections.contains(where: { $0.title.isEmpty || $0.symbols.isEmpty }))
        precondition(Set(symbols).count == symbols.count, "symbol catalog has duplicate entries")
        precondition(Set(symbols) == Set(expected), "all existing math symbols must be preserved")
        for snippet in symbols {
            precondition(!snippet.title.isEmpty && !snippet.source.isEmpty)
            precondition(snippet.group == .mathSymbols)
            let prepared = MarkdownAssistInsertionCore.prepare(
                source: snippet.source, caretBack: snippet.caretBack,
                selectedText: "", wrapsSelection: snippet.wrapsSelection)
            precondition(prepared.source == snippet.source)
            precondition(prepared.caretBack == snippet.caretBack)
        }
        print("PASS v0.9.62: \(symbols.count) unique math symbols in 7 readable sections; source/caret preserved")
    }
}
