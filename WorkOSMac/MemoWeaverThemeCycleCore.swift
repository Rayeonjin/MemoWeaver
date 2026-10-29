import Foundation

// App and preview themes have independent storage keys, but identical
// one-click behavior. Invalid legacy values recover to system mode.
enum MemoWeaverThemeCycleCore {
    static let modes = ["system", "light", "dark"]
    static func next(after current: String) -> String {
        guard let index = modes.firstIndex(of: current) else { return "system" }
        return modes[(index + 1) % modes.count]
    }
}
