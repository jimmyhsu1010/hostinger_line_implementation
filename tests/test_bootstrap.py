import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HERMES_ROOT = Path(os.environ.get("HERMES_ROOT", "/opt/hermes"))
HERMES_PYTHON = Path(os.environ.get("HERMES_PYTHON", "/opt/hermes/.venv/bin/python"))


class BootstrapScriptsTest(unittest.TestCase):
    def run_cmd(self, args, *, env=None, cwd=ROOT, check=True):
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        result = subprocess.run(
            args,
            cwd=cwd,
            env=merged_env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        if check and result.returncode != 0:
            self.fail(f"command failed ({result.returncode}): {' '.join(args)}\n{result.stdout}")
        return result

    def test_install_creates_line_plugin_directory_and_copies_adapter_and_metadata(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "plugins" / "platforms" / "line" / "adapter.py"
            result = self.run_cmd(
                ["bash", "scripts/install-line-adapter.sh"],
                env={
                    "TARGET_ADAPTER": str(target),
                    "PYTHONPYCACHEPREFIX": str(Path(td) / "pycache"),
                },
            )
            self.assertIn("OK: LINE adapter installed", result.stdout)
            self.assertTrue(target.exists())
            self.assertTrue((target.parent / "plugin.yaml").exists())
            self.assertIn("LINE Messaging API platform adapter", target.read_text())
            self.assertIn("name: line-platform", (target.parent / "plugin.yaml").read_text())

    def test_verify_line_fails_strictly_but_can_skip_health_during_install(self):
        with tempfile.TemporaryDirectory() as td:
            adapter = Path(td) / "adapter.py"
            shutil.copy(ROOT / "line" / "adapter.py", adapter)
            env_file = Path(td) / ".env"
            env_file.write_text(
                "LINE_CHANNEL_ACCESS_TOKEN=dummy\n"
                "LINE_CHANNEL_SECRET=dummy\n"
                "LINE_PUBLIC_URL=https://example.invalid\n"
                "LINE_PORT=65534\n"
            )
            base_env = {
                "ENV_FILE": str(env_file),
                "TARGET_ADAPTER": str(adapter),
                "LINE_PORT": "65534",
                "PYTHONPYCACHEPREFIX": str(Path(td) / "pycache"),
            }
            strict = self.run_cmd(["bash", "scripts/verify-line.sh"], env=base_env, check=False)
            self.assertNotEqual(strict.returncode, 0)
            self.assertIn("local_health=FAILED", strict.stdout)

            skipped = self.run_cmd(
                ["bash", "scripts/verify-line.sh", "--skip-health"],
                env=base_env,
                check=False,
            )
            self.assertEqual(skipped.returncode, 0, skipped.stdout)
            self.assertIn("health=SKIPPED", skipped.stdout)


@unittest.skipUnless(HERMES_PYTHON.exists() and HERMES_ROOT.exists(), "Hermes runtime not available")
class LineAdapterMediaCacheTest(unittest.TestCase):
    def test_downloaded_media_uses_type_specific_cache_helpers(self):
        code = f'''
import importlib.util
import os
import sys
from pathlib import Path
os.environ.setdefault("LINE_CHANNEL_ACCESS_TOKEN", "dummy-token")
os.environ.setdefault("LINE_CHANNEL_SECRET", "dummy-secret")
sys.path.insert(0, {str(HERMES_ROOT)!r})
name = "line_adapter_under_test"
spec = importlib.util.spec_from_file_location(name, {str(ROOT / "line" / "adapter.py")!r})
mod = importlib.util.module_from_spec(spec)
sys.modules[name] = mod
spec.loader.exec_module(mod)
for msg_type, data, filename in [
    ("audio", b"\\x00\\x00\\x00\\x18ftypM4A " + b"0" * 16, None),
    ("file", b"%PDF-1.7\\nbody", "report.pdf"),
    ("video", b"\\x00\\x00\\x00\\x18ftypmp42" + b"0" * 16, None),
]:
    path = mod._cache_downloaded_media(data, msg_type, "MSG123", filename)
    print(msg_type, path)
    assert Path(path).exists(), path
    if msg_type == "audio":
        assert "/audio" in path or "audio_cache" in path, path
    elif msg_type == "video":
        assert "/video" in path or "video_cache" in path, path
    else:
        assert "/documents" in path or "document" in path or "/cache/" in path, path
    Path(path).unlink(missing_ok=True)
'''
        result = subprocess.run(
            [str(HERMES_PYTHON), "-c", code],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
