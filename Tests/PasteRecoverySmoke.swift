import Foundation

@main
struct PasteRecoverySmoke {
    static func main() {
        let plain = "🏆 Top Trading Competition 🏆\n🎯 Quiz Event — raise awareness 🧩\n💎 HODLer Event 日本語 한글"
        let broken = "� Top Trading Competition �\n�� Quiz Event — raise awareness �\n�� HODLer Event 日本語 한글"
        assert(WorkOSPasteRecovery.replacementCount(in: broken) == 7)
        assert(WorkOSPasteRecovery.replacementText(rich: broken, unicodePlain: plain) == plain)
        assert(WorkOSPasteRecovery.replacementText(rich: plain, unicodePlain: broken) == nil)
        assert(WorkOSPasteRecovery.replacementText(rich: broken, unicodePlain: broken) == nil)
        assert(WorkOSPasteRecovery.replacementText(rich: broken + "\u{FFFC}", unicodePlain: plain) == nil)
        assert(WorkOSPasteRecovery.replacementText(rich: broken, unicodePlain: nil) == nil)
        assert(WorkOSPasteRecovery.replacementText(rich: "A\tB\nC\tD", unicodePlain: "A\tB\nC\tD") == nil)
        let best = WorkOSPasteRecovery.bestPlainText([broken, plain, "� Quiz Event"])
        assert(best == plain)
        assert(WorkOSPasteRecovery.bestPlainText(["", ""]) == nil)
        assert(WorkOSPasteRecovery.bestPlainText(["안전😀", "safe"]) == "안전😀")
        assert(WorkOSPasteRecovery.replacementCount(in: "𠜎🇰🇷한글이모지😀") == 0)
        print("PASS: Unicode paste repair chooses intact clipboard text; never invents symbols or discards attachments")
    }
}
