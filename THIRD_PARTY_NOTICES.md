# Third-party notices

## KaTeX (JavaScript, MathML-only runtime)

Version: 0.16.27 (bundled script reports this version)

Copyright (c) 2013-2020 Khan Academy and other contributors.

Licensed under the MIT License:

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

The vendored asset is adapted from a locally present ES module build into an
offline, self-contained script exposed as `window.WorkOSKaTeX`. MathML output
was selected to avoid bundling fonts or CSS font assets.


## Included official diagram runtime (bundled locally)

- Mermaid 12.2.0 - Copyright Mermaid project contributors - MIT License - https://github.com/mermaid-js/mermaid
- Markmap packages (markmap-lib, markmap-view) 0.18.12 - Copyright Markmap contributors - MIT License - https://github.com/markmap/markmap
- The local bundled runtime also contains transitive dependencies. Preserve the bundle's `/*! ... */` legal comments and verify all package licenses before external redistribution.
- The 2026-10-23 BUNDLED source ZIP includes `WorkOSMac/Resources/official-diagrams.js` directly, so Node.js/npm/network access is not required for installation. Before external redistribution, verify transitive dependency license obligations.
