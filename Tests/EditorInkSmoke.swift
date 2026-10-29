import AppKit

@main
struct EditorInkSmoke {
    static func main() {
        let sample = NSMutableAttributedString(string: "검정/빨강/화이트/배경/그대로")
        let source = sample.string as NSString
        func span(_ text: String) -> NSRange { source.range(of: text) }
        let inkColor = NSColor(calibratedRed: 0.93, green: 0.13, blue: 0.21, alpha: 1)
        sample.addAttribute(.foregroundColor, value: NSColor.black, range: span("검정"))
        sample.addAttribute(.foregroundColor, value: inkColor, range: span("빨강"))
        sample.addAttribute(.foregroundColor, value: NSColor.white, range: span("화이트"))
        sample.addAttributes([.foregroundColor: NSColor.black,
                              .backgroundColor: NSColor.white], range: span("배경"))
        sample.addAttribute(.foregroundColor, value: NSColor.black, range: span("그대로"))
        let editable = NSRange(location: 0, length: span("배경").location + span("배경").length)
        assert(EditorInk.adapt(sample, range: editable))
        assert(sample.attribute(.foregroundColor, at: span("검정").location,
                                effectiveRange: nil) as? NSColor == NSColor.labelColor)
        assert(sample.attribute(.foregroundColor, at: span("화이트").location,
                                effectiveRange: nil) as? NSColor == NSColor.labelColor)
        assert(sample.attribute(.foregroundColor, at: span("빨강").location,
                                effectiveRange: nil) as? NSColor == inkColor)
        assert(sample.attribute(.foregroundColor, at: span("배경").location,
                                effectiveRange: nil) as? NSColor == NSColor.black,
               "A readable black-on-white cell retains its original ink")
        assert(sample.attribute(.foregroundColor, at: span("그대로").location,
                                effectiveRange: nil) as? NSColor == NSColor.black,
               "Only the pasted range can be rewritten")
        assert(EditorInk.customColor(hex: "#12AB34") != nil)
        assert(EditorInk.customColor(hex: "#GGGGGG") == nil)
        assert(WorkOSInkPreset.allCases.count == 7)
        print("PASS: dark-mode adaptive neutral ink, colored spans, contrasted cells, exact range, custom colors")
    }
}
