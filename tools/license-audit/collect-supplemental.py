#!/usr/bin/env python3
"""Rebuild audit evidence from an explicit temporary reconstruction workspace."""
import sys
from pathlib import Path
import urllib.request,json,tarfile,hashlib,re
r=Path(__file__).resolve().parents[2];out=r/'THIRD_PARTY_LICENSES';w=Path(sys.argv[1])
records=[]
def save(url,target):
 with urllib.request.urlopen(url,timeout=60) as f:data=f.read()
 p=out/target;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
 records.append({'url':url,'path':str(p.relative_to(r)),'sha256':hashlib.sha256(data).hexdigest()})
 return data
for relative in ['distro-source/core/src/COPYING','user/super/com/google/gwt/emul/COPYING','user/src/com/google/gwt/core/COPYING','user/src/com/google/gwt/i18n/COPYING','user/src/com/google/gwt/json/COPYING','user/src/com/google/gwt/user/COPYING','user/src/com/google/gwt/xml/COPYING']:
 save('https://raw.githubusercontent.com/gwtproject/gwt/2.10.0/'+relative,'supplemental/gwt-2.10.0/'+relative)
for repo,ref,files,target in [('google/guava','v31.1',['COPYING','CONTRIBUTORS'],'guava-31.1'),('eclipse-elk/elk','62d5909f96fad541bc101ad52dabaece6b7eab7e',['LICENSE.md','NOTICE.md'],'elk-0.9.1'),('kieler/elkjs','a8304cf79fde75bc2ab1a89d28320f53f8637436',['LICENSE.md','build.gradle'],'elkjs-0.9.3')]:
 for name in files:save(f'https://raw.githubusercontent.com/{repo}/{ref}/{name}',f'supplemental/{target}/{name}')
for group,artifact,version in [('com.google.guava','guava-parent','31.1-jre'),('org.gwtproject','gwt','2.10.0'),('com.genmymodel.emf.gwt','emf-parent','2.12.4')]:
 save('https://repo.maven.apache.org/maven2/'+group.replace('.','/')+'/'+artifact+'/'+version+'/'+artifact+'-'+version+'.pom',f'supplemental/maven-parents/{artifact}-{version}.pom')
# Original copies from pinned upstream repositories; retain both licensing options.
meta=json.loads(urllib.request.urlopen('https://registry.npmjs.org/regenerator-runtime/0.14.1',timeout=30).read())
with urllib.request.urlopen(meta['dist']['tarball'],timeout=60) as response:data=response.read()
import io
with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
 content=archive.extractfile('package/LICENSE').read()
 p=out/'embedded/regenerator-runtime-LICENSE';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
 records.append({'url':meta['dist']['tarball']+'#package/LICENSE','path':str(p.relative_to(r)),'sha256':hashlib.sha256(content).hexdigest(),'note':'Supplemental MIT permission text; the embedded DOMPurify banner does not identify a runtime version.'})
save('https://www.eclipse.org/org/documents/epl-v10.html','supplemental/EPL-1.0.html')
# FastDom declares MIT but its npm tarball has no separate license file.
# Preserve the exact declaration and authors; do not fabricate copyright dates.
with tarfile.open(w/'registry-cache/fastdom-1.0.12.tgz') as t:
 folder=out/'packages/fastdom/1.0.12'
 for original in ['package.json','README.md']:
  data=t.extractfile('package/'+original).read();p=folder/original;p.write_bytes(data)
  records.append({'url':'https://registry.npmjs.org/fastdom/-/fastdom-1.0.12.tgz#package/'+original,'path':str(p.relative_to(r)),'sha256':hashlib.sha256(data).hexdigest()})
 source=t.extractfile('package/fastdom.js').read().decode();header=re.search(r'/\*\*[\s\S]*?\*/',source).group()
 p=folder/'UPSTREAM-AUTHORS.txt';p.write_text(header+'\n')
 records.append({'url':'https://registry.npmjs.org/fastdom/-/fastdom-1.0.12.tgz#package/fastdom.js','path':str(p.relative_to(r)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
mit=(out/'packages/katex/0.16.27/LICENSE').read_text();start=mit.index('Permission is hereby granted');p=out/'embedded/MIT-permission-text.txt';p.write_text(mit[start:])
records.append({'url':'https://registry.npmjs.org/katex/-/katex-0.16.27.tgz#package/LICENSE (permission text only; component attribution supplied separately)','path':str(p.relative_to(r)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'supplemental-sources.json').write_text(json.dumps(records,indent=2)+'\n')
print('Collected',len(records),'additional original notices and source declarations')
