# Wiki/navigation stability fixes — 2026-11-08

Baseline: v0.9.65 / Build 98, commit f1b5555. Its unchanged full verification
passed before edits: seven gate groups, isolated AppKit UI and full native build.

## Reproductions and fixes

1. An application-defined completion popover outlived a Settings route change.
   Native editors now receive explicit deactivation; the representable also
   tracks page activity. Deactivation closes both completion kinds and releases
   the editor's own window responder, not the popover's key window. Late wiki
   selection and deferred focus restoration check page activity.
2. A title binding could be shadowed by an imported note whose ID equaled that
   title. Bound targets now take precedence, including a missing-target stop.
3. Wiki reference scanning interpreted dollar-math contents as links even when
   preview did not. The scanner protects inline/display math and code while
   keeping exact source offsets and line pointers. CRLF and emoji are tested.

## Verification

The seven current verification groups passed against the final source:

- Foundation/SQLite core regression, including bound-ID/title collision,
  missing bound target, duplicate titles, explicit IDs and backup roundtrips.
- Inline/display/fenced/unclosed math exclusions, escaped dollars, CRLF and
  emoji with exact UTF-16 reference ranges and physical line numbers.
- Native open completion → Settings → return: popup dismissed, actual window
  responder released, hidden Enter rejected, same editor/source retained and
  completion available again after returning.
- Existing note navigation/undo, pin, background archive import, synthetic IME
  guard, light/dark, two requested window widths and four pane states.
- Offline preview, legal/export notices, ratio policy, notebooks/migration and
  AppKit clipboard tests.

`./install-v0.9.66.sh --verify`: PASS end-to-end on the frozen final source,
including the complete native arm64/macOS 14-target compile/link/ad-hoc sign.
Strict code-signature verification, exact packaged legal-resource comparisons,
source/app version equality (0.9.66 / 99), public-source preflight and its own
regressions, launcher syntax and diff whitespace checks: PASS.
The installed app was not replaced. Full gate log: `build/Logs/release-0.9.66-verify.log`.
Logs are generated under ignored `build/Logs/`; they are not public artifacts.

Tests use temporary SQLite, preferences and recovery directories. Reminder
mutation is disabled in isolated native models. No live notes, user backup,
installed app, renderer asset or third-party legal file is modified by testing.

Real Korean/Japanese input-method acceptance, mouse-driven completion selection,
notification delivery and live Ollama remain manual checks. Synthetic marked
text and native event tests do not certify those behaviors.
