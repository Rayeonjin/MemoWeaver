#!/usr/bin/env python3
"""Rebuild audit evidence from an explicit temporary reconstruction workspace."""
import sys
from pathlib import Path,PurePosixPath
import urllib.request,urllib.parse,json,tarfile,io,hashlib,base64,re,concurrent.futures,time
r=Path(__file__).resolve().parents[2];w=Path(sys.argv[1]);out=r/'THIRD_PARTY_LICENSES';out.mkdir(exist_ok=True)
items=json.loads((w/'discovered-packages.json').read_text())
cache=w/'registry-cache';cache.mkdir(exist_ok=True)
def get(url):
 for attempt in range(3):
  try:
   with urllib.request.urlopen(url,timeout=60) as f:return f.read()
  except Exception:
   if attempt==2:raise
   time.sleep(1+attempt)
def work(item):
 name,version=item['name'],item['version'];slug=name.replace('@','').replace('/','__');folder=out/'packages'/slug/version;folder.mkdir(parents=True,exist_ok=True)
 url='https://registry.npmjs.org/'+urllib.parse.quote(name,safe='@')+'/'+version
 mp=cache/(slug+'-'+version+'.json')
 if not mp.exists():mp.write_bytes(get(url))
 meta=json.loads(mp.read_text());dist=meta['dist'];tp=cache/(slug+'-'+version+'.tgz')
 if not tp.exists():tp.write_bytes(get(dist['tarball']))
 data=tp.read_bytes();integrity=dist.get('integrity','')
 if integrity:
  matches=False
  for spec in integrity.split():
   algorithm,encoded=spec.split('-',1)
   if algorithm in hashlib.algorithms_available and base64.b64encode(hashlib.new(algorithm,data).digest()).decode()==encoded:matches=True
  assert matches,'integrity mismatch '+name
 else:assert hashlib.sha1(data).hexdigest()==dist['shasum']
 files=[]
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
  for member in archive.getmembers():
   if not member.isfile():continue
   path=PurePosixPath(member.name)
   if not path.parts or path.is_absolute() or '..' in path.parts:continue
   relative=Path(*path.parts[1:]);base=relative.name.lower()
   if not re.search(r'(^|[._-])(licen[cs]e|copying|notice|copyright|authors)([._-]|$)',base):continue
   if relative.suffix.lower() in ['.js','.mjs','.ts','.map','.png']:continue
   content=archive.extractfile(member).read()
   dest=folder/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(content)
   files.append(dict(path=str(dest.relative_to(r)),sha256=hashlib.sha256(content).hexdigest(),upstreamPath=str(relative)))
 license=meta.get('license')
 if not license and name=='khroma' and any(b'Permission is hereby granted' in (r/f['path']).read_bytes() for f in files):license='MIT'
 repository=meta.get('repository');repository=repository.get('url') if isinstance(repository,dict) else repository
 record={**item,'declaredLicense':meta.get('license'),'license':license,'metadataURL':url,'tarball':dist['tarball'],'integrity':integrity,'tarballSHA256':hashlib.sha256(data).hexdigest(),'gitHead':meta.get('gitHead'),'repository':repository,'licenseFiles':sorted(files,key=lambda d:d['path'])}
 if not files:record['reviewRequired']='No license/notice file found in published package'
 return record
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
 futures={pool.submit(work,x):x for x in items}
 for f in concurrent.futures.as_completed(futures):
  item=futures[f]
  try:results.append(f.result())
  except Exception as e:results.append({**item,'error':str(e)});print('FAIL',item['name'],item['version'],str(e))
results.sort(key=lambda x:(x['name'],x['version']))
(out/'manifest.json').write_text(json.dumps({'schema':1,'auditDate':'2026-10-29','scope':'Observed package banners/module paths and conservative audit-reconstruction/source-map dependency coverage; not an original build receipt','assets':[{'path':str(p.relative_to(r)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [r/'WorkOSMac/Resources/official-diagrams.js',r/'WorkOSMac/Resources/katex-mathml.js']],'packages':results},indent=2,ensure_ascii=False)+'\n')
from collections import Counter
print('Collected',len(results),'package/version pairs; license files:',sum(len(x.get('licenseFiles',[])) for x in results))
print('License families:',dict(Counter(str(x.get('license')) for x in results)))
print('Review required:',[(x['name'],x.get('version'),x.get('error')or x.get('reviewRequired')) for x in results if x.get('error')or x.get('reviewRequired')])
