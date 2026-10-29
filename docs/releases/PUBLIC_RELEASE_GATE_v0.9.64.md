# MemoWeaver public GitHub / donation release gate (v0.9.64)

Current answer: the code is a credible *source preview* candidate, but this ZIP
is NOT a license-cleared, tested or notarized public `.app` distribution.

## Confirmed progress

- Real Swift/SQLite schedule tests cover storage, links, dates, backup and
  safe destructive restore; current backup identifiers now work in the UI.
- An existing third-party notice document is included inside compiled apps,
  not just the source ZIP.
- No downloaded npm dependency, JS bundle or app data has been changed in the
  scope of the planner fixes.
- The native UI must still pass the macOS acceptance plan.

## Open P0 gates

1. The project owner must choose and supply the app's own root LICENSE, with
   real copyright-holder details. No app license is inferred here.
2. Audit the full effective bundled Mermaid/Markmap/KaTeX transitive dependency
   tree, provide actual license/NOTICE text for every shipped package, and
   track a reproducible npm lockfile plus esbuild metafile/SBOM. The current
   `THIRD_PARTY_NOTICES.md` remains **INCOMPLETE**; adding it to the app is
   useful but not sufficient for legal compliance.
3. Mac native compile plus the new notification permission/delivery/click,
   edit/complete/cancellation, restore, Korean IME, slash pointer and symbols
   visual QA must pass.
4. Public downloadable `.app`: decide Developer ID signing and notarization
   (or clearly document a self-build-only developer preview), and publish
   truthful support/privacy/backup/security documentation.
5. Publish sanitized project files, README and screenshots; audit for personal
   memo data, local paths and secrets. A GitHub Sponsors link can be attached
   only after the owner has a genuine approved account.

Source license selection and sponsorship participation are owner choices.
No new external dependency permissions are claimed by these patches.

See `docs/releases/PUBLIC_LICENSE_AUDIT_v0.9.62.md` for the observed incomplete notices and
reproducibility problems, and `docs/releases/MAC_ACCEPTANCE_v0.9.64.md` for runtime tests.

The v0.9.64 math UI refinements do not change these gates.
