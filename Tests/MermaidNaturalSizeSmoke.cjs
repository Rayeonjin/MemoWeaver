// Exercises the HTML-injected compatibility shim against an OLD v0.9.6
// renderer with width=100% (without needing the 5.3MB official JS bundle).
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../WorkOSMac/OfficialDiagramRuntime.swift'), 'utf8');
const match = source.match(/static let mermaidNaturalSizeScript = #"""\s*<script>([\s\S]*?)<\/script>\s*"""#/);
assert.ok(match, 'Self-contained HTML Mermaid sizing script should exist');
const script = match[1];
new vm.Script(script); // JavaScript syntax
function diagram(width, kind='mermaid', chart=false) {
  let attributes = {'viewBox':`0 0 ${width} 125`};
  const svg = {
    viewBox: {baseVal:{width,height:125}},
    style: {
      maxWidth:'100%', width:'100%',
      setProperty(key,value,importance) { assert.equal(importance,'important'); this[key]=value; },
    },
    getAttribute(key) { return attributes[key] || null; },
    setAttribute(key,value) { attributes[key]=value; }
  };
  return { kind, svg, hasAttribute(key) { return key === 'data-workos-chart' && chart; }, querySelector(query) {
    return query === '.workos-official-target svg' ? svg : null;
  }};
}
const a = diagram(244.2), b = diagram(780.1), markmap = diagram(500, 'markmap'),
  chart = diagram(425.3, 'mermaid', true);
let selected = [a, markmap];
let observer;
class MutationObserver {
  constructor(callback) { this.callback=callback; observer=this; }
  observe(root, options) {
    assert.deepEqual(JSON.stringify(options), JSON.stringify({childList:true,subtree:true}));
  }
}
const document = {
  readyState:'complete', body:{},
  querySelectorAll(selector) {
    assert.equal(selector, '[data-workos-diagram="mermaid"]');
    return selected.filter(d=>d.kind==='mermaid');
  }
};
vm.runInNewContext(script,{document,MutationObserver,Number,Math});
assert.equal(a.svg.style.width,'245px');
assert.equal(a.svg.style['max-width'],'none');
assert.equal(markmap.svg.style.width,'100%', 'Markmap untouched');
selected = [a,b,markmap,chart];
observer.callback(); // the next SVG is inserted asynchronously by old Mermaid JS
assert.equal(b.svg.style.width,'781px');
assert.equal(b.svg.style['max-width'],'none');
assert.equal(markmap.svg.style.width,'100%');
assert.equal(a.svg.getAttribute('data-workos-natural-size'),'1');
assert.equal(chart.svg.style.width,'min(100%, 426px)', 'Charts must shrink to the available pane');
assert.equal(chart.svg.style['max-width'],'100%', 'Chart stays within preview');
assert.equal(chart.svg.getAttribute('data-workos-natural-size'),'1');
console.log('PASS Mermaid natural-size flowchart, responsive XY/pie chart, observer, Markmap untouched');
