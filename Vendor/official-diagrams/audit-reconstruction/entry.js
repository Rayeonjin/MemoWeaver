// Official packages are imported unmodified from their pinned npm releases.
// The source repositories supplied by the user document their implementation.
// The generated artifact is a SINGLE local IIFE; no runtime CDN, import(),
// Node.js, remote CSS, fonts, Mermaid plugins, or WebView network calls.
import mermaid from 'mermaid';
import { Transformer } from 'markmap-lib/no-plugins';
import { Markmap } from 'markmap-view';

(function () {
  'use strict';
  if (window.MemoryHomeOfficialDiagrams) return;
  const transformer = new Transformer([]); // no remote KaTeX/HLJS/plugin assets
  transformer.md.set({ html: false, linkify: false });
  let nextID = 0;
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'strict',
    suppressErrorRendering: true,
    htmlLabels: false,
    theme: 'default',
    fontFamily: '-apple-system, Apple SD Gothic Neo, sans-serif',
    maxTextSize: 60000,
    flowchart: { htmlLabels: false, useMaxWidth: false }
  });

  async function renderMermaid(root, target, source) {
    // Mermaid 12 handles the full diagram syntax and layout, not our Swift SVG
    // approximation. Do not enable clickable diagram links or external assets.
    const id = 'memoryhome-mermaid-' + (++nextID);
    const result = await mermaid.render(id, source);
    if (!result?.svg || !result.svg.includes('<svg')) throw Error('SVG missing');
    target.innerHTML = result.svg;
    const svg = target.querySelector('svg');
    if (!svg) throw Error('SVG missing after insert');
    svg.removeAttribute('onclick');
    // Natural SVG viewBox width keeps text and nodes at their intended px
    // size regardless of preview-pane width. A large diagram scrolls.
    const box = svg.viewBox && svg.viewBox.baseVal;
    if (box && Number.isFinite(box.width) && box.width > 0) {
      svg.style.width = Math.ceil(box.width) + 'px';
    }
    svg.style.maxWidth = 'none';
    svg.style.height = 'auto';
  }

  async function renderMarkmap(root, target, source) {
    const result = transformer.transform(source);
    if (!result?.root) throw Error('Markmap tree missing');
    target.classList.add('markmap-view');
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'Markmap');
    svg.style.width = '100%';
    svg.style.height = '100%';
    target.appendChild(svg);
    const instance = new Markmap(svg, {
      autoFit: false,
      zoom: true,
      pan: true,
      duration: 0,
      maxInitialScale: 1.35,
      maxWidth: 260,
      paddingX: 18,
      scrollForPan: true,
      embedGlobalCSS: true
    });
    await instance.setData(result.root);
    // Dynamic SVG fit relies on a visible container with nonzero dimensions.
    const rect = target.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) throw Error('Markmap host has no size');
    await instance.fit();
    return instance;
  }

  async function renderOne(root) {
    if (root.dataset.officialRendered === '1') return;
    const kind = root.getAttribute('data-workos-diagram');
    const source = root.getAttribute('data-workos-source') || '';
    const target = root.querySelector('.workos-official-target');
    if (!target || !source) return;
    try {
      // The target must be visible for Markmap measurements, but the native
      // fallback stays visible until official SVG is fully ready.
      if (kind === 'markmap') {
        target.style.display = 'block';
        target.style.visibility = 'hidden';
        await renderMarkmap(root, target, source);
      } else if (kind === 'mermaid') {
        await renderMermaid(root, target, source);
      } else return;
      root.setAttribute('data-official-rendered', '1');
      target.style.visibility = '';
      target.style.display = '';
    } catch (error) {
      // Never discard the source or replace a working offline fallback.
      console.warn('[MemoryHome] Official diagram fallback:', error);
      target.replaceChildren();
      target.classList.remove('markmap-view');
      target.style.display = '';
      target.style.visibility = '';
      root.setAttribute('data-official-rendered', '0');
    }
  }

  async function renderAll() {
    const roots = Array.from(document.querySelectorAll('[data-workos-diagram]'));
    // Mermaid internally mutates global state; render sequentially.
    for (const root of roots) await renderOne(root);
  }

  const api = { renderAll, version: 'mermaid-12.2.0-markmap-0.18.12' };
  window.MemoryHomeOfficialDiagrams = api;
  const start = () => {
    window.WorkOSReady = false;
    window.WorkOSDiagramReady = renderAll().catch(e => {
      console.warn('[MemoryHome] Diagram render failed:', e);
    }).then(() => { window.WorkOSReady = true; });
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
