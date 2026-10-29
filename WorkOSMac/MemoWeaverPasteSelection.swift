import Foundation

// Pure, testable input routing for a clipboard with both an image and table-
// related UTIs. An image should not be discarded because a provider advertises
// an empty or single-line pseudo-TSV. Excel's genuine cells remain higher
// priority than the accompanying bitmap preview.
enum MemoWeaverPasteSelection {
    static func containsActualTable(tabular: String?, html: String?, plain: String?) -> Bool {
        if let tabular, WorkOSPasteTable.tabDelimitedText(from: tabular) != nil { return true }
        if let html, html.range(of: "<table", options: .caseInsensitive) != nil,
           html.range(of: "</table", options: .caseInsensitive) != nil { return true }
        let rows = (plain ?? "").components(separatedBy: "\n").filter { !$0.isEmpty }
        return rows.count > 1 && !(rows.first?.hasPrefix("\t") ?? false) &&
            rows.allSatisfy { $0.contains("\t") }
    }
}
