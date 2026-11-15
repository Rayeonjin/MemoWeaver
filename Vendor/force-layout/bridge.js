// MemoWeaver's synchronous bridge. d3's scheduler is intentionally inert in
// JavaScriptCore: forceSimulation is stopped and only bounded manual ticks run.
// No labels, source text, database or remote API is exposed to this runtime.
globalThis.memoWeaverForceSolve = function (json) {
  const input = JSON.parse(json);
  const pinned = new Map(input.pinned.map(p => [p.id, p]));
  const nodes = input.nodes.map(p => {
    const pin = pinned.get(p.id);
    return {id: p.id, x: p.x, y: p.y, fx: pin ? pin.x : null, fy: pin ? pin.y : null};
  });
  const links = input.links.map(e => ({source: e.source, target: e.target}));
  const simulation = d3.forceSimulation(nodes).stop()
    .force('links', d3.forceLink(links).id(p => p.id).distance(185).strength(0.45))
    .force('charge', d3.forceManyBody().strength(-380))
    .force('collide', d3.forceCollide(76).iterations(2))
    .force('x', d3.forceX(0).strength(0.025))
    .force('y', d3.forceY(0).strength(0.025));
  simulation.tick(180);
  return JSON.stringify(nodes.map(p => ({id: p.id, x: p.x, y: p.y})));
};
