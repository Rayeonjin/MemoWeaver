# Manual acceptance — unreleased stability update (2026-10-29)

Use test-only notes in an isolated macOS account. Do not restore or run test
fixtures against the owner's real WorkOS database. Never treat automated
AppKit smoke tests as proof of human IME or GUI acceptance.

NOT RUN during the coding session:

- [ ] Real Korean IME composition, selection and undo, including line changes,
      fence edits and switching notes during composition.
- [ ] Light/dark, four pane visibility states, rapid toggles and window resize.
- [ ] Slash command mouse/keyboard and 99-symbol picker insertion at the caret.
- [ ] Long-note typing/scrolling with preview, image paste/drop and restart.
- [ ] Recovery banner after metadata-only save failure / abnormal termination.
- [ ] Stop an Ollama answer, immediately ask again and confirm busy/error state.
- [ ] Backup dialog responsiveness and actual restore in an isolated user account.
- [ ] System notification permission, delivery and reminder click-through.

No app installation or replacement was requested or performed. The compiled
app remains under build/Release and should undergo this acceptance before use
with real notes. The pending third-party bundle license audit is unchanged.
