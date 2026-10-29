# Weekly release completion checklist

## Before edits

- [ ] Home Mac only; `git status`, `git pull --ff-only`, topic branch.
- [ ] Record one scoped problem and acceptance scenario.
- [ ] Preserve protected app identifier, original data path and SQLite IDs.

## After edits

- [ ] Current version/build, changelog, test names and handoff all agree.
- [ ] Latest script `--verify` ran on the home Mac and whole app build succeeded.
- [ ] Native GUI: Korean IME, mouse/keyboard menus, symbols, pane resize,
      focus/caret/undo, 30x open/close, light/dark, screenshots sans private notes.
- [ ] Long edit and paste/image/Excel table tests on Mac; backup restore with
      temporary data; schedules and notification permissions when relevant.
- [ ] All modified or added tests actually executed; FAIL/SKIP disclosed.
- [ ] No change in third-party license copies/JS bundle without full audit.
- [ ] `./tools/public-source-preflight.sh` passed; no secrets/notes/build files.
- [ ] Update `docs/LATEST_HANDOFF_SUMMARY.md` and QA checklist.
- [ ] Commit on weekly branch; merge fast-forward; optional `-qa` tag; push
      only from home Mac. Avoid fake stable/production declarations.
- [ ] Preserve private fallback ZIP and full source state outside public Git.
