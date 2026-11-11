#!/usr/bin/env python3
"""Generate the human-readable status document and the README status block.

Every number and status comes from the machine-readable manifest, the test
inventory, and the recorded check/artifact files.  Nothing is inferred from
prose, and an absent result is rendered as NOT TESTED — never as a pass.

Usage:
  python3 scripts/generate_docs.py            # write generated documents
  python3 scripts/generate_docs.py --check    # fail if they are stale
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "release" / "manifest.json"
INVENTORY = ROOT / "docs" / "testing" / "test-inventory.json"
COMPATIBILITY = ROOT / "release" / "compatibility.json"
BENCHMARKS = ROOT / "release" / "benchmarks.json"
OUTPUT = ROOT / "docs" / "GENERATED_STATUS.md"
README = ROOT / "README.md"
BEGIN = "<!-- BEGIN GENERATED:status -->"
END = "<!-- END GENERATED:status -->"


EVIDENCE = ROOT / "release" / "evidence.json"


def load(path: Path, default=None):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as error:
        raise SystemExit(f"error: invalid JSON in {path}: {error}")


def head_commit() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def candidate_head() -> str:
    """PR merge commits have two parents; the second is the actual PR head.

    Evidence must be compared against the code the PR introduces, not against
    unrelated base-branch changes that happen to be in the merge commit.
    """
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


def evidence_only_ok(source_commit: str) -> bool:
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
        or path.startswith("docs/")
        or path.startswith("release/")
        for path in changed
        if path
    )


def gate_summary(manifest: dict) -> dict:
    bundle = load(EVIDENCE, None)
    if bundle and evidence_only_ok(bundle.get("sourceCommit", "")):
        return {
            "status": bundle.get("status", "INCOMPLETE"),
            "problems": bundle.get("problems", []),
            "checks": bundle.get("checks", []),
            "artifacts": bundle.get("artifacts", []),
        }
    return {
        "status": "INCOMPLETE",
        "problems": ["no committed evidence bundle for this source commit"],
        "checks": [],
        "artifacts": [],
    }


def short(commit: str | None) -> str:
    return (commit or "")[:12] or "unknown"


def table(headers: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |"]
    lines.append("|" + "|".join(["---"] * len(headers)) + "|")
    for row in rows:
        lines.append("| " + " | ".join(str(cell) for cell in row) + " |")
    return "\n".join(lines)


def build() -> str:
    manifest = load(MANIFEST)
    if manifest is None:
        raise SystemExit("error: release/manifest.json is missing")
    inventory = load(INVENTORY, {"fileCount": 0, "testCount": 0, "kdfFileCount": 0, "files": []})
    compatibility = load(COMPATIBILITY, {"platforms": []})
    benchmarks = load(BENCHMARKS, {"machine": {}, "benchmarks": []})
    gate = gate_summary(manifest)

    lines = [
        "# Generated release status",
        "",
        "**This file is generated. Do not edit it by hand.**",
        "Regenerate with `python3 scripts/generate_docs.py`.",
        "",
        "## Release status",
        "",
        f"- Version: `{manifest['version']}`",
        "- Exact source commit: recorded in `release/evidence.json` when a "
        "release bundle is published. It is deliberately not embedded here, "
        "because a document cannot contain the hash of the commit that "
        "contains it.",
        f"- Status: **{gate.get('status', 'INCOMPLETE')}**",
        "",
        "Status meanings: `VERIFIED` requires every source and release check; "
        "`PARTIALLY VERIFIED` means source checks passed but a release-only "
        "check is missing; `INCOMPLETE` means a required result is absent; "
        "`FAILED` means a recorded check or artifact failed.",
        "",
        "## Source and toolchain",
        "",
        table(
            ["Item", "Value"],
            [
                ["Flutter", manifest["toolchain"]["flutter"]],
                ["Dart", manifest["toolchain"]["dart"]],
                ["pubspec.lock SHA-256", manifest["lockfiles"]["pubspec.lock"] or "missing"],
                [
                    "verification/package-lock.json SHA-256",
                    manifest["lockfiles"]["verification/package-lock.json"] or "missing",
                ],
                ["SBOM SHA-256", manifest["sbom"]["sha256"] or "missing"],
            ],
        ),
        "",
        "## Test inventory",
        "",
        f"- Test files: **{inventory['fileCount']}**",
        f"- Test/testWidgets declarations: **{inventory['testCount']}**",
        f"- Real-KDF files: **{inventory['kdfFileCount']}**",
        f"- Inventory: `{inventory.get('path', 'docs/testing/test-inventory.json')}`",
        "",
        "A declaration count is not a pass count. Pass/fail evidence comes only "
        "from a committed evidence bundle for this exact commit.",
        "",
        "## Recorded checks for this commit",
        "",
    ]

    checks = gate.get("checks", [])
    if checks:
        lines.append(
            table(
                ["Check", "Exit", "Duration (s)", "Required", "Log SHA-256"],
                [
                    [
                        item.get("id", ""),
                        item.get("exitCode"),
                        item.get("durationSeconds"),
                        "yes" if item.get("required", True) else "no",
                        (item.get("logSha256") or "—")[:16],
                    ]
                    for item in checks
                ],
            )
        )
    else:
        lines.append(
            "No committed evidence bundle names this commit. "
            "**NOT TESTED / INCOMPLETE.**"
        )

    lines += ["", "## Artifacts", ""]
    artifacts = gate.get("artifacts", [])
    if artifacts:
        lines.append(
            table(
                ["Artifact", "SHA-256", "Signed", "Signature verified"],
                [
                    [
                        artifact.get("path", ""),
                        artifact.get("sha256", ""),
                        "yes" if artifact.get("signed") else "no",
                        "yes" if artifact.get("signatureVerified") else "NO",
                    ]
                    for artifact in artifacts
                ],
            )
        )
    else:
        lines.append("No release artifact is recorded for this commit. **NOT TESTED.**")

    signing = manifest.get("androidSigning", {})
    lines += [
        "",
        "## Android signing incident",
        "",
        f"- Incident status: `{signing.get('incidentStatus', 'NOT RECORDED')}`",
        f"- Rotation verified: **{'yes' if signing.get('rotationVerified') else 'NO'}**",
        f"- Denylisted certificates: {signing.get('denylistedFingerprints', 0)}",
        "",
        "An Android artifact is never releasable while rotation is unverified or "
        "the denylist is empty. See "
        "[the incident record](security/INCIDENT_2026-11-KEYSTORE.md).",
        "",
        "## Platform compatibility",
        "",
    ]
    platforms = compatibility.get("platforms", [])
    if platforms:
        lines.append(
            table(
                ["Platform", "Arch", "Package", "Build", "Install", "Functional", "Status"],
                [
                    [
                        item.get("platform", ""),
                        item.get("arch", ""),
                        item.get("package", ""),
                        item.get("build", "NOT TESTED"),
                        item.get("install", "NOT TESTED"),
                        item.get("functional", "NOT TESTED"),
                        item.get("status", "NOT TESTED"),
                    ]
                    for item in platforms
                ],
            )
        )
    else:
        lines.append(
            "No platform result is recorded. **NOT TESTED** — do not infer support "
            "from the source building."
        )

    lines += ["", "## Performance", ""]
    machine = benchmarks.get("machine", {})
    if machine:
        lines.append(
            "Measured on: "
            + ", ".join(f"{key}={value}" for key, value in sorted(machine.items()))
        )
        lines.append("")
    rows = benchmarks.get("benchmarks", [])
    if rows:
        lines.append(
            table(
                ["Benchmark", "Value", "Unit", "Status", "Evidence"],
                [
                    [
                        item.get("name", ""),
                        item.get("value")
                        if item.get("value") is not None
                        else "—",
                        item.get("unit", ""),
                        item.get("status", "NOT TESTED"),
                        item.get("evidence", ""),
                    ]
                    for item in rows
                ],
            )
        )
    else:
        lines.append("No performance measurement is recorded. **NOT TESTED.**")

    lines += [
        "",
        "## Honest limitations",
        "",
        "- This project is self-assessed. It has **not** been independently audited.",
        "- No automated test, signature, or score can guarantee the safety of funds.",
        "- A compromised operating system, malware, or a stolen unlocked session can "
        "defeat a local hot wallet.",
        "- Android releases are blocked until the historical signing key is rotated "
        "and denylisted.",
        f"- Full limitations: [{manifest.get('knownLimitations', 'docs/KNOWN_LIMITATIONS.md')}]"
        f"({manifest.get('knownLimitations', 'docs/KNOWN_LIMITATIONS.md')})",
        "",
        "## Evidence files",
        "",
        f"- Manifest: `release/manifest.json`",
        f"- Checks: `release/checks.json`",
        f"- Artifacts: `release/artifacts.json`",
        f"- Test inventory: `docs/testing/test-inventory.json`",
        f"- SBOM: `docs/SBOM.json`",
        "",
    ]
    if gate.get("problems"):
        lines += ["## Open gate problems", ""]
        lines += [f"- {problem}" for problem in gate["problems"]]
        lines.append("")
    return "\n".join(lines)


def readme_block() -> str:
    manifest = load(MANIFEST, {})
    inventory = load(INVENTORY, {})
    version = manifest.get("version", "unknown")
    files = inventory.get("fileCount", 0)
    declarations = inventory.get("testCount", 0)
    return "\n".join(
        [
            BEGIN,
            f"> **X Wallet {version}** · {files} test files · "
            f"{declarations} test declarations",
            ">",
            "> [Download the latest release]"
            "(https://github.com/jackh0006/X-Wallet/releases/latest) · "
            "[Full test evidence](docs/TEST_EVIDENCE.md) · "
            "[Release status](docs/GENERATED_STATUS.md)",
            END,
        ]
    )


def updated_readme(text: str) -> str:
    block = readme_block()
    if BEGIN in text and END in text:
        before = text.split(BEGIN, 1)[0]
        after = text.split(END, 1)[1]
        return before + block + after
    marker = "> Important: this project is self-assessed"
    if marker in text:
        index = text.index(marker)
        return text[:index] + block + "\n\n" + text[index:]
    return text + "\n\n" + block + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    status = build()
    readme = updated_readme(README.read_text(encoding="utf-8"))

    if args.check:
        stale = []
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != status:
            stale.append(str(OUTPUT.relative_to(ROOT)))
        if README.read_text(encoding="utf-8") != readme:
            stale.append("README.md")
        if stale:
            print(
                "error: generated documentation is stale: " + ", ".join(stale),
                file=sys.stderr,
            )
            return 1
        print("generated documentation: current")
        return 0

    OUTPUT.write_text(status, encoding="utf-8")
    README.write_text(readme, encoding="utf-8")
    print(f"generated documentation: wrote {OUTPUT.relative_to(ROOT)} and README.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
