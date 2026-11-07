#!/usr/bin/env python3
"""Fail-closed release identity validator.

Checks that the manifest, evidence bundle, package, SBOM, test inventory,
reproducibility record, package-smoke record, and Git commits form one
documented chain. Missing values are failures, never passes.

Exit codes:
  0  identity is consistent
  1  identity is invalid or stale
  2  usage / unreadable input
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")

REQUIRED_CHECKS = [
    "static-analysis",
    "full-test-suite",
    "secret-scan",
    "cold-signature",
    "dependency-audit",
    "sbom",
    "test-inventory",
    "release-evidence",
    "license-inventory",
    "deb-build",
    "install-smoke",
    "reproducibility",
]


def sha256(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path: Path) -> tuple[dict | None, str | None]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except FileNotFoundError:
        return None, f"missing file: {path}"
    except json.JSONDecodeError as error:
        return None, f"invalid JSON in {path}: {error}"


def git(root: Path, *args: str) -> tuple[int, str]:
    result = subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True
    )
    return result.returncode, (result.stdout + result.stderr).strip()


def is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    if ancestor == descendant:
        return True
    code, _ = git(root, "merge-base", "--is-ancestor", ancestor, descendant)
    return code == 0


# Paths that may legitimately change between the commit where checks ran and
# the release commit without invalidating the checks. Wallet source, assets,
# tests, manifests, and lockfiles are deliberately absent.
SQUASH_ALLOWED_PATHS = {
    "README.md",
    "AGENTS.md",
    "IMPLEMENTATION_STATUS.md",
    ".github/workflows/verify.yml",
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
}


def squash_merge_ok(
    root: Path, checks: str, source: str, record: object
) -> tuple[bool, str | None]:
    """Accept a squash merge without ancestry when the squash is provably
    content-preserving and every differing path is documentation, release
    evidence, or release tooling."""
    if not isinstance(record, dict):
        return False, (
            f"checksCommit {checks[:8]} is not an ancestor of sourceCommit "
            f"{source[:8]} and evidence.squashMerge is missing"
        )
    if str(record.get("testedCommit") or "") != checks:
        return False, "evidence.squashMerge.testedCommit does not match checksCommit"
    if str(record.get("mergeCommit") or "") != source:
        return False, "evidence.squashMerge.mergeCommit does not match sourceCommit"
    branch_head = str(record.get("branchHead") or "")
    if branch_head:
        if not COMMIT.fullmatch(branch_head):
            return False, "evidence.squashMerge.branchHead is not a 40-hex commit"
        # The reviewed branch may be deleted and its objects unreachable after
        # the merge. Verify tree equality when the object is available; the
        # allowlisted diff below remains the authoritative check either way.
        code, _ = git(root, "cat-file", "-e", f"{branch_head}^{{commit}}")
        if code == 0:
            code, _ = git(root, "diff", "--quiet", branch_head, source)
            if code != 0:
                return False, (
                    "squash merge source tree differs from the reviewed branch head"
                )
    code, output = git(root, "diff", "--name-only", checks, source)
    if code != 0:
        return False, "cannot diff the tested commit against the release commit"
    changed = [line for line in output.splitlines() if line.strip()]
    disallowed = [
        path
        for path in changed
        if not (
            path.startswith("docs/")
            or path.startswith("release/")
            or path in SQUASH_ALLOWED_PATHS
        )
    ]
    if disallowed:
        return False, (
            "tested commit differs from the release commit in non-release paths: "
            + ", ".join(disallowed[:5])
        )
    return True, None


def version_from_pubspec(root: Path) -> str | None:
    try:
        text = (root / "pubspec.yaml").read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    match = re.search(r"^version:\s*([^\s#]+)", text, re.MULTILINE)
    return match.group(1) if match else None


def validate(root: Path, artifact: Path | None, skip_git: bool = False) -> list[str]:
    errors: list[str] = []

    manifest, error = load(root / "release" / "manifest.json")
    if error:
        return [error]
    evidence, error = load(root / "release" / "evidence.json")
    if error:
        return [error]
    reproducibility, error = load(root / "release" / "reproducibility.json")
    if error:
        errors.append(error)
    package_smoke, error = load(root / "release" / "package-smoke.json")
    if error:
        errors.append(error)
    inventory, error = load(root / "docs" / "testing" / "test-inventory.json")
    if error:
        errors.append(error)
    sbom, error = load(root / "docs" / "SBOM.json")
    if error:
        errors.append(error)

    assert manifest is not None and evidence is not None
    version = str(manifest.get("version") or "")
    pubspec_version = version_from_pubspec(root)
    if not version:
        errors.append("manifest.version is missing")
    if pubspec_version != version:
        errors.append(
            f"version mismatch: manifest {version!r} vs pubspec {pubspec_version!r}"
        )
    if evidence.get("version") and evidence["version"] != version:
        errors.append(
            f"evidence.version {evidence['version']!r} != manifest {version!r}"
        )
    release_note = root / "docs" / "releases" / f"{version.split('+', 1)[0]}.md"
    if not release_note.is_file():
        errors.append(f"missing release evidence record: {release_note}")

    source = str(evidence.get("sourceCommit") or "")
    checks = str(evidence.get("checksCommit") or "")
    artifact_source = str(evidence.get("artifactSourceCommit") or "")
    for label, value in (
        ("sourceCommit", source),
        ("checksCommit", checks),
        ("artifactSourceCommit", artifact_source),
    ):
        if not COMMIT.fullmatch(value):
            errors.append(f"{label} is not a 40-hex commit: {value!r}")

    if source and checks and not skip_git:
        if not is_ancestor(root, checks, source):
            ok, reason = squash_merge_ok(
                root, checks, source, evidence.get("squashMerge")
            )
            if not ok and reason:
                errors.append(reason)
        code, head = git(root, "rev-parse", "HEAD")
        if code != 0:
            errors.append("cannot read Git HEAD")
        elif not is_ancestor(root, source, head):
            errors.append(
                f"sourceCommit {source[:8]} is not an ancestor of HEAD {head[:8]}"
            )
        if artifact_source and not is_ancestor(root, artifact_source, checks):
            errors.append(
                f"artifactSourceCommit {artifact_source[:8]} is not an ancestor of checksCommit {checks[:8]}"
            )
        dirty, _ = git(root, "status", "--porcelain")
        if dirty:
            errors.append("working tree is dirty; release identity cannot be clean")

    check_rows = evidence.get("checks") or []
    if not isinstance(check_rows, list) or not check_rows:
        errors.append("evidence.checks is missing or empty")
        check_rows = []
    ids: list[str] = []
    for row in check_rows:
        if not isinstance(row, dict):
            errors.append("evidence.checks contains a non-object")
            continue
        check_id = str(row.get("id") or "")
        ids.append(check_id)
        if row.get("exitCode") != 0:
            errors.append(f"check {check_id!r} did not exit 0")
        if row.get("required") is not True:
            errors.append(f"check {check_id!r} is not marked required")
        if not COMMIT.fullmatch(str(row.get("commit") or "")):
            errors.append(f"check {check_id!r} has no valid commit")
    duplicates = sorted({item for item in ids if ids.count(item) > 1})
    if duplicates:
        errors.append(f"duplicate check ids: {', '.join(duplicates)}")
    for check_id in REQUIRED_CHECKS:
        if check_id not in ids:
            errors.append(f"missing required check: {check_id}")

    status = str(evidence.get("status") or "")
    if status not in {
        "BLOCKED",
        "FAILED",
        "PARTIALLY VERIFIED",
        "VERIFIED FOR TESTING",
        "RELEASE APPROVED",
    }:
        errors.append(f"invalid evidence status: {status!r}")

    sbom_manifest = (manifest.get("sbom") or {}).get("sha256")
    actual_sbom = sha256(root / "docs" / "SBOM.json")
    if not sbom_manifest or sbom_manifest != actual_sbom:
        errors.append("manifest SBOM hash does not match docs/SBOM.json")
    inventory_manifest = (manifest.get("tests") or {}).get("sha256")
    actual_inventory = sha256(root / "docs" / "testing" / "test-inventory.json")
    if not inventory_manifest or inventory_manifest != actual_inventory:
        errors.append("manifest test-inventory hash does not match the file")
    if inventory and inventory.get("fileCount") != (manifest.get("tests") or {}).get(
        "recordedFiles"
    ):
        errors.append("test inventory fileCount does not match the manifest")

    artifact_hash = str(evidence.get("artifactSha256") or "")
    if not SHA256.fullmatch(artifact_hash):
        errors.append("evidence.artifactSha256 is missing or malformed")
    if artifact is not None:
        actual = sha256(artifact)
        if actual != artifact_hash:
            errors.append(
                f"artifact hash mismatch: expected {artifact_hash}, got {actual}"
            )

    if reproducibility:
        if reproducibility.get("status") not in {"PASS_FIXED_PATH", "PASS_INDEPENDENT"}:
            errors.append("reproducibility status is not a recognised pass")
        if not SHA256.fullmatch(str(reproducibility.get("archiveSha256") or "")):
            errors.append("reproducibility archiveSha256 is missing or malformed")
        repro_commit = str(reproducibility.get("sourceCommit") or "")
        if not COMMIT.fullmatch(repro_commit):
            errors.append("reproducibility sourceCommit is missing or malformed")
        elif not skip_git and not is_ancestor(root, repro_commit, checks):
            errors.append(
                "reproducibility sourceCommit is not an ancestor of checksCommit"
            )

    if package_smoke:
        if package_smoke.get("status") != "PASS":
            errors.append("package-smoke status is not PASS")
        if not isinstance(package_smoke.get("runId"), int):
            errors.append("package-smoke runId is missing")

    if sbom:
        component = (sbom.get("metadata") or {}).get("component") or {}
        sbom_version = str(component.get("version") or "")
        if sbom_version != version.split("+", 1)[0]:
            errors.append(
                f"SBOM version {sbom_version!r} does not match {version.split('+', 1)[0]!r}"
            )

    if evidence.get("sourceCommit") != evidence.get("checksCommit"):
        if not evidence.get("identityNote"):
            errors.append(
                "checksCommit and sourceCommit differ without an identityNote"
            )
    if artifact_source and checks and artifact_source != checks:
        errors.append("artifactSourceCommit must equal checksCommit for this release")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=None)
    parser.add_argument("--artifact", default=None)
    parser.add_argument("--skip-git", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[1]
    artifact = Path(args.artifact).resolve() if args.artifact else None
    errors = validate(root, artifact, skip_git=args.skip_git)
    if errors:
        for error in errors:
            print(f"IDENTITY FAIL: {error}", file=sys.stderr)
        return 1
    if not args.quiet:
        print("Release identity: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
