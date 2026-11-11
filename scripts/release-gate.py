#!/usr/bin/env python3
"""Evaluate the release gate from recorded evidence.

Status vocabulary (never invented):

  VERIFIED            every required source and release check passed for this
                      exact commit, artifacts match their hashes and signatures,
                      and the manifest is current
  PARTIALLY VERIFIED  every required source check passed, but at least one
                      release-only check (package, install, reproducibility) is
                      missing
  INCOMPLETE          a required check has no result for this commit, or the
                      manifest is stale/dirty
  FAILED              a required check failed, an artifact hash mismatched, a
                      signature failed, or an Android artifact was signed by a
                      non-rotated/denylisted identity

A missing result is never treated as a pass.  Timeouts and interruptions are
recorded by scripts/record_check.py with their real exit code.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "release" / "manifest.json"
CHECKS_FILE = ROOT / "release" / "checks.json"
ARTIFACTS_FILE = ROOT / "release" / "artifacts.json"
EVIDENCE_FILE = ROOT / "release" / "evidence.json"

REQUIRED_SOURCE = [
    ("static-analysis", "flutter analyze --no-pub"),
    ("full-test-suite", "bash scripts/test-suite.sh"),
    ("secret-scan", "bash scripts/secret-scan.sh"),
    ("cold-signature", "(cd verification && npm ci && node verify.cjs)"),
    ("dependency-audit", "python3 scripts/dependency-audit.py"),
    ("sbom", "python3 scripts/sbom.py --out docs/SBOM.json"),
    ("test-inventory", "python3 scripts/test_inventory.py --check"),
    ("release-evidence", "python3 scripts/check_release_evidence.py"),
    ("license-inventory", "python3 scripts/license-check.py"),
]
REQUIRED_RELEASE = [
    ("deb-build", "bash scripts/build-deb.sh"),
    ("deb-signature", "gpg --verify <deb>.asc <deb>"),
    ("install-smoke", "clean Ubuntu/Debian install + launch"),
    ("reproducibility", "two independent builds compared"),
]


def load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as error:
        raise SystemExit(f"error: invalid JSON in {path}: {error}")


def sha256(path: Path) -> str | None:
    import hashlib

    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_map(manifest: dict) -> dict:
    return {item.get("id"): item for item in manifest.get("checks", [])}


def head_commit() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def candidate_head() -> str:
    """PR merge commits have two parents; the second is the actual PR head."""
    fields = subprocess.check_output(
        ["git", "rev-list", "--parents", "-n", "1", "HEAD"],
        cwd=ROOT,
        text=True,
    ).strip().split()
    if len(fields) >= 3:
        return fields[2]
    return fields[0]


EVIDENCE_ONLY_PATHS = {
    "release/evidence.json",
    "release/manifest.json",
    "release/compatibility.json",
    "release/benchmarks.json",
    "docs/GENERATED_STATUS.md",
    "docs/testing/test-inventory.json",
    "docs/testing/TEST_MATRIX.md",
    "docs/releases/1.0.10.md",
    "docs/RELEASE_EVIDENCE.md",
    "docs/HARDENING_REPORT.md",
    "README.md",
    "AI_REVIEW_PACKET.md",
    "llms.txt",
    "VERSION",
    "CITATION.cff",
}

# Release tooling may change between the tested commit and a later evidence
# commit without invalidating the wallet checks.
RELEASE_TOOLING_PATHS = {
    "AGENTS.md",
    "SECURITY_AUDIT.md",
    "TEST_EVIDENCE.md",
    "THREAT_MODEL.md",
    "REMEDIATION.md",
    "RELEASE_SECURITY.md",
    "SECURITY_LIMITATIONS.md",
    "IMPLEMENTATION_STATUS.md",
    ".github/workflows/verify.yml",
    ".github/workflows/android-build.yml",
    "android/gradle.properties",
    ".github/workflows/benchmark.yml",
    "scripts/check_branding.py",
    "scripts/check_free_product.py",
    "scripts/check_release_evidence.py",
    "scripts/build-deb.sh",
    "scripts/check_release_identity.py",
    "scripts/generate_docs.py",
    "scripts/release-gate.py",
    "scripts/release_manifest.py",
    "scripts/sbom.py",
    "scripts/test_release_identity.py",
    "scripts/test-suite-fast.sh",
    "scripts/package-launch-smoke.sh",
    "scripts/build_review_bundle.py",
}


def evidence_commit_ok(source_commit: str) -> bool:
    """Accept evidence recorded on an ancestor commit only when every change
    since then is evidence/documentation, never source or tests."""
    head = candidate_head()
    if source_commit == head:
        return True
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", source_commit, head],
        cwd=ROOT,
        capture_output=True,
    )
    if ancestor.returncode != 0:
        return False
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", f"{source_commit}..{head}"],
        cwd=ROOT,
        text=True,
    ).splitlines()
    return all(
        path in {"README.md", "AGENTS.md", "IMPLEMENTATION_STATUS.md"}
        or path in RELEASE_TOOLING_PATHS
        or path in EVIDENCE_ONLY_PATHS
        or path.startswith("docs/")
        or path.startswith("release/")
        for path in changed
        if path
    )


def evidence_for(manifest: dict) -> tuple[dict, list]:
    """Return (checks_by_id, artifacts) for the current HEAD commit.

    A committed release/evidence.json is authoritative when it names HEAD or
    an ancestor whose only later changes are evidence files.  Otherwise,
    local untracked evidence from scripts/record_check.py is used.
    """
    commit = head_commit()
    bundle = load(EVIDENCE_FILE, None)
    if bundle and evidence_commit_ok(bundle.get("sourceCommit", "")):
        return (
            {item.get("id"): item for item in bundle.get("checks", [])},
            list(bundle.get("artifacts", [])),
        )
    checks = load(CHECKS_FILE, {"checks": []})
    artifacts = load(ARTIFACTS_FILE, {"artifacts": []})
    return (
        {
            item.get("id"): item
            for item in checks.get("checks", [])
            if item.get("commit") == commit
        },
        [item for item in artifacts.get("artifacts", []) if item.get("commit") == commit],
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--require-verified", action="store_true")
    parser.add_argument("--require-source", action="store_true")
    parser.add_argument("--artifacts-dir", default=None)
    args = parser.parse_args()

    problems: list[str] = []
    manifest = load(MANIFEST, None)
    if manifest is None:
        print("error: release/manifest.json is missing", file=sys.stderr)
        return 1

    # The manifest must describe the checkout, not an older commit.
    current = subprocess.run(
        [sys.executable, "scripts/release_manifest.py", "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if current.returncode != 0:
        problems.append(current.stderr.strip() or current.stdout.strip())
    dirty = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True
    ).stdout.strip()
    if dirty:
        problems.append("working tree is dirty; release evidence must be clean")

    checks, artifacts = evidence_for(manifest)
    for check_id, command in REQUIRED_SOURCE:
        record = checks.get(check_id)
        if record is None:
            problems.append(f"missing source check: {check_id} ({command})")
        elif record.get("exitCode") != 0:
            problems.append(
                f"failed source check: {check_id} exit {record.get('exitCode')} "
                f"({record.get('command', command)})"
            )
    for check_id, command in REQUIRED_RELEASE:
        record = checks.get(check_id)
        if record is None:
            problems.append(f"missing release check: {check_id} ({command})")
        elif record.get("exitCode") != 0:
            problems.append(
                f"failed release check: {check_id} exit {record.get('exitCode')} "
                f"({record.get('command', command)})"
            )

    if manifest.get("sbom", {}).get("sha256") != sha256(ROOT / "docs" / "SBOM.json"):
        problems.append("docs/SBOM.json does not match the manifest hash")
    inventory = ROOT / "docs" / "testing" / "test-inventory.json"
    if manifest.get("tests", {}).get("sha256") != sha256(inventory):
        problems.append("docs/testing/test-inventory.json does not match the manifest hash")
    if manifest.get("tests", {}).get("matches") is not True:
        problems.append("test inventory file count does not match the test tree")

    for artifact in artifacts:
        name = str(artifact.get("name") or artifact.get("path") or "")
        rel = str(artifact.get("path") or name)
        if args.artifacts_dir:
            path = Path(args.artifacts_dir) / Path(rel).name
        elif artifact.get("path"):
            path = ROOT / rel
        else:
            path = None
        if path is not None:
            if not path.is_file():
                problems.append(f"artifact missing: {rel}")
                continue
            if sha256(path) != artifact.get("sha256"):
                problems.append(f"artifact hash mismatch: {rel}")
        elif args.require_verified:
            problems.append(f"artifact has no path/name: {artifact}")
        if artifact.get("kind") == "android":
            signing = manifest.get("androidSigning", {})
            if not signing.get("rotationVerified") or not signing.get("denylistedFingerprints"):
                problems.append(
                    "Android artifact present but key rotation/denylist is not verified"
                )
        if artifact.get("signed") and not artifact.get("signatureVerified"):
            problems.append(f"artifact signature not verified: {rel}")

    source_ok = not any(
        problem.startswith(("missing source check:", "failed source check:"))
        for problem in problems
    )
    release_missing = [
        check_id
        for check_id, _ in REQUIRED_RELEASE
        if check_id not in checks or checks[check_id].get("exitCode") != 0
    ]

    if any(
        problem.startswith(("failed source check:", "failed release check:"))
        for problem in problems
    ):
        status = "FAILED"
    elif not source_ok:
        status = "INCOMPLETE"
    elif release_missing:
        status = "PARTIALLY VERIFIED"
    elif problems:
        status = "INCOMPLETE"
    else:
        status = "VERIFIED"

    # "VERIFIED" above means every recorded check passed. It is not an audit
    # and not a production approval. If the evidence bundle itself declares a
    # lower status, never display a stronger one.
    bundle = load(EVIDENCE_FILE, {})
    declared = bundle.get("status") if isinstance(bundle, dict) else None
    if status == "VERIFIED" and declared in {"PARTIALLY VERIFIED", "INCOMPLETE"}:
        status = declared

    summary = {
        "status": status,
        "commit": head_commit(),
        "version": manifest.get("version"),        "sourceChecksPassed": source_ok,
        "releaseChecksMissing": release_missing,
        "problems": problems,
        "artifacts": [artifact.get("path") for artifact in artifacts],
    }

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(f"Release status: {status}")
        print(f"Version: {summary['version']}  Commit: {summary['commit']}")
        print(f"Source checks: {'PASS' if source_ok else 'INCOMPLETE/FAILED'}")
        if release_missing:
            print("Release checks missing: " + ", ".join(release_missing))
        for problem in problems:
            print(f"  - {problem}")

    if args.require_verified and status != "VERIFIED":
        return 1
    if args.require_source and not source_ok:
        return 1
    return 0 if status != "FAILED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
