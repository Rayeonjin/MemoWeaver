import Foundation

// Official engine runtime is an optional, locally bundled JavaScript IIFE.
// It is produced once by prepare-official-renderers.sh. No npm, Node, or
// network access is required to open or edit notes on a user's Mac.
enum WorkOSOfficialDiagramRuntime {
    static let source: String? = {
        guard let url = Bundle.main.url(forResource: "official-diagrams", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8),
              script.contains("MemoryHomeOfficialDiagrams") else { return nil }
        return script
    }()

    static func wrapper(kind: String, source: String, fallback: String) -> String {
        // The original source remains a plain UTF-8 Markdown/JSON string.
        // Escape all five special HTML attribute characters before display.
        let escaped = source.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        let chart = kind == "mermaid" ? chartType(for: source) : nil
        let chartAttribute = chart.map { " data-workos-chart='\($0)'" } ?? ""
        return "<div class='workos-official-diagram' data-workos-diagram='\(kind)'\(chartAttribute) data-workos-source='\(escaped)'><div class='workos-native-diagram'>\(fallback)</div><div class='workos-official-target' aria-live='polite'></div></div>"
    }

    // Initial directive only; never reinterpret or modify the user's Mermaid.
    static func chartType(for source: String) -> String? {
        var inFrontMatter = false
        var sawFrontMatter = false
        for line in source.components(separatedBy: "\n") {
            let trim = line.trimmingCharacters(in: .whitespaces)
            if trim.isEmpty || trim.hasPrefix("%%") { continue }
            if trim == "---" && !sawFrontMatter {
                inFrontMatter = true; sawFrontMatter = true; continue
            }
            if inFrontMatter {
                if trim == "---" { inFrontMatter = false }
                continue
            }
            let first = String(trim.split(whereSeparator: { $0.isWhitespace }).first ?? "")
            if first == "xychart" || first == "xychart-beta" { return "xy" }
            if first == "pie" { return "pie" }
            return nil
        }
        return nil
    }

    // Exported HTML is standalone, with no CDN links or companion folder.
    // Inline the *known local* bundle for exports only. WKWebView preview uses
    // a user script, avoiding megabytes of HTML on every editor keystroke.
    private static let thirdPartyLicenseText: String = {
        guard let resources = Bundle.main.resourceURL else { return "" }
        let file = resources.appendingPathComponent("Licenses/ALL_LICENSES.txt")
        return (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    }()

    // Non-executable JSON preserves the exact copyright and source-offer text.
    // Escape every '<' to avoid both closing-tag and HTML script-comment states.
    static func embedLicenseNotices(in html: String, notices: String) -> String {
        guard !notices.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: ["notices": notices]),
              let range = html.range(of: "</body>", options: [.backwards, .caseInsensitive]) else { return html }
        let json = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003C")
        let block = "<script type='application/json' id='memoweaver-third-party-licenses'>" + json + "</script>"
        var result = html
        result.replaceSubrange(range, with: block + "</body>")
        return result
    }

    static func embedForStandaloneExport(_ html: String) -> String {
        var result = html
        if html.contains("data-workos-diagram="), let script = source,
           let range = result.range(of: "</body>", options: [.backwards, .caseInsensitive]) {
            let safeScript = script.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
            result.replaceSubrange(range, with: "<script>\(safeScript)</script></body>")
        }
        // Only standalone exports call this path; live typing previews do not
        // carry the large inventory or perform additional file reads.
        return embedLicenseNotices(in: result, notices: thirdPartyLicenseText)
    }
}


// Works with BOTH a newly prepared bundle and the user's existing v0.9.6
// official-diagrams.js. The old bridge sets SVG max-width:100%, so the HTML
// preview must correct it after Mermaid inserts its SVG (without modifying or
// repackaging the pinned 5.3MB official library). Markmap is never selected.
extension WorkOSOfficialDiagramRuntime {
    static let mermaidNaturalSizeScript = #"""
    <script>
    (function () {
      'use strict';
      function sizeMermaid() {
        for (const root of document.querySelectorAll('[data-workos-diagram="mermaid"]')) {
          const svg = root.querySelector('.workos-official-target svg');
          if (!svg || svg.getAttribute('data-workos-natural-size') === '1') continue;
          const box = svg.viewBox && svg.viewBox.baseVal;
          const raw = (svg.getAttribute('viewBox') || '').trim().split(/[\s,]+/).map(Number);
          const width = box && box.width > 0 ? box.width :
            (raw.length === 4 && raw[2] > 0 ? raw[2] : NaN);
          if (!Number.isFinite(width) || width <= 0) continue;
          // 1 SVG unit = 1 CSS px: nodes and font size do not grow merely
          // because the right preview pane has become wider.
          // Charts fit the pane without re-rendering during a resize;
          // Mermaid flowcharts retain natural size and horizontal scrolling.
          if (root.hasAttribute('data-workos-chart')) {
            svg.style.setProperty('max-width', '100%', 'important');
            svg.style.setProperty('width', 'min(100%, ' + Math.ceil(width) + 'px)', 'important');
          } else {
            svg.style.setProperty('max-width', 'none', 'important');
            svg.style.setProperty('width', Math.ceil(width) + 'px', 'important');
          }
          svg.style.setProperty('height', 'auto', 'important');
          svg.style.setProperty('margin', '0', 'important');
          svg.setAttribute('data-workos-natural-size', '1');
        }
      }
      function start() {
        if (!document.body) return;
        // Only watch SVG insertion/removal, not style/attribute updates.
        // Thus changing the SVG size cannot recurse through the observer.
        new MutationObserver(sizeMermaid).observe(document.body,
          { childList: true, subtree: true });
        sizeMermaid();
      }
      if (document.readyState === 'loading')
        document.addEventListener('DOMContentLoaded', start, { once: true });
      else start();
    })();
    </script>
    """#
}
