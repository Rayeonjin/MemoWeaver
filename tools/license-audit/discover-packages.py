#!/usr/bin/env python3
"""Rebuild audit evidence from an explicit temporary reconstruction workspace."""
import sys
from pathlib import Path
import re,json,collections
w=Path(sys.argv[1]).resolve();r=Path(__file__).resolve().parents[2]
m=json.loads((w/'metafile.json').read_text());inputs=next(iter(m['outputs'].values()))['inputs']
items={}
def add(name,version,scope,evidence):
 key=name+'@'+version
 e=items.setdefault(key,dict(name=name,version=version,scopes=[],evidence=[]))
 if scope not in e['scopes']:e['scopes'].append(scope)
 if evidence not in e['evidence']:e['evidence'].append(evidence)
for filename,info in inputs.items():
 if info['bytesInOutput']<=0:continue
 p=(r/filename).resolve()
 if 'node_modules' not in p.parts:continue
 for parent in p.parents:
  f=parent/'package.json'
  if f.exists():
   d=json.loads(f.read_text())
   if d.get('name'):
    add(d['name'],d['version'],'audit-output',str(p.relative_to(w)))
    break
 mp=Path(str(p)+'.map')
 if mp.exists():
  d=json.loads(mp.read_text())
  for x in d.get('sources',[]):
   for store in re.findall(r'node_modules/\.pnpm/([^/]+)/node_modules/',x):
    v=re.match(r'(.+?)@([0-9][^_]*)(?:_.*)?$',store)
    if v:add(v[1].replace('+','/'),v[2],'upstream-prebundle-source-map',str(mp.relative_to(w))+' :: '+x)
add('katex','0.16.27','standalone-asset','WorkOSMac/Resources/katex-mathml.js embedded version')
add('@gera2ld/jsx-dom','2.2.2','embedded-banner','WorkOSMac/Resources/official-diagrams.js preserved legal banner')
for package,version in re.findall(r'node_modules/\.pnpm/([^/@]+)@([^/]+)/node_modules/',(r/'WorkOSMac/Resources/official-diagrams.js').read_text()):
 add(package,version,'embedded-module-path','WorkOSMac/Resources/official-diagrams.js preserved module path')
# Development tools are not represented as shipped runtime code.
add('esbuild','0.25.12','build-tool-only','Vendor/official-diagrams/package.json')
# Include the installed declared dependency closure conservatively: upstream
# prebundles can hide helpers even when esbuild exposes only their parent file.
for f in (w/'node_modules').rglob('package.json'):
    rel=str(f.parent.relative_to(w))
    if not re.fullmatch(r'(?:node_modules/(?:@[^/]+/)?[^/]+/)*node_modules/(?:@[^/]+/)?[^/]+',rel): continue
    d=json.loads(f.read_text())
    scope='type-or-build-only' if d['name'].startswith(('@types/','@esbuild/')) else 'conservative-dependency-notice'
    key=d['name']+'@'+d['version']
    if key not in items: add(d['name'],d['version'],scope,rel+'/package.json; declared closure, not proof this version was emitted')
(w/'discovered-packages.json').write_text(json.dumps(sorted(items.values(),key=lambda d:(d['name'],d['version'])),indent=2))
print('Discovered package/version pairs:',len(items))
print('\n'.join(items))
