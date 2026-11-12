# v0.9.67 native acceptance

Use only disposable data. Never validate restore against the user's live store.

Automated tests include light/dark, two widths, all four pane visibility states,
editor identity/undo, completion/Enter, pin, background import and a synthetic
marked-text guard. Evidence and exact execution status are recorded in
`../UPDATE_CHECK_2026-11-12.md`.

Additional automated regression covers open completion → Settings → return,
hidden Enter rejection, bound-ID/title collision and math exclusions.

- [x] Installed v0.9.67 / Build 100: manual update button and actual GitHub
      rate-limit error/fallback link displayed; existing note hashes unchanged.
- [x] Mocked service/controller: newer/current/ahead, API errors, no construction
      request, duplicate suppression and cancellation generation checks passed.

- [ ] App information: no request on launch; manual button shows current/newer/
      ahead and error states; source/release links point to this repository.
- [ ] Leave/reopen Settings during a slow request; no stale response or busy UI.

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
