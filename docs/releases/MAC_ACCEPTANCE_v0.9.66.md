# v0.9.66 native acceptance

Use only disposable data. Never validate restore against the user's live store.

Automated tests include light/dark, two widths, all four pane visibility states,
editor identity/undo, completion/Enter, pin, background import and a synthetic
marked-text guard. Evidence and exact execution status are recorded in
`../WIKI_STABILITY_2026-11-08.md`.

Additional automated regression covers open completion → Settings → return,
hidden Enter rejection, bound-ID/title collision and math exclusions.

Manual acceptance still required:

- [ ] Real Korean IME: composition, candidate selection, arrow keys, undo and
      navigation during composition; Japanese IME if used.
- [ ] Notes/Settings: cold and repeated transitions with small and long notes;
      compare perceived responsiveness, focus, selection and undo.
- [ ] Pin/unpin in toolbar and note list; failed-save behavior on a full disk.
- [ ] First launch: editable welcome, delete/relaunch, existing store unchanged.
- [ ] Resize in light/dark, all four pane-visibility states, narrow/wide window;
      ratio label during dragging and correct final value, no stolen widths.
- [ ] Wiki completion with keyboard AND mouse, Esc/outside click, inline/fenced
      examples, duplicate titles, rename, trash/restore and incoming source jump.
- [ ] Image paste/drop, long-line TXT import while editing another note, archive
      search, JSON with image/history/wiki bindings, restore and restart.
- [ ] Offline preview, PDF/HTML export, reminder permission/delivery and optional
      live Ollama behavior.

A synthetic marked-text check is not a human IME acceptance test. QR/mobile
is outside this release. No user app installation is performed by --verify.
