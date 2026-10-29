import Foundation

@main
struct EditorUXV0930Smoke {
    static func main() {
        let minimum = EditorTypographyRules.minimumSize
        let maximum = EditorTypographyRules.maximumSize
        precondition(minimum == 13.0 && maximum == 24.0)
        precondition(EditorTypographyRules.zoom(minimum, by: -1) == minimum)
        precondition(EditorTypographyRules.zoom(maximum, by: 1) == maximum)
        precondition(EditorTypographyRules.zoom(minimum, by: 1) == minimum + 1)
        precondition(EditorTypographyRules.zoom(maximum, by: -1) == maximum - 1)
        precondition(EditorTypographyRules.fontSize(.nan) == EditorTypographyRules.defaultSize)
        print("PASS v0.9.30: typography bounds and restoration behavior")
    }
}
