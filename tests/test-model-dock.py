#!/usr/bin/env python3
"""Boundary tests for downloads, credential handling and service generation."""
import argparse
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader("dock", str(Path(__file__).resolve().parents[1] / "model-dock"))
spec = importlib.util.spec_from_loader(loader.name, loader)
dock = importlib.util.module_from_spec(spec)
loader.exec_module(dock)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.headers.get("Authorization") != "Bearer test-private-key":
            self.send_response(401)
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"data": [{"id": "test", "status": {
            "value": "loaded", "args": ["--api-key", "SHOULD-NOT-APPEAR"]}}]}).encode())

    def do_POST(self):
        if self.headers.get("Authorization") != "Bearer test-private-key":
            self.send_response(401)
            self.end_headers()
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        chunks = [{"choices": [{"delta": {"role": "assistant"}}]},
                  {"choices": [{"delta": {"reasoning_content": "thinking"}}]},
                  {"choices": [{"delta": {"content": "hello"}}]},
                  {"choices": [], "usage": {"completion_tokens": 1}, "timings": {"cache_n": 3}}]
        for chunk in chunks:
            self.wfile.write(b"data: " + json.dumps(chunk).encode() + b"\n\n")
        self.wfile.write(b"data: [DONE]\n\n")


class DockTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.config = self.home / "config"
        self.state = self.home / "state"
        self.config.mkdir()
        self.patches = [patch.object(dock, "CONFIG", self.config), patch.object(dock, "STATE", self.state),
                        patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.home)})]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def config_value(self, port=8090):
        return {"version": 1, "port": port, "max_loaded": 2, "server": "/runtime/llama-server",
                "models": [{"id": "test", "file": "/models/hello world.gguf", "device": "Vulkan0",
                            "context": 4096, "slots": 2, "cache": "f16", "prompt_cache_mib": 1024}]}

    def test_atomic_private_and_versioned_config(self):
        dock.save(self.config_value())
        self.assertEqual(dock.load()["max_loaded"], 2)
        self.assertEqual((self.config / "config.json").stat().st_mode & 0o777, 0o600)
        (self.config / "config.json").write_text('{"version": 99}')
        with self.assertRaises(ValueError):
            dock.load()

    def test_service_has_bounded_context_and_no_network_exposure(self):
        result = argparse.Namespace(stdout="--models-preset --models-max --api-key-file --cache-ram --cors-origins --no-agent")
        with patch.object(dock, "run", return_value=result), patch.object(dock.platform, "system", return_value="Linux"), \
                patch.object(dock.shutil, "which", return_value="systemctl"):
            dock.render(self.config_value())
        preset = (self.config / "models.ini").read_text()
        self.assertIn("ctx-size = 8192", preset)
        self.assertIn("parallel = 2", preset)
        self.assertIn("cache-ram = 1024", preset)
        self.assertIn("load-on-startup = false", preset)
        service = (self.home / "systemd/user" / dock.UNIT).read_text()
        self.assertIn('"--host" "127.0.0.1"', service)
        self.assertIn('"--models-max" "2"', service)
        self.assertIn('"--no-agent"', service)
        self.assertNotIn((self.config / "api-key").read_text().strip(), service)
        self.assertNotIn("WantedBy=multi-user", service)

    def test_key_does_not_rotate_on_upgrade(self):
        result = argparse.Namespace(stdout="--models-preset --models-max --api-key-file --cache-ram")
        with patch.object(dock, "run", return_value=result), patch.object(dock.platform, "system", return_value="Linux"), \
                patch.object(dock.shutil, "which", return_value="systemctl"):
            dock.render(self.config_value())
            first = (self.config / "api-key").read_bytes()
            dock.render(self.config_value())
        self.assertEqual(first, (self.config / "api-key").read_bytes())

    def test_unsupported_mtp_does_not_replace_presets(self):
        dock.atomic(self.config / "models.ini", "owner preset\n")
        config = self.config_value()
        config["models"][0]["draft_tokens"] = 3
        result = argparse.Namespace(stdout="--models-preset --models-max --api-key-file --cache-ram")
        with patch.object(dock, "run", return_value=result), patch.object(dock.platform, "system", return_value="Linux"), \
                patch.object(dock.shutil, "which", return_value="systemctl"), self.assertRaises(ValueError):
            dock.render(config)
        self.assertEqual((self.config / "models.ini").read_text(), "owner preset\n")

    def test_unrelated_service_is_preserved(self):
        path = self.home / "systemd/user" / dock.UNIT
        path.parent.mkdir(parents=True)
        path.write_text("unrelated service")
        result = argparse.Namespace(stdout="--models-preset --models-max --api-key-file --cache-ram")
        with patch.object(dock, "run", return_value=result), patch.object(dock.platform, "system", return_value="Linux"), \
                patch.object(dock.shutil, "which", return_value="systemctl"), self.assertRaises(ValueError):
            dock.render(self.config_value())
        self.assertEqual(path.read_text(), "unrelated service")

    def test_unit_values_cannot_expand_or_inject_directives(self):
        self.assertEqual(dock.unit_arg('/a/$HOME/%h/"x"'), '"/a/$$HOME/%%h/\\"x\\""')
        with self.assertRaises(ValueError):
            dock.unit_arg("safe\nExecStart=/bad")
        for ident in ("../file", "[preset]", "x\ny", "--option", "a" * 65):
            with self.assertRaises(ValueError):
                dock.validate_id(ident)

    def test_download_size_and_hash_failure_preserve_destination(self):
        data = b"GGUFpayload"
        catalog = {"test": {"repository": "test/model", "revision": "a" * 40,
                            "file": "test.gguf", "bytes": len(data), "sha256": "0" * 64}}
        fake_root = self.home / "repo"
        fake_root.mkdir()
        (fake_root / "models.json").write_text(json.dumps(catalog))
        destination = self.home / "models"
        args = argparse.Namespace(starter="test", directory=str(destination))
        with patch.object(dock, "ROOT", fake_root), patch.object(dock.urllib.request, "urlopen", return_value=io.BytesIO(data)), \
                self.assertRaises(ValueError):
            dock.fetch(args)
        self.assertEqual(list(destination.iterdir()), [])

    def test_client_profile_does_not_embed_key_or_replace_defaults(self):
        config = self.config_value()
        dock.save(config)
        args = argparse.Namespace(kind="pi", model="test", max_output=512)
        with self.assertRaises(ValueError):
            dock.client(args)
        config["models"][0]["context"] = 8192
        dock.save(config)
        with self.assertRaises(ValueError):
            dock.client(argparse.Namespace(kind="pi", model="test", max_output=8192))
        with self.assertRaises(ValueError):
            dock.client(argparse.Namespace(kind="codex", model="test", max_output=4096))
        dock.atomic(self.config / "api-key", "PRIVATE-CREDENTIAL\n")
        with patch("sys.stdout", io.StringIO()):
            dock.client(args)
            dock.client(argparse.Namespace(kind="codex", model="test"))
        files = list((self.state / "clients").rglob("*"))
        for file in files:
            if file.is_file():
                self.assertNotIn("PRIVATE-CREDENTIAL", file.read_text())
                self.assertEqual(file.stat().st_mode & 0o077, 0)
        launch = self.state / "clients/codex-test/launch"
        compile(launch.read_text(), str(launch), "exec")
        self.assertFalse((self.home / "config.toml").exists())

    def test_install_is_idempotent_and_preserves_foreign_entries(self):
        with patch.object(dock.Path, "home", return_value=self.home), patch("sys.stdout", io.StringIO()):
            dock.install()
            dock.install()
            link = self.home / ".agents/skills/omarchy-model-dock"
            self.assertEqual(link.resolve(), dock.ROOT)
            link.unlink()
            link.mkdir()
            (link / "original").write_text("owner skill")
            with self.assertRaises(ValueError):
                dock.install()
            self.assertEqual((link / "original").read_text(), "owner skill")

    def test_successful_download_has_provenance_and_is_idempotent(self):
        data = b"GGUFpayload"
        catalog = {"test": {"repository": "test/model", "revision": "a" * 40,
                            "file": "test.gguf", "bytes": len(data), "sha256": dock.hashlib.sha256(data).hexdigest()}}
        fake_root = self.home / "repo"
        fake_root.mkdir()
        (fake_root / "models.json").write_text(json.dumps(catalog))
        args = argparse.Namespace(starter="test", directory=str(self.home / "models"))
        with patch.object(dock, "ROOT", fake_root), patch.object(dock.urllib.request, "urlopen", return_value=io.BytesIO(data)) as net:
            target = dock.fetch(args)
            dock.fetch(args)
            self.assertEqual(net.call_count, 1)
        self.assertEqual(target.read_bytes(), data)
        self.assertEqual(json.loads(target.with_suffix(".gguf.source.json").read_text()), catalog["test"])

    def test_auth_sse_and_status_redaction(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        dock.save(self.config_value(server.server_port))
        dock.atomic(self.config / "api-key", "test-private-key\n")
        try:
            out = io.StringIO()
            with patch("sys.stdout", out):
                dock.check()
            self.assertIn('"unauthenticated_status": 401', out.getvalue())
            self.assertNotIn("test-private-key", out.getvalue())
            self.assertNotIn("SHOULD-NOT-APPEAR", out.getvalue())
            result = dock.infer("test", "hello")
            self.assertEqual(result["answer"], "hello")
            self.assertEqual(result["timings"]["cache_n"], 3)
            self.assertLessEqual(result["ttft_seconds"], result["visible_ttft_seconds"])
            with patch.object(dock, "run", return_value=argparse.Namespace(returncode=0)), \
                    patch.object(dock.shutil, "which", return_value="systemctl"):
                value = dock.status()
            self.assertTrue(value["ready"])
            self.assertNotIn("SHOULD-NOT-APPEAR", json.dumps(value))
            (self.config / "api-key").chmod(0o644)
            with self.assertRaises(ValueError):
                dock.credentials()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
