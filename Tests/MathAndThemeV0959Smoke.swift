import Foundation

@main
struct MathAndThemeV0959Smoke {
    static func main() {
        func check(_ condition: @autoclosure () -> Bool, _ description: String) {
            if !condition() { fatalError(description) }
        }
        let multi = MarkdownAssistSnippet.gatheredEquations
        let aligned = MarkdownAssistSnippet.alignedEquations
        for (snippet, environment) in [(multi, "gathered"), (aligned, "aligned")] {
            let source = snippet.source
            check(source.hasPrefix("\\begin{\(environment)}\n"), "opening environment: \(environment)")
            check(source.hasSuffix("\n\\end{\(environment)}"), "closing environment: \(environment)")
            check(source.contains(" \\\\\n"), "LaTeX line-break is two backslashes followed by actual newline")
            check(!source.contains("\\\\n"), "do not accidentally include literal n")
            check(snippet.group == .mathLayout, "palette math-layout category")
            check(snippet.caretBack > 0, "caret returns to first editable expression")
            let firstExpression = environment == "gathered" ? "a+b=c" : "a &= b"
            let sourceUTF16 = source as NSString
            let focus = sourceUTF16.length - snippet.caretBack
            check(sourceUTF16.substring(from: focus).hasPrefix(firstExpression), "caret at first expression")
        }
        check(MemoWeaverThemeCycleCore.next(after: "system") == "light", "theme system -> light")
        check(MemoWeaverThemeCycleCore.next(after: "light") == "dark", "theme light -> dark")
        check(MemoWeaverThemeCycleCore.next(after: "dark") == "system", "theme dark -> system")
        check(MemoWeaverThemeCycleCore.next(after: "unknown") == "system", "invalid old state")
        print("PASS: multi-line math templates, caret focus, independent theme cycle core")
    }
}
