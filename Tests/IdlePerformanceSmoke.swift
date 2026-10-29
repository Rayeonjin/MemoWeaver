import Foundation

@main
struct IdlePerformanceSmoke {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }

    static func main() {
        // A 10,000-line imported VS Code scratchpad with Hangul and emoji.
        let seed = "업무 진행 · 점검 🚀\n"
        var document = String(repeating: seed, count: 10_000)
        var positions = EditorLineNumberRules.lineStarts(in: document)
        require(positions.count == 10_001, "initial 10000-line document")
        // Deterministic edits exercise replacement, insertion, newline and
        // deletion at valid grapheme boundaries, with exact UTF-16 offsets.
        let replacements = ["텍스트", "", "\n", "- 체크", "🚀", "\n\n", "  "]
        for turn in 0..<1_000 {
            let old = document as NSString
            let idx = 10 + (turn * 197) % 8_000
            let lineStart = positions[min(idx, positions.count - 1)]
            let replace = replacements[turn % replacements.count]
            let oldLen = min(2, max(0, old.length - lineStart))
            let new = old.replacingCharacters(in: NSRange(location: lineStart, length: oldLen), with: replace)
            let delta = (replace as NSString).length - oldLen
            let modified = NSRange(location: lineStart, length: (replace as NSString).length)
            positions = EditorLineNumberRules.updatedLineStarts(
                previous: positions, newText: new, editedRange: modified, changeInLength: delta)
            require(positions == EditorLineNumberRules.lineStarts(in: new),
                    "incremental map matches full scan at edit \(turn)")
            document = new
        }
        let typed = "의견 /표"
        let range = SlashCommandCore.trigger(in: typed, caretUTF16: (typed as NSString).length)
        require(range?.query == "표", "Korean slash command")
        require(SlashCommandCore.matches("표").contains(where: { $0.id == "table" }), "slash table")
        require(SlashCommandCore.matches("mermaid").contains(where: { $0.id == "mermaid" }), "slash diagram")
        require(SlashCommandCore.trigger(in: "https://example.com/path", caretUTF16: 24) == nil,
                "slash in URL should not open palette")
        require(SlashCommandCore.trigger(in: "\\/", caretUTF16: 2) == nil,
                "escaped slash should stay literal")
        for item in SlashCommandCore.items {
            require(item.caretBack <= (item.source as NSString).length, "valid caret for \(item.id)")
        }
        let can = MemoryIdlePolicy.mayRun
        require(!can(.automatic, true, 2, 2, 0, false, false), "typing must block AI")
        require(can(.automatic, true, 36, 20, 0, false, false), "editor idle enables AI")
        require(can(.automatic, false, 20, 12, 0, false, false), "other app enables AI")
        require(!can(.automatic, false, 20, 12, 0, true, false), "low-power suspends AI")
        require(!can(.automatic, false, 20, 12, 0, false, true), "thermal limits AI")
        require(!can(.systemIdle, false, 130, 130, 100, false, false), "system idle threshold")
        require(can(.systemIdle, false, 130, 130, 130, false, false), "system idle enabled")
        require(!can(.manual, false, 999, 999, 999, false, false), "manual never auto")
        print("PASS 10000-line / 1000-edit incremental UTF16 line map")
        print("PASS raw Markdown slash catalog + Korean /URL safety")
        print("PASS adaptive AI scheduling, inactive app, low power, thermal and manual")
    }
}
