# Offline native map force layout

Pinned npm distributions: d3-force 3.0.0, d3-dispatch 3.0.1, d3-quadtree 3.0.1,
d3-timer 3.0.1. All are ISC and match the versions/license files in the existing
THIRD_PARTY_LICENSES inventory. Original UMD JS/package metadata is unmodified.
The original LICENSE files at THIRD_PARTY_LICENSES/packages/<name>/<version>/LICENSE
accompany these distributions and are bundled into the app's Licenses directory.

manifest.json records npm SHA512 integrity and exact JS/package/license hashes.
The runtime is reproducible by joining bootstrap, dispatch/quadtree/timer/force
UMD sources, then bridge.js, with one newline between each part. The offline
license verification script checks both that composition and packaged resources.
No npm install/build step or runtime CDN is required.

JavaScriptCore runs a stopped simulation with 180 manual ticks on a private
serial background queue. Timer callbacks are deliberately inert. Only IDs,
accepted graph edges, positions and presentation pins enter the solver.
The native map owns zoom, pan, drawing, selection and accessibility.

Upstream simulation API: https://d3js.org/d3-force/simulation
