#!/usr/bin/env python3
"""Negative tests for scripts/check_release_identity.py.

Each test starts from a valid copied evidence set, applies one defect, and
requires the validator to reject it. A validator that accepts any of these is
not fail-closed.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import check_release_identity as identity

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    "pubspec.yaml",
    "release/manifest.json",
    "release/evidence.json",
    "release/reproducibility.json",
    "release/package-smoke.json",
    "docs/SBOM.json",
    "docs/testing/test-inventory.json",
    "docs/releases/1.0.10.md",
    "docs/releases/1.1.0.md",
    "docs/releases/1.2.0.md",
    "docs/releases/1.3.0.md",
    "docs/releases/1.3.1.md",
]


class IdentityNegativeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = Path(tempfile.mkdtemp(prefix="bnb-identity-test-"))
        for name in FILES:
            source = ROOT / name
            target = self.temp / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    def tearDown(self) -> None:
        shutil.rmtree(self.temp, ignore_errors=True)

    def read(self, name: str) -> dict:
        return json.loads((self.temp / name).read_text(encoding="utf-8"))

    def write(self, name: str, data: dict | str) -> None:
        path = self.temp / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, str):
            path.write_text(data, encoding="utf-8")
        else:
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    def assert_rejected(self) -> None:
        errors = identity.validate(self.temp, None, skip_git=True)
        self.assertTrue(errors, "validator accepted an invalid identity")

    def test_valid_baseline_passes(self) -> None:
        self.assertEqual(identity.validate(self.temp, None, skip_git=True), [])

    def test_missing_required_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"] = [
            c for c in evidence["checks"] if c["id"] != "full-test-suite"
        ]
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_failed_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"][0]["exitCode"] = 1
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_duplicate_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"].append(dict(evidence["checks"][0]))
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_malformed_commit(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checksCommit"] = "not-a-commit"
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_missing_identity_note_when_commits_differ(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checksCommit"] = "1" * 40
        evidence.pop("identityNote", None)
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_stale_sbom_hash(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["sbom"]["sha256"] = "0" * 64
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_stale_inventory_hash(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["tests"]["sha256"] = "0" * 64
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_version_mismatch(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["version"] = "9.9.9+1"
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_missing_evidence(self) -> None:
        (self.temp / "release/evidence.json").unlink()
        self.assert_rejected()

    def test_invalid_json(self) -> None:
        (self.temp / "release/manifest.json").write_text("{not json", encoding="utf-8")
        self.assert_rejected()

    def test_artifact_hash_mismatch(self) -> None:
        artifact = self.temp / "artifact.deb"
        artifact.write_bytes(b"not the real package")
        self.assert_rejected_with_artifact(artifact)

    def assert_rejected_with_artifact(self, artifact: Path) -> None:
        errors = identity.validate(self.temp, artifact, skip_git=True)
        self.assertTrue(errors, "validator accepted a mismatched artifact hash")


class SquashMergeProvenanceTests(unittest.TestCase):
    """A squash merge may drop ancestry, but never wallet source changes."""

    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="bnb-squash-test-"))
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        (self.repo / "lib").mkdir()
        (self.repo / "lib" / "wallet.dart").write_text("// wallet\n")
        (self.repo / "docs").mkdir()
        (self.repo / "docs" / "note.md").write_text("one\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "tested")
        self.checks = self.rev("HEAD")
        (self.repo / "docs" / "note.md").write_text("two\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "docs")
        self.source = self.rev("HEAD")
        self.record = {
            "testedCommit": self.checks,
            "mergeCommit": self.source,
            "branchHead": self.source,
        }

    def tearDown(self) -> None:
        shutil.rmtree(self.repo, ignore_errors=True)

    def git(self, *args: str) -> None:
        subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True)

    def rev(self, ref: str) -> str:
        return subprocess.check_output(
            ["git", "rev-parse", ref], cwd=self.repo, text=True
        ).strip()

    def test_docs_only_squash_is_accepted(self) -> None:
        ok, reason = identity.squash_merge_ok(
            self.repo, self.checks, self.source, self.record
        )
        self.assertTrue(ok, reason)

    def test_wallet_source_change_is_rejected(self) -> None:
        (self.repo / "lib" / "wallet.dart").write_text("// changed\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "runtime")
        source = self.rev("HEAD")
        record = dict(self.record, mergeCommit=source)
        ok, _ = identity.squash_merge_ok(self.repo, self.checks, source, record)
        self.assertFalse(ok)

    def test_missing_squash_record_is_rejected(self) -> None:
        ok, _ = identity.squash_merge_ok(
            self.repo, self.checks, self.source, None
        )
        self.assertFalse(ok)



if __name__ == "__main__":
    unittest.main(verbosity=2)
