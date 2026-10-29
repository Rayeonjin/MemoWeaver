#!/usr/bin/env python3
"""Offline integrity/coverage gate for retained assets and shipped legal files."""
from pathlib import Path
import argparse
import hashlib
import json

parser = argparse.ArgumentParser()
parser.add_argument('--app', type=Path, help='Also verify the built app resources')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
legal = root / 'THIRD_PARTY_LICENSES'
manifest = json.loads((legal / 'manifest.json').read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def local_file(relative):
    path = (root / relative).resolve()
    assert root in path.parents and path.is_file(), 'Missing/unsafe notice: ' + relative
    return path

for asset in manifest['assets']:
    assert digest(local_file(asset['path'])) == asset['sha256'], 'Runtime asset changed; repeat audit'
for component in manifest['packages'] + manifest['embeddedComponents']:
    assert component.get('selectedLicense') or component.get('license'), component['name']
    assert not component.get('error') and not component.get('reviewRequired'), component['name']
    assert component['licenseFiles'], 'Notice evidence missing: ' + component['name']
    for notice in component['licenseFiles']:
        assert digest(local_file(notice['path'])) == notice['sha256'], notice['path']
for component in json.loads((legal / 'maven-manifest.json').read_text())['packages']:
    assert component['sourceURL'].startswith('https://repo.maven.apache.org/'), component['artifact']
    assert len(component['sourceSHA256']) == 64
    assert component['selectedLicense'] in {'Apache-2.0', 'EPL-1.0', 'EPL-2.0'}
    for notice in component['licenseFiles']:
        assert digest(local_file(notice['path'])) == notice['sha256'], notice['path']
for notice in json.loads((legal / 'supplemental-sources.json').read_text()):
    assert digest(local_file(notice['path'])) == notice['sha256'], notice['path']
proof = json.loads((root / 'Vendor/official-diagrams/audit-reconstruction/ast-comparison.json').read_text())
assert proof['originalSHA256'] == manifest['assets'][0]['sha256']
for filename, expected in proof['auditReconstructionFiles'].items():
    assert digest(root / 'Vendor/official-diagrams/audit-reconstruction' / filename) == expected, filename
assert proof['libraryStatements'] == proof['matchedLibraryStatements'] == 4233
assert proof['differingStatements'] == [proof['excludedLocalBridgeStatement']]
indexed = set()
for row in (legal / 'FILES.sha256').read_text().splitlines():
    expected, relative = row.split('  ', 1)
    path = (legal / relative).resolve()
    assert legal.resolve() in path.parents and path.is_file(), relative
    assert digest(path) == expected, relative
    indexed.add(relative)
actual = {str(p.relative_to(legal)) for p in legal.rglob('*') if p.is_file() and p.name != 'FILES.sha256'}
assert indexed == actual, 'Legal-file integrity index is incomplete'
text = (legal / 'ALL_LICENSES.txt').read_text()
for needle in ['Eclipse Public License', 'Cure53', 'Ralf S. Engelschall', 'Gaetan Renaudeau', 'Koen Bok', 'SOURCE_AVAILABILITY', 'IBM Corporation']:
    assert needle in text, 'Consolidated notice missing: ' + needle
assert len(text) > 100_000
for filename in ['LICENSE', 'NOTICE', 'COPYRIGHT.md']:
    assert (root / filename).read_text() in text, 'Standalone export missing current project notice: ' + filename
if args.app:
    resources = args.app.resolve() / 'Contents/Resources'
    for source in legal.rglob('*'):
        if source.is_file():
            assert source.read_bytes() == (resources / 'Licenses' / source.relative_to(legal)).read_bytes(), str(source)
    for filename in ['LICENSE', 'NOTICE', 'COPYRIGHT.md', 'TRADEMARKS.md', 'BRAND_ASSETS.md', 'THIRD_PARTY_NOTICES.md']:
        assert (root / filename).read_bytes() == (resources / filename).read_bytes(), filename
    for asset in manifest['assets']:
        assert digest(resources / Path(asset['path']).name) == asset['sha256']
print('PASS: retained assets, npm/embedded/Maven notices, EPL source links and complete legal-file hashes' + ('; app copies match' if args.app else ''))
