// Compare JavaScript bindings, properties, literals and statement order while
// ignoring minifier-chosen bound identifier names and parser source locations.
// The only excluded statement must be the final local MemoWeaver bridge IIFE.
const fs = require('fs');
const crypto = require('crypto');
const parser = require('@babel/parser');
const traverse = require('@babel/traverse').default;
const omit = new Set(['start','end','loc','extra','leadingComments','trailingComments','innerComments','comments','tokens','errors']);
const standalone = process.argv[5] === '--standalone';
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
function inspect(filename) {
  const source = fs.readFileSync(filename, 'utf8');
  const ast = parser.parse(source, {sourceType: 'script'});
  const body = standalone ? ast.program.body : ast.program.body[0].expression.callee.body.body;
  const positions = new Map(body.map((node, index) => [node, index]));
  const references = new WeakMap(), bindings = new Map();
  traverse(ast, {'ReferencedIdentifier|BindingIdentifier'(path) {
    const binding = path.scope.getBinding(path.node.name);
    if (!binding) return;
    references.set(path.node, binding);
    if (!bindings.has(binding)) {
      let parent = binding.path;
      while (parent && !positions.has(parent.node)) parent = parent.parentPath;
      bindings.set(binding, {statement: parent ? positions.get(parent.node) : -1, start: binding.identifier.start});
    }
  }});
  const groups = {};
  for (const [binding, info] of bindings) (groups[info.statement] ??= []).push([binding, info]);
  for (const values of Object.values(groups)) {
    values.sort((a,b) => a[1].start - b[1].start).forEach(([binding, info], index) => {
      info.key = `statement${info.statement}:binding${index}`;
    });
  }
  function canonical(node) {
    if (node === null || typeof node !== 'object') return node;
    if (Array.isArray(node)) return node.map(canonical);
    const output = {};
    for (const key of Object.keys(node).sort()) {
      if (omit.has(key)) continue;
      output[key] = key === 'name' && node.type === 'Identifier' && references.has(node)
        ? bindings.get(references.get(node)).key : canonical(node[key]);
    }
    return output;
  }
  const last = body.at(-1);
  const bridge = source.slice(last.start, last.end);
  if (!standalone && (last.type !== 'ExpressionStatement' || last.expression.type !== 'CallExpression' ||
      last.expression.callee.type !== 'FunctionExpression' || !bridge.includes('window.MemoryHomeOfficialDiagrams'))) {
    throw Error('Expected final local MemoWeaver bridge IIFE');
  }
  return {sha256: crypto.createHash('sha256').update(source).digest('hex'), hashes: body.map(node => hash(canonical(node)))};
}
const original = inspect(process.argv[2]), reconstruction = inspect(process.argv[3]);
if (original.hashes.length !== reconstruction.hashes.length) throw Error('Statement counts differ');
const differences = original.hashes.flatMap((hash, index) => hash !== reconstruction.hashes[index] ? [index] : []);
if (differences.some(index => standalone || index !== original.hashes.length - 1)) throw Error('Library statements differ: ' + differences);
const result = {schema: 1, comparison: 'scope-aware AST alpha equivalence', originalSHA256: original.sha256,
  reconstructionSHA256: reconstruction.sha256, libraryStatements: original.hashes.length - (standalone ? 0 : 1),
  matchedLibraryStatements: original.hashes.length - (standalone ? 0 : 1), excludedLocalBridgeStatement: standalone ? null : original.hashes.length - 1,
  differingStatements: differences, originalBuildReceipt: false};
const json = JSON.stringify(result, null, 2) + '\n';
if (process.argv[4]) fs.writeFileSync(process.argv[4], json);
process.stdout.write(json);
