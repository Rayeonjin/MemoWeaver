# Third-party audit tools

Normal release checks are offline: `python3 tools/verify-third-party-licenses.py`
and `./test-third-party-licenses.sh`. After a native build, also run
`python3 tools/verify-third-party-licenses.py --app build/Release/MemoWeaver.app`.

`./tools/license-audit/reproduce.sh` optionally downloads the frozen dependency
graph and parser tooling into temporary folders, creates an investigation-only
bundle, and verifies all retained library statements by scope-aware AST
comparison. It never overwrites the runtime assets. Node/npm are needed only
for this developer audit.

The collection scripts accept an explicit investigation workspace argument,
containing node_modules, metafile.json, registry-cache and package-lock.json:

1. `discover-packages.py`: find contributed modules, upstream prebundle maps,
   original banners/module paths, and conservative declared/type/tool closure.
2. `collect-npm.py`: verify official npm archive integrity, copy original legal
   files, and write package evidence. Handle both package/ and @types tar roots.
3. `collect-elk-notices.py`: collect checksum-verified Maven sources and original
   license/attribution headers from elkjs 0.9.3's declared Java build dependencies.
4. `collect-supplemental.py`: upstream notices, inherited POMs, EPL-1.0, source
   availability evidence and original metadata for packages omitting license files.
5. `finalize-notices.py`: select DOMPurify's Apache option, preserve embedded
   credits, generate the inventory, source offers and consolidated export text.

These collectors make network requests and regenerate legal documents. Review
their output before committing; do not run them as application startup tasks.
Original upstream holders/years are preserved; no missing copyright year is
invented. The inventory explicitly distinguishes directly observed and
conservative entries and records limitations instead of declaring a legal warranty.
