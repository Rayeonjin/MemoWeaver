import Foundation
// This CLI fixture runs without the SQLite source file that owns the shared
// HTML escape helper in the full app. It does not affect shipped app code.
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
