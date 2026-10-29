import Foundation

// Only the algorithm is executed here. WKWebView and AppKit are validated by
// the complete Mac build and manual UI acceptance checks.
@main struct PreviewLiveV0955Smoke {
    static func html(_ body: String, extra: String = "", style: String = "body{color:black}") -> String {
        "<!doctype html><html><head><title>Memo</title><style>\(style)</style></head><body><h1>제목</h1><div class='metadata'>날짜</div><article>\(body)</article>\(extra)</body></html>"
    }
    static func main() {
        let base = html("<p>오늘</p>")
        let edited = html("<p>오늘 바로 반영</p>")
        guard let plain = MemoWeaverLivePreviewDocument(html: base),
              let plainEdit = MemoWeaverLivePreviewDocument(html: edited) else {
            fatalError("Known NoteDocuments HTML should support DOM patch")
        }
        assert(!plain.requiresMath && !plain.requiresDiagrams)
        assert(plain.fragment.contains("<article><p>오늘</p></article>"))
        assert(!plain.fragment.contains("<script>"))
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: plain.styleSignature,
            mathLoaded: false, diagramsLoaded: false, incoming: plainEdit) == .patch)
        let addMath = html("<div class='formula' data-tex='x^2'></div>",
                           extra: "<script>WorkOSKaTeX.renderToString()</script>")
        let math = MemoWeaverLivePreviewDocument(html: addMath)!
        assert(math.requiresMath && !math.requiresDiagrams)
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: plain.styleSignature,
            mathLoaded: false, diagramsLoaded: false, incoming: math) == .reload)
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: math.styleSignature,
            mathLoaded: true, diagramsLoaded: false, incoming: math) == .patch)
        let addMap = html("<div class='workos-official-diagram' data-workos-source='first'></div>")
        let map = MemoWeaverLivePreviewDocument(html: addMap)!
        assert(map.requiresDiagrams)
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: plain.styleSignature,
            mathLoaded: false, diagramsLoaded: false, incoming: map) == .reload)
        let editedMap = MemoWeaverLivePreviewDocument(html: html(
            "<div class='workos-official-diagram' data-workos-source='second'></div>"))!
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: map.styleSignature,
            mathLoaded: false, diagramsLoaded: true, incoming: editedMap) == .patch)
        let changedTheme = MemoWeaverLivePreviewDocument(html: html("<p>hello</p>",style:"body{color:white}"))!
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: plain.styleSignature,
            mathLoaded: true, diagramsLoaded: true, incoming: changedTheme) == .reload)
        assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: plain.styleSignature,
            mathLoaded: true, diagramsLoaded: true, incoming: nil) == .reload)
        // Repeated source changes should be eligible for patching (not 100
        // WKWebView navigations/large official JS initializations).
        for i in 0..<100 {
            let next = MemoWeaverLivePreviewDocument(html: html(
                "<div class='workos-official-diagram' data-workos-source='diagram \(i)'></div>"))!
            assert(MemoWeaverLivePreviewUpdateCore.action(currentStyle: map.styleSignature,
                mathLoaded: false, diagramsLoaded: true, incoming: next) == .patch)
        }
        print("PASS v0.9.55: 100 diagram edits patch DOM; first engine load & theme changes reload once")
    }
}
