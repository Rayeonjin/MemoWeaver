// Integration sanity test for the WebView bridge. Official packages are
// mocked because their release bundles cannot be downloaded in this runtime.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');

const filename = path.join(__dirname, '..', 'Vendor/official-diagrams/entry.js');
const content = fs.readFileSync(filename, 'utf8').replace(/^import .+?;\s*$/gm, '');
const initialize = [];
const calls = [];
const mermaid = {
  initialize(options) { initialize.push(options); },
  async render(id, source) {
    calls.push(['mermaid', id, source]);
    if (source.includes('FORCE_ERROR')) throw Error('synthetic error');
    return {svg:'<svg role="img"></svg>'};
  }
};
class Transformer {
  constructor(plugins) { assert.equal(plugins.length, 0); this.md={set(o){assert.equal(o.html,false)}}; }
  transform(source) { calls.push(['markmap', source]); return {root:{content:source,children:[]}}; }
}
class Markmap {
  constructor(svg) {this.svg=svg}
  async setData(root) {assert.ok(root.content); calls.push(['setData'])}
  async fit() { calls.push(['fit']) }
}
function target() {
  const cl = new Set();
  const previewSVG = {viewBox:{baseVal:{width:345.2,height:142}},style:{},removeAttribute(){}};
  return {
    classList: {add(s){cl.add(s)},remove(s){cl.delete(s)}},
    style:{},
    innerHTML:'',
    childNodes:[],
    appendChild(child){this.childNodes.push(child)},
    getBoundingClientRect(){return {width:440,height:440}},
    querySelector(which){return which==='svg'?previewSVG:null},
    replaceChildren(){this.innerHTML=''; this.childNodes=[]},
  };
}
function root(kind, source) {
  const attrs={'data-workos-diagram':kind,'data-workos-source':source};
  const r={dataset:{}, attrs, target:target(),
    getAttribute(k){return attrs[k]},
    setAttribute(k,v){attrs[k]=v; if(k==='data-official-rendered')this.dataset.officialRendered=v},
    querySelector(sel){return sel==='.workos-official-target'?this.target:null},
  };
  return r;
}
const roots=[root('mermaid','flowchart LR\n A-->B'),root('markmap','# 프로젝트\n- 작업'),root('mermaid','FORCE_ERROR')];
const testConsole = { ...console, warn() {} }; // synthetic failure is intentional
const context={window:{},document:{readyState:'complete',querySelectorAll(){return roots},createElementNS(ns,tag){return {setAttribute(){},style:{}}}},mermaid,Transformer,Markmap,Promise,console:testConsole};
vm.runInNewContext(content,context, {timeout:1000});
(async()=>{
  await context.window.WorkOSDiagramReady;
  assert.equal(roots[0].dataset.officialRendered,'1');
  assert.equal(roots[0].target.querySelector('svg').style.width, '346px');
  assert.equal(roots[0].target.querySelector('svg').style.maxWidth, 'none');
  assert.equal(roots[1].dataset.officialRendered,'1');
  assert.equal(roots[2].dataset.officialRendered,'0');
  assert.equal(initialize[0].securityLevel,'strict');
  assert.equal(initialize[0].startOnLoad,false);
  assert.ok(calls.some(x=>x[0]==='fit'));
  assert.ok(context.window.WorkOSReady);
  console.log('PASS simulated WebView JS bridge: official APIs, success, errors retain fallback, readiness');
})().catch(e=>{console.error(e);process.exitCode=1});
