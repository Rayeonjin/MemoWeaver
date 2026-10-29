import Foundation

/// Logical (hard-break) line positions measured in UTF-16, like NSTextView's
/// selection ranges. Visual rows created by word-wrap share one line number.
/// This core has no AppKit dependency so it can be regression-tested on Linux.
enum EditorLineNumberRules {
    static func lineStarts(in text: String) -> [Int] {
        let units = Array(text.utf16)
        var starts = [0]
        starts.reserveCapacity(max(1, min(units.count / 60, 16_384)))
        var index = 0
        while index < units.count {
            switch units[index] {
            case 0x000D: // CR and CRLF both count as one hard break.
                if index + 1 < units.count && units[index + 1] == 0x000A {
                    index += 1
                }
                starts.append(index + 1)
            case 0x000A, 0x2028, 0x2029:
                starts.append(index + 1)
            default:
                break
            }
            index += 1
        }
        return starts
    }

    /// Incrementally updates logical line numbers for a character edit.
    /// `editedRange` is NSTextStorage.editedRange in the NEW string and
    /// `changeInLength` is NSTextStorage.changeInLength (UTF-16 delta).
    /// Recomputes at most the neighboring edited lines, not a 10,000-line note.
    static func updatedLineStarts(previous: [Int], newText: String,
                                  editedRange: NSRange, changeInLength delta: Int) -> [Int] {
        let ns = newText as NSString
        let oldLength = ns.length - delta
        let oldEditLength = editedRange.length - delta
        guard !previous.isEmpty, previous[0] == 0, oldLength >= 0,
              oldEditLength >= 0, editedRange.location >= 0,
              editedRange.location + oldEditLength <= oldLength,
              NSMaxRange(editedRange) <= ns.length,
              (previous.last ?? 0) <= oldLength else {
            return lineStarts(in: newText)
        }
        let editedStart = editedRange.location
        // CR and CRLF can merge/split across NSTextStorage edit boundaries.
        // Use the proven full scan for those unusual boundary edits rather
        // than risk an incorrect line pointer in an old pasted document.
        let aroundStart = max(0, editedStart - 3)
        let aroundEnd = min(ns.length, NSMaxRange(editedRange) + 3)
        if ns.substring(with: NSRange(location: aroundStart, length: aroundEnd - aroundStart)).contains("\r") {
            return lineStarts(in: newText)
        }
        // Include the previous line to handle CRLF edits across a boundary.
        let startIndex = max(0, lineIndex(forUTF16Offset: editedStart, starts: previous) - 1)
        let start = previous[startIndex]
        let oldEditEnd = editedStart + oldEditLength
        var suffixIndex = startIndex
        while suffixIndex < previous.count && previous[suffixIndex] <= oldEditEnd {
            suffixIndex += 1
        }
        // Recompute the next line as well: an edited CR/LF may change
        // whether the immediately following boundary is a single CRLF.
        suffixIndex = min(previous.count, suffixIndex + 1)
        let oldWindowEnd = suffixIndex < previous.count ? previous[suffixIndex] : oldLength
        let newWindowEnd = oldWindowEnd + delta
        guard start <= newWindowEnd, newWindowEnd <= ns.length else { return lineStarts(in: newText) }
        let window = ns.substring(with: NSRange(location: start, length: newWindowEnd - start))
        let updatedWindow = lineStarts(in: window).map { $0 + start }
        var merged = Array(previous.prefix(startIndex))
        for position in updatedWindow {
            if position == newWindowEnd && suffixIndex < previous.count { continue }
            if merged.last != position { merged.append(position) }
        }
        for originalPosition in previous.dropFirst(suffixIndex) {
            let shifted = originalPosition + delta
            if merged.last != shifted { merged.append(shifted) }
        }
        return merged
    }

    /// Zero-based logical line containing a UTF-16 character/caret offset.
    static func lineIndex(forUTF16Offset offset: Int, starts: [Int]) -> Int {
        guard !starts.isEmpty else { return 0 }
        var low = 0
        var high = starts.count
        while low < high {
            let middle = low + (high - low) / 2
            if starts[middle] <= offset { low = middle + 1 }
            else { high = middle }
        }
        return max(0, low - 1)
    }

    static func isFirstVisualRow(atUTF16Offset offset: Int, starts: [Int]) -> Bool {
        guard !starts.isEmpty else { return offset == 0 }
        return starts[lineIndex(forUTF16Offset: offset, starts: starts)] == offset
    }
}
