import Foundation

@main struct PasteSelectionV0933Smoke {
    static func assertRouting(_ value: Bool, _ expected: Bool, _ reason: String) {
        guard value == expected else {
            fputs("FAIL paste decision: \(reason)\n", stderr)
            exit(1)
        }
    }
    static func main() {
        let decide = MemoWeaverPasteSelection.containsActualTable
        assertRouting(decide(nil, nil, nil), false, "empty clipboard")
        assertRouting(decide("", nil, nil), false, "empty advertised TSV")
        assertRouting(decide("image metadata\nline", nil, nil), false, "pseudo TSV is not a table")
        assertRouting(decide("1\t2\n3\t4", nil, nil), true, "real Excel TSV")
        assertRouting(decide(nil, "<TABLE><TR><TD>Single</TD></TR></TABLE>", nil), true, "one-column HTML table")
        assertRouting(decide(nil, nil, "a\tb\nc\td"), true, "plain-text TSV fallback")
        assertRouting(decide(nil, nil, "ordinary multiline\nplain text"), false, "normal paragraphs")
        print("PASS v0.9.33 clipboard image/table routing: 7 cases")
    }
}
