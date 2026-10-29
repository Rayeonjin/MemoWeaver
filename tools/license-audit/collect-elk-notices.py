#!/usr/bin/env python3
"""Rebuild audit evidence from an explicit temporary reconstruction workspace."""
import sys
from pathlib import Path
import urllib.request,urllib.error,xml.etree.ElementTree as ET,zipfile,io,hashlib,re,json,concurrent.futures
r=Path(__file__).resolve().parents[2];out=r/'THIRD_PARTY_LICENSES';w=Path(sys.argv[1]);cache=w/'maven-cache';cache.mkdir(exist_ok=True)
items=[('com.google.guava','guava','31.1-jre','ELK build-declared source dependency'),('com.google.guava','guava-gwt','31.1-jre','ELK GWT-translated source dependency'),('org.gwtproject','gwt-user','2.10.0','ELK GWT runtime/emulation source dependency'),('org.gwtproject','gwt-dev','2.10.0','ELK upstream build-tool dependency; conservative notices'),('com.genmymodel.emf.gwt','emf-common','2.12.4','ELK GWT-translated source dependency'),('com.genmymodel.emf.gwt','emf-ecore','2.12.4','ELK GWT-translated source dependency'),('org.eclipse.xtend','org.eclipse.xtend.lib','2.28.0','ELK GWT-translated source dependency'),('org.eclipse.xtext','org.eclipse.xtext.xbase.lib','2.28.0','ELK GWT-translated source dependency')]
def fetch(url):
 with urllib.request.urlopen(url,timeout=90) as f:return f.read()
def work(item):
 group,artifact,version,scope=item;base='https://repo.maven.apache.org/maven2/'+group.replace('.','/')+'/'+artifact+'/'+version+'/'+artifact+'-'+version
 d=out/'maven'/group/artifact/version;d.mkdir(parents=True,exist_ok=True)
 pom=fetch(base+'.pom');(d/'pom.xml').write_bytes(pom)
 root=ET.fromstring(pom);ns={'m':'http://maven.apache.org/POM/4.0.0'}
 licenses=[{c.tag.split('}')[-1]:c.text for c in x} for x in root.findall('m:licenses/m:license',ns)]
 sources=base+'-sources.jar'
 try:data=fetch(sources)
 except urllib.error.HTTPError as e:
  if e.code!=404:raise
  sources=base+'.jar';data=fetch(sources)
 sha=fetch(sources+'.sha1').decode().strip().split()[0];assert hashlib.sha1(data).hexdigest()==sha
 (cache/(artifact+'-'+version+'.jar')).write_bytes(data)
 files=[];headers={}
 with zipfile.ZipFile(io.BytesIO(data)) as z:
  for name in z.namelist():
   if name.endswith('/'):continue
   content=None;basename=Path(name).name.lower()
   if re.search(r'(^|[._-])(license|licence|notice|copying|about|copyright)([._-]|$)',basename) and not name.endswith(('.java','.class')):
    content=z.read(name);target=d/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content);files.append(str(target.relative_to(r)))
   if name.endswith('.java'):
    text=z.read(name).decode('utf8',errors='replace')[:12000]
    for c in re.findall(r'/\*[\s\S]*?\*/',text):
     if re.search(r'copyright|licensed under|eclipse public license',c,re.I):headers.setdefault(c,[]).append(name)
 if headers:
  txt=''.join('Source paths: '+', '.join(paths[:4])+ (' (and other files)'if len(paths)>4 else '')+'\n'+h+'\n\n'for h,paths in sorted(headers.items()))
  p=d/'SOURCE_COPYRIGHT_HEADERS.txt';p.write_text(txt);files.append(str(p.relative_to(r)))
 return {'group':group,'artifact':artifact,'version':version,'scope':scope,'pomURL':base+'.pom','declaredLicenses':licenses,'sourceURL':sources,'sourceSHA256':hashlib.sha256(data).hexdigest(),'licenseFiles':[{'path':p,'sha256':hashlib.sha256((r/p).read_bytes()).hexdigest()} for p in files],'sourceHeaderCount':len(headers)}
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for item,ret in zip(items,pool.map(work,items)):
  results.append(ret);print(ret['artifact'],ret['declaredLicenses'],'license files',len(ret['licenseFiles']))
(out/'maven-manifest.json').write_text(json.dumps({'basis':'elkjs 0.9.3 build.gradle; conservative source/build dependency notice coverage, not proof every Java class survives GWT compilation','packages':results},indent=2)+'\n')
