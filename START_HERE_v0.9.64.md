# MemoWeaver v0.9.64 / Build 97 - start here

This is the complete v0.9.63 source with a narrow math-symbol UI consistency
change and no changes to planner, persistence, or AI.

## Safely test on macOS

1. Quit MemoWeaver. Run `./backup-before-real-use.sh` to preserve your data.
2. `./install-v0.9.64.sh --verify` runs regression checks and builds the app
   without touching the installed app.
3. Verify `MAC_ACCEPTANCE_v0.9.64.md` first, especially symbols and note
   editing. Follow `MAC_ACCEPTANCE_v0.9.63.md` for planner/notifications.
4. Only after passing tests: `./install-v0.9.64.sh` if you choose to install.

Linux supports source parsing and Foundation/SQLite tests but cannot validate
native SwiftUI/AppKit build, hover/click, keyboard/IME or notification delivery.
This is a QA candidate, not a cleared public binary. Root LICENSE and complete
transitive JavaScript notices still require owner review.
