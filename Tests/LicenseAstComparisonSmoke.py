"""Test that the optional AST audit accepts renaming but rejects code changes."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
comparison = root / 'tools/license-audit/compare-bundles.cjs'
original = '(()=>{var outer=4;function calc(value){return value+1}window.example=calc;(function(){window.MemoryHomeOfficialDiagrams={};})();})();'
renamed = '(()=>{var alpha=4;function beta(gamma){return gamma+1}window.example=beta;(function(){window.MemoryHomeOfficialDiagrams={};})();})();'
with tempfile.TemporaryDirectory(prefix='mw-license-ast-test-') as folder:
    folder = Path(folder)
    old, candidate = folder / 'old.js', folder / 'candidate.js'
    old.write_text(original)
    cases = [(renamed, True), (renamed.replace('gamma+1', 'gamma+2'), False),
             (renamed.replace('window.example', 'window.other'), False),
             (renamed.replace('gamma+1', 'alpha+1'), False)]
    for source, should_match in cases:
        candidate.write_text(source)
        result = subprocess.run(['node', str(comparison), str(old), str(candidate)], capture_output=True, text=True)
        assert (result.returncode == 0) == should_match, result.stdout + result.stderr
print('PASS: AST renaming accepted; changed literals, properties and lexical references rejected')
