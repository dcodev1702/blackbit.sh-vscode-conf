#!/usr/bin/env python3
"""Offline regression tests for the BlackBit API diagnostic script."""

import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
MODEL = "offline_model"
DUMMY_KEY = "offline-test-key"


def message_response(content):
    return {"choices": [{"message": {"role": "assistant", "content": content}}]}


def mock_curl():
    arguments = sys.argv[1:]
    output = Path(arguments[arguments.index("-o") + 1])
    if "--data-binary" in arguments:
        request_file = arguments[arguments.index("--data-binary") + 1][1:]
        request = json.loads(Path(request_file).read_text(encoding="utf-8"))
        if any(message["role"] == "tool" for message in request["messages"]):
            stage = "roundtrip"
        else:
            stage = "tool" if "tools" in request else "chat"
        request_path = Path(os.environ["BB_TEST_REQUESTS"]) / f"{stage}.json"
        request_path.write_text(json.dumps(request), encoding="utf-8")
    else:
        stage = "catalog"
    if stage == os.environ.get("BB_TEST_HTTP_ERROR"):
        return 22
    response = json.loads(os.environ["BB_TEST_RESPONSES"])[stage]
    output.write_text(json.dumps(response), encoding="utf-8")
    return 0


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="blackbit-offline-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        binaries = self.directory / "bin"
        binaries.mkdir()
        mock = binaries / "curl"
        shutil.copyfile(__file__, mock)
        mock.chmod(0o700)
        self.requests = self.directory / "requests"
        self.requests.mkdir()
        self.environment = {
            "PATH": f"{binaries}{os.pathsep}{os.defpath}",
            "HOME": str(self.directory),
            "TMPDIR": str(self.directory),
            "BLACKBIT_API_KEY": DUMMY_KEY,
            "BLACKBIT_BASE_URL": "https://blackbit.invalid/v1",
            "BLACKBIT_ENV_FILE": str(self.directory / "missing.env"),
            "BLACKBIT_KEY_LOADER": str(ROOT / ".blackbit/load-blackbit-key.sh"),
            "BB_TEST_REQUESTS": str(self.requests),
        }

    def run_validator(self, overrides=None, *, stdin=subprocess.DEVNULL):
        responses = {
            "catalog": {"data": [{"id": MODEL, "model_info": {"supports_tools": True}}]},
            "chat": message_response("BLACKBIT_CHAT_OK"),
            "tool": {
                "choices": [{"message": {
                    "role": "assistant",
                    "content": None,
                    "reasoning_content": "Offline fixture reasoning",
                    "tool_calls": [{
                        "id": "offline_call",
                        "type": "function",
                        "function": {
                            "name": "bb_validation_echo",
                            "arguments": '{"value":"BLACKBIT_TOOL_OK"}',
                        },
                    }],
                }}],
            },
            "roundtrip": message_response("Tool result received."),
        }
        responses.update(overrides or {})
        self.environment["BB_TEST_RESPONSES"] = json.dumps(responses)
        result = subprocess.run(
            ["bash", str(ROOT / "test-blackbit-models.sh"), MODEL],
            env=self.environment,
            stdin=stdin,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertNotIn(DUMMY_KEY, result.stdout + result.stderr)
        return result

    def result_columns(self, result):
        row = next(line for line in result.stdout.splitlines() if line.startswith(MODEL))
        return row.split()[1:]

    def test_success_and_tool_roundtrip(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.result_columns(result), ["PASS"] * 4)
        request = json.loads((self.requests / "roundtrip.json").read_text(encoding="utf-8"))
        self.assertEqual(request["messages"][1]["reasoning_content"], "Offline fixture reasoning")
        self.assertEqual(request["messages"][2]["tool_call_id"], "offline_call")

    def test_different_nonempty_chat_is_pass_star(self):
        result = self.run_validator({"chat": message_response("Prefix BLACKBIT_CHAT_OK")})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.result_columns(result)[1], "PASS*")

    def test_empty_or_invalid_chat_fails(self):
        for content in (None, "", "   ", [], {"text": "BLACKBIT_CHAT_OK"}, 42):
            with self.subTest(content=content):
                result = self.run_validator({"chat": message_response(content)})
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.result_columns(result), ["PASS", "FAIL", "SKIP", "SKIP"])

    def test_http_200_error_body_fails(self):
        for stage in ("catalog", "chat", "tool", "roundtrip"):
            with self.subTest(stage=stage):
                result = self.run_validator({stage: {"error": {"code": "model_maintenance"}}})
                self.assertEqual(result.returncode, 1)
                self.assertIn("FAIL", self.result_columns(result))

    def test_error_takes_precedence_over_choices(self):
        for stage in ("chat", "roundtrip"):
            with self.subTest(stage=stage):
                response = message_response("BLACKBIT_CHAT_OK")
                response["error"] = {"code": "model_maintenance"}
                result = self.run_validator({stage: response})
                self.assertEqual(result.returncode, 1)

    def test_missing_choices_fails(self):
        result = self.run_validator({"chat": {"choices": []}})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.result_columns(result)[1], "FAIL")

    def test_array_catalog_is_supported(self):
        result = self.run_validator({"catalog": [{"id": MODEL}]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.result_columns(result), ["PASS"] * 4)

    def test_invalid_catalog_fails(self):
        for catalog in (None, "invalid", {"data": {}}, {"data": []}):
            with self.subTest(catalog=catalog):
                result = self.run_validator({"catalog": catalog})
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.result_columns(result), ["FAIL", "SKIP", "SKIP", "SKIP"])

    def test_empty_roundtrip_fails(self):
        result = self.run_validator({"roundtrip": message_response("")})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.result_columns(result)[3], "FAIL")

    def test_http_failure_fails(self):
        self.environment["BB_TEST_HTTP_ERROR"] = "chat"
        result = self.run_validator()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.result_columns(result)[1], "FAIL")

    def test_missing_key_never_prompts_on_a_terminal(self):
        self.environment["BLACKBIT_API_KEY"] = ""
        master, terminal = pty.openpty()
        try:
            result = self.run_validator(stdin=terminal)
        finally:
            os.close(master)
            os.close(terminal)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("BlackBit API key: ", result.stdout)
        self.assertIn("No API key loaded", result.stderr)


if __name__ == "__main__":
    if Path(sys.argv[0]).name == "curl":
        sys.exit(mock_curl())
    unittest.main()