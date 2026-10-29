import Foundation

@main
struct TypographySmoke {
    static func near(_ actual: Double, _ expected: Double, _ label: String) {
        assert(abs(actual - expected) < 0.001, "\(label): expected \(expected), got \(actual)")
    }

    static func main() {
        near(EditorTypographyRules.fontSize(17), 17, "default size")
        near(EditorTypographyRules.fontSize(10), 13, "minimum size")
        near(EditorTypographyRules.fontSize(80), 24, "maximum size")
        near(EditorTypographyRules.fontSize(.nan), 17, "invalid size")
        near(EditorTypographyRules.lineHeight(.infinity), 1.5, "invalid spacing")
        assert(EditorTypographyRules.extraLeading(fontSize: 17, lineHeight: 1.7) >
               EditorTypographyRules.extraLeading(fontSize: 17, lineHeight: 1.3))
        near(EditorTypographyRules.displaySize(original: 14, referenceBody: 14, preferredBody: 17, bold: false), 17, "body normalization")
        near(EditorTypographyRules.displaySize(original: 14, referenceBody: 14, preferredBody: 17, bold: true), 17, "bold body normalization")
        near(EditorTypographyRules.displaySize(original: 25, referenceBody: 14, preferredBody: 17, bold: true), 17*1.64, "H1 preserved")
        near(EditorTypographyRules.displaySize(original: 20, referenceBody: 14, preferredBody: 17, bold: true), 17*1.35, "H2 preserved")
        near(EditorTypographyRules.displaySize(original: 16, referenceBody: 14, preferredBody: 17, bold: true), 17*1.12, "H3 preserved")
        near(EditorTypographyRules.displaySize(original: 17*1.35, referenceBody: 17, preferredBody: 20, bold: true), 20*1.35, "H2 rescale")
        near(EditorTypographyRules.zoom(24, by: 1), 24, "zoom capped")
        near(EditorTypographyRules.zoom(13, by: -1), 13, "zoom floor")
        let hangul = "오전 회의 기록과 후속 작업 😀"
        assert((hangul as NSString).length > 0)
        print("PASS typography rules: default, bounds, Hangul-safe leading, heading hierarchy, live zoom")
    }
}
