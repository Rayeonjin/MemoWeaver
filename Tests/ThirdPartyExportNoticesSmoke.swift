import Foundation

@main struct ThirdPartyExportNoticesSmoke {
    static func main() throws {
        let html = "<!doctype html><html><body><p>한글 메모</p></BODY></html>"
        let notices = "Copyright © 원저자\nLicense text </script><script>alert('unsafe')</script>\nEPL source: https://example.org/source"
        let output = WorkOSOfficialDiagramRuntime.embedLicenseNotices(in: html, notices: notices)
        precondition(output.contains("<p>한글 메모</p>"), "Export body preserved")
        precondition(!output.contains("<script>alert('unsafe')"), "Notice cannot inject an executable tag")
        let opening = "<script type='application/json' id='memoweaver-third-party-licenses'>"
        let start = output.range(of: opening)!.upperBound
        let end = output.range(of: "</script>", range: start..<output.endIndex)!.lowerBound
        let decoded = try JSONSerialization.jsonObject(with: Data(output[start..<end].utf8)) as! [String: String]
        precondition(decoded["notices"] == notices, "Full copyright/source text roundtrips exactly")
        precondition(WorkOSOfficialDiagramRuntime.embedLicenseNotices(in: html, notices: "") == html)
        print("PASS: standalone HTML retains exact notices/source offers in non-executable JSON")
    }
}
