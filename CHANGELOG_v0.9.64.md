# MemoWeaver v0.9.64 / Build 97 - category-first large math symbols

2026-10-28. QA candidate; Mac AppKit/SwiftUI GUI not verified in this environment.

## UX correction

- The previously oversized 455x450 palette required scrolling through all
  99 glyphs and looked unlike other small contextual tools. The same seven
  original math groups now appear in a compact, persistent left-side list.
  Hover or click a category, then choose a readable 25pt glyph on the right.
- The lightweight palette is 444x352pt. Its symbols have plain, borderless
  surfaces (neutral hover only), matching the existing toolbar's visual idiom.
- A category switch resets only that group's symbol scroll. The original
  LaTeX source and readable name remain visible with tooltips.
- The narrow overflow menu opens the palette in the next main-loop iteration
  to avoid simultaneous native Menu dismissal and SwiftUI popover presentation.

## Protected functionality

- All 99 original symbols, exact source/caret insertion and the existing
  Markdown editing, saved note IDs, attachments, database and Undo paths.
- Original 30pt contextual toolbar and slash-command behavior.
- Scheduling, reminders, and v0.9.63 JSON safe restore are unchanged.
- No SQLite migration, no new dependency, no bundle-id/path change.

## Verification limits

- Syntax parser, Foundation symbol-set / insertion smoke, source contracts,
  protected core hashes and non-schedule regressions are runnable on Linux.
- Full SwiftUI typecheck and visual behavior (hover, mouse click, dark mode,
  narrow popover and restoration of editor focus) require Mac acceptance.
- External-library notices and root source license are NOT fully resolved.
