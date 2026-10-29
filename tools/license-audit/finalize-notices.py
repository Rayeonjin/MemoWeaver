#!/usr/bin/env python3
"""Rebuild notices from an explicit reconstruction workspace."""
import sys
from pathlib import Path
import json,hashlib,re,tarfile,xml.etree.ElementTree as ET
r=Path(__file__).resolve().parents[2];out=r/'THIRD_PARTY_LICENSES';w=Path(sys.argv[1])
def file_record(p,upstream=None):
 d={'path':str(p.relative_to(r)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 if upstream:d['upstreamPath']=upstream
 return d
manifest=json.loads((out/'manifest.json').read_text())
for item in manifest['packages']:
 item['selectedLicense']='Apache-2.0' if item['name']=='dompurify' else item['license']
 if item['name'] in ['fastdom','boolbase']:
  folder=out/'packages'/item['name']/item['version']
  with tarfile.open(w/'registry-cache'/f"{item['name']}-{item['version']}.tgz") as archive:
   for name in ['package.json','README.md']:
    content=archive.extractfile('package/'+name).read();p=folder/name;p.write_bytes(content)
    item['licenseFiles'].append(file_record(p,name))
  item.pop('reviewRequired',None)
  item['upstreamPackagingNote']='The published package declares this license but supplies no standalone license file. Exact metadata/author/readme are preserved; no copyright year is invented. Standard permission text is supplied separately.'
  if item['name']=='fastdom':
   item['licenseFiles'].append(file_record(folder/'UPSTREAM-AUTHORS.txt','fastdom.js header'))
   item['licenseFiles'].append(file_record(out/'embedded/MIT-permission-text.txt'))
  else:
   text=(out/'packages/d3/7.9.0/LICENSE').read_text();start=text.index('Permission to use');p=out/'embedded/ISC-permission-text.txt';p.write_text(text[start:]);item['licenseFiles'].append(file_record(p))
 if item['name'].startswith('@esbuild/'):
  item.pop('reviewRequired',None);item['licenseFiles']=[file_record(out/'packages/esbuild/0.25.12/LICENSE.md')]
  item['upstreamPackagingNote']='Optional build-tool binary only, not redistributed in MemoWeaver; license supplied by the matching parent esbuild package.'
for item in manifest['packages']:
 item['licenseFiles']=list({notice['path']:notice for notice in item['licenseFiles']}.values())
# Preserve every embedded legal banner byte-for-byte from the retained asset.
asset=r/'WorkOSMac/Resources/official-diagrams.js';comments=[]
for match in re.finditer(r'/\*[\s\S]*?\*/',asset.read_text()):
 if re.search(r'license|copyright',match.group(),re.I) and len(match.group())<9000:comments.append(match.group())
p=out/'embedded/official-diagrams-original-banners.txt';p.write_text('\n\n'.join(comments)+'\n')
manifest['embeddedComponents']=[
 {'name':'regenerator-runtime helper','version':None,'license':'MIT','provider':'DOMPurify 3.4.17 prebuilt module','evidence':'regenerator-runtime banner preserved in original asset','licenseFiles':[file_record(out/'embedded/regenerator-runtime-LICENSE'),file_record(p)],'note':'The embedded helper does not separately declare its version; supplemental permission text comes from upstream regenerator-runtime 0.14.1, not a claim of the helper version.'},
 {'name':'Thenable/Promise 1.1.1, jQuery-derived events, Bezier and Runge-Kutta helpers','version':None,'license':'MIT','provider':'Cytoscape 3.34.4 prebuilt module','licenseFiles':[file_record(p),file_record(out/'embedded/MIT-permission-text.txt')],'note':'Original Ralf S. Engelschall, Gaetan Renaudeau, Koen Bok and jQuery attribution banners are retained.'}
]
manifest['limitations']=[
 'An original producer lockfile/build receipt is unavailable. The checked-in audit reconstruction passes scope-aware AST alpha equivalence for all 4233 library statements; the final local bridge is excluded and neither deployed JS asset is replaced.',
 'Source-map and declared-closure entries are conservative notice coverage. A package appearing in that closure is not proof that every file/version is emitted; type packages and esbuild are not app runtime payloads.',
 'ELK Java source provenance follows the upstream elkjs 0.9.3 release declaration (ELK 0.9.1 plus PR 955), build.gradle and checksum-verified Maven sources. The original upstream GWT compilation is not independently reproduced.',
 'FastDom and boolbase npm archives omit standalone license files; original SPDX declarations and authors are preserved with standard permission text, without inventing an upstream copyright year.',
 'Inventory, original notice collection and source availability verification are engineering evidence, not a legal warranty or a native GUI acceptance sign-off.'
]
(out/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
maven=json.loads((out/'maven-manifest.json').read_text())
for item in maven['packages']:
 item['selectedLicense']='EPL-1.0' if item['group']=='com.genmymodel.emf.gwt' else ('EPL-2.0'if item['group'].startswith('org.eclipse')else'Apache-2.0')
(out/'maven-manifest.json').write_text(json.dumps(maven,indent=2)+'\n')
# Source offers accompany the EPL components in every app and standalone HTML.
source_text='''# Source availability for third-party components

The following components retain their upstream licenses. They are separate
from MemoWeaver's project-owned Apache-2.0 code. MemoWeaver does not replace
or restrict rights that those upstream licenses grant.

## EPL-2.0: elkjs 0.9.3 / Eclipse Layout Kernel

The component's source is available from these public, versioned upstream
locations in the same customary electronic medium as this distribution:

- elkjs exact release source and build files:
  https://github.com/kieler/elkjs/tree/a8304cf79fde75bc2ab1a89d28320f53f8637436
- Downloadable elkjs source:
  https://github.com/kieler/elkjs/archive/a8304cf79fde75bc2ab1a89d28320f53f8637436.tar.gz
- Upstream release declaration (ELK 0.9.1 with additional PR 955):
  https://github.com/kieler/elkjs/releases/tag/0.9.3
- ELK 0.9.1 base source:
  https://github.com/eclipse-elk/elk/tree/62d5909f96fad541bc101ad52dabaece6b7eab7e
- Additional upstream patch and merge commit:
  https://github.com/eclipse-elk/elk/pull/955
  https://github.com/eclipse-elk/elk/commit/7ca51784e42a24201f29bc13e458728b6fc61cdc

Use the accompanying EPL-2.0 text and ELK NOTICE. MemoWeaver retains the
upstream algorithm payload; bundling/minification and the local app bridge are
identified in the audit report. The original GWT build receipt is not available;
these source references follow the original maintainer's release declaration.

## EPL-1.0 / EPL-2.0 and Apache-2.0: Java-to-JavaScript dependencies

ELK's build.gradle identifies the following source inputs. They are included
conservatively as source/notice coverage; no claim is made that every Java
class survives GWT optimization. The listed source archives were downloaded
and checksum-verified during the audit. Their copyrights and license headers
are preserved under maven/ and supplemental/. Source remains available under
the applicable original license, including the EPL component terms.

'''
for item in maven['packages']:
 source_text+=f"- {item['group']}:{item['artifact']}:{item['version']} ({item['selectedLicense']})\n  {item['sourceURL']}\n  SHA-256: {item['sourceSHA256']}\n"
source_text+='''
## Other upstream JavaScript sources and modifications

manifest.json records official npm source archives, integrity digests and git
revisions for each package/version. These npm packages include the distributable
source, prebuilt code and, where supplied, source maps with sourcesContent.
Mermaid's published source maps also identify upstream patched fastdom/roughjs
inputs. Their retained prebuilt code is not silently replaced by this audit.
The checked-in reconstruction and AST comparison are audit evidence; they are
not presented as the missing original producer's build receipt.
'''
(out/'SOURCE_AVAILABILITY.md').write_text(source_text)
# Human-readable table distinguishes evidence classes rather than claiming all
# conservatively collected dependency packages were emitted into the app.
intro='''# Third-party licenses and copyright notices

Audit date: 2026-10-29. Project-owned MemoWeaver code remains Apache-2.0,
Copyright (c) 2026 Rayeonjin. The third-party components below retain their own
licenses and copyright holders; the project copyright does not apply to them.

## Files and evidence

- `THIRD_PARTY_LICENSES/` preserves original package LICENSE, NOTICE, COPYRIGHT,
  author and applicable Java-source header material without rewriting holders.
- `manifest.json`: npm package/version inventory, source URLs, integrity hashes,
  evidence class, license choice and original notice hashes.
- `maven-manifest.json`: eight conservative ELK Java source/build dependencies.
- `SOURCE_AVAILABILITY.md`: public source access for EPL-1.0 / EPL-2.0 components.
- `ALL_LICENSES.txt`: consolidated original notices carried by standalone HTML.
- `Vendor/official-diagrams/audit-reconstruction/`: frozen reconstruction graph
  and 4,233-statement scope-aware AST comparison. The local final bridge differs;
  the installed assets are preserved byte-for-byte.

DOMPurify's `(MPL-2.0 OR Apache-2.0)` is used under the Apache-2.0 option. Its
original dual-license text is preserved. ELK remains EPL-2.0, and EMF-for-GWT
source remains EPL-1.0; these are not relicensed as MemoWeaver-owned code.

KaTeX's standalone asset declares 0.16.27; Mermaid also includes KaTeX 0.18.10.
No separate KaTeX fonts, Ollama executable, AI model weights, Apple frameworks
or SQLite binaries are redistributed in this source/app bundle. macOS system
frameworks and SQLite are linked at runtime. The official JavaScript bundle
includes the original inline third-party banners reproduced under embedded/.

## Inventory interpretation

`audit-output` identifies a package contributing to the reconstruction output;
`upstream-prebundle-source-map` identifies code inside a published prebundle;
`embedded-*` is direct original-asset evidence. `conservative-dependency-notice`
entries cover the declared tree, including helpers hidden by upstream bundles
and optional plugins that may be tree-shaken. `type-or-build-only` and
`build-tool-only` entries do not imply redistribution of a runtime/tool binary.
Full copyright lines are in the linked original files, not replaced by a single
invented umbrella attribution. FastDom/boolbase's original MIT/ISC metadata is
preserved where npm supplied no standalone license file; no year is fabricated.

## npm packages and original notice files

| Package | Version | License used | Evidence scope | Original notice |
|---|---|---|---|---|
'''
for item in manifest['packages']:
 scope=', '.join(item['scopes']);link=item['licenseFiles'][0]['path'] if item['licenseFiles'] else None
 intro+=f"| {item['name']} | {item['version']} | {item['selectedLicense']} | {scope} | "+(f"[Original]({link})"if link else 'See metadata')+' |\n'
intro+='\n## Embedded contributions\n\n'
for item in manifest['embeddedComponents']:intro+=f"- **{item['name']}** — {item['license']}; {item['provider']}. {item['note']}\n"
intro+='\n## ELK Java source/build dependencies (conservative coverage)\n\n| Component | Version | License | Source and notices |\n|---|---|---|---|\n'
for item in maven['packages']:intro+=f"| {item['group']}:{item['artifact']} | {item['version']} | {item['selectedLicense']} | [Source]({item['sourceURL']}), [headers]({item['licenseFiles'][0]['path']}) |\n"
intro+='\n## Verification scope and limitations\n\n'+''.join('- '+line+'\n'for line in manifest['limitations'])
(r/'THIRD_PARTY_NOTICES.md').write_text(intro)
# Package-level view from inside the license directory.
(out/'README.md').write_text('''# Original third-party legal materials

See ../THIRD_PARTY_NOTICES.md for the inventory. Source access for EPL components
is described in SOURCE_AVAILABILITY.md. manifest.json and maven-manifest.json
record origins, versions, evidence classes and checksums. Supplemental material
is conservative coverage and is not a claim that every dependency is emitted.
''')
# The exported text contains the complete inventory, source offers and every
# original legal/author file. Metadata-only JSON and build scripts are omitted.
legal=set()
for item in manifest['packages']+manifest['embeddedComponents']+maven['packages']:
 for f in item['licenseFiles']:legal.add(f['path'])
supp=json.loads((out/'supplemental-sources.json').read_text())
for f in supp:
 if not f['path'].endswith(('.gradle','.pom','.json')):legal.add(f['path'])
sections=[(name,(r/name).read_text()) for name in ['LICENSE','NOTICE','COPYRIGHT.md']] + [(str((r/'THIRD_PARTY_NOTICES.md').relative_to(r)),intro),('THIRD_PARTY_LICENSES/SOURCE_AVAILABILITY.md',source_text)]
for path in sorted(legal):sections.append((path,(r/path).read_text(encoding='utf-8',errors='strict')))
combined=''.join('\n'+'='*78+'\n'+name+'\n'+'='*78+'\n'+content+'\n'for name,content in sections)
(out/'ALL_LICENSES.txt').write_text(combined)
# Integrity manifest includes every shipped legal document; itself is excluded.
files=[p for p in out.rglob('*')if p.is_file()and p.name!='FILES.sha256']
(out/'FILES.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n'for p in sorted(files)))
print('Finalized',len(manifest['packages']),'npm pairs,',len(maven['packages']),'Java dependencies,',len(legal),'original notice files; consolidated bytes',len(combined.encode()))
