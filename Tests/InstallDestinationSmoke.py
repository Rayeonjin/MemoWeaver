"""Run the real launcher with disposable install/build stand-ins, never real apps."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='mw-install-destination-') as directory:
    scratch = Path(directory)
    launcher = scratch / 'install-v0.9.70.sh'
    launcher.write_bytes((root / launcher.name).read_bytes())
    launcher.chmod(0o755)
    log = scratch / 'calls'
    env = dict(os.environ, MW_INSTALL_TEST_LOG=str(log))
    def script(path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/bash\nset -eu\n' + body)
        path.chmod(0o755)
    script(scratch/'install.sh', 'printf "install %s\\n" "$*" >> "$MW_INSTALL_TEST_LOG"\nexit "${MW_INSTALL_TEST_FAILURE:-0}"\n')
    script(scratch/'build.sh', 'echo build >> "$MW_INSTALL_TEST_LOG"\n')
    # Use the current gate's actual list, but no compile/UI work for dispatch tests.
    import re
    for name in re.findall(r'^    (test-[^\s]+\.sh)$', launcher.read_text(), re.M):
        script(scratch/'scripts/tests'/name, 'echo test >> "$MW_INSTALL_TEST_LOG"\n')
    def run(*args, failure='0'):
        log.write_text('')
        result = subprocess.run([str(launcher), *args], cwd='/tmp', env=dict(env, MW_INSTALL_TEST_FAILURE=failure), capture_output=True, text=True)
        return result, log.read_text().splitlines()
    result, calls = run()
    assert result.returncode == 0 and calls == ['install --yes --open'], (result, calls)
    assert 'Selected: /Applications' in result.stdout
    result, calls = run('--build-only')
    assert result.returncode == 0 and calls == ['build'], (result, calls)
    result, calls = run('--verify')
    assert result.returncode == 0 and calls == ['test'] * 12 + ['build'], (result, calls)
    result, calls = run(failure='42')
    assert result.returncode == 42 and calls == ['install --yes --open'], (result, calls)
    assert 'Installation command completed' not in result.stdout
    result, calls = run('--unknown')
    assert result.returncode != 0 and not calls
    installer = (root/'install.sh').read_text()
    assert 'INSTALL_DIR=/Applications' in installer
    assert 'sudo -v || fail' in installer
    assert 'Signature check failed; original app restored.' in installer
print('PASS: default system destination, build/verify isolation, failure propagation, invalid flags')
