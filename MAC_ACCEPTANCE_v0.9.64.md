# MemoWeaver v0.9.64 - macOS owner acceptance (manual; not yet passed)

Do not run restore tests on daily data. Quit app before backing up.
Run `./backup-before-real-use.sh`, then `./install-v0.9.64.sh --verify`
without replacing the installed app.

## P0: Math symbol consistency

1. Inside `$$...$$`, select the math-symbol tool. Expect the same seven
   categories as before (Greek lowercase/uppercase, relation, sets, logic,
   calculus, arrows), now arranged as a compact vertical group menu at left.
2. Move the pointer over a category without clicking. Only that category's
   glyphs should update at right; click is also supported.
3. Check Greek/sigma/integrals/arrows at 25pt in both light and dark mode.
   Hover feedback must be subtle and full LaTeX source accessible on hover.
4. Select any glyph once. It must insert the exact LaTeX source at the caret,
   leave the editor focused, be undoable, autosave, and update preview.
5. Select a different category after scrolling the Greek group; its glyph
   grid should begin at the top, not inherit the previous scroll offset.
6. Narrow the editor until the toolbar collapses to the all-tools menu;
   'large symbols' must open the same palette with ONE click. Escape or
   clicking outside should close it without changing note content.
7. Try a display with a narrow available screen edge and larger system text;
   popover must not obscure all controls or clip category/symbol labels.

## P0: Daily-note use without planner

- Korean IME composition, cursor/selection, undo/redo, paste from Excel,
  PNG clipboard/Finder drop, long note scrolling and syntax highlighting.
- Search (`Cmd+K` and full-text), multiple notebooks, delete/recover, backup
  and safe JSON export/recovery (use an isolated test account).
- Pane show/hide, width preservation, tooltip single-click behavior,
  Markdown/Mermaid/Markmap/KaTeX offline preview and optional Ollama disabled.
- Restart after a new/edited note and verify exact text and attachments.

Only user-observed real Mac outcomes can mark these as passed. v0.9.63
planner tests remain in `MAC_ACCEPTANCE_v0.9.63.md` if that feature is needed.
