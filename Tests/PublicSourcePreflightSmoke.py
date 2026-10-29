"""Exercise source publication checks with disposable, synthetic Git fixtures."""
from pathlib import Path
import shutil
import subprocess
import tempfile

source_script = Path(__file__).resolve().parents[1] / "tools/public-source-preflight.sh"
with tempfile.TemporaryDirectory(prefix="mw-public-source-") as scratch:
    root = Path(scratch)
    (root / "tools").mkdir()
    script = root / "tools/public-source-preflight.sh"
    shutil.copyfile(source_script, script)
    resources = root / "WorkOSMac/Resources"
    resources.mkdir(parents=True)
    for name in ("LICENSE", "NOTICE", "TRADEMARKS.md", "AGENTS.md"):
        (root / name).write_text("Synthetic test fixture\n")
    for name in ("official-diagrams.js", "katex-mathml.js"):
        (resources / name).write_text("fixture\n")
    (root / ".gitignore").write_text("/build/\n*.sqlite\n")
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    build = root / "build"
    build.mkdir()
    # This is fake pattern data, not a credential.
    synthetic = "ghp_" + "A" * 30
    (build / "ignored.txt").write_text(synthetic)

    def scan():
        return subprocess.run(["bash", str(script)], cwd=root, capture_output=True, text=True)

    assert scan().returncode == 0, "Ignored local build outputs must not block source upload"
    leak = root / "synthetic-secret.txt"
    leak.write_text((synthetic + "\n") * 100)
    assert scan().returncode != 0, "Many positive matches must not be hidden by pipefail/SIGPIPE"
    leak.unlink()
    forbidden = root / "synthetic.sqlite"
    forbidden.write_text("not real data")
    subprocess.run(["git", "add", "-f", "synthetic.sqlite"], cwd=root, check=True)
    assert scan().returncode != 0, "Tracked files must be scanned even if ignored"
    subprocess.run(["git", "rm", "-f", "--cached", "synthetic.sqlite"], cwd=root, check=True, capture_output=True)
    assert scan().returncode == 0, "Clean source candidates should pass again"
print("PASS: ignored builds, repeated secret patterns, tracked ignored databases, clean source")
