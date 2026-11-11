#!/usr/bin/env python3
"""Fail if the X Wallet product identity is inconsistent.

Historical release records and technical compatibility identifiers are
allowlisted. Every other occurrence of the old display name is a failure.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The old display name and repository slug must not appear anywhere. Technical
# compatibility identifiers such as `bnb-wallet`, `bnb_wallet_gui` and
# `com.jackh0006.xwallet` are asserted separately and are intentionally kept.
FORBIDDEN = ("BNB Wallet", "BNB-Wallet-GUI")

SKIP_DIRS = {".git", "build", ".dart_tool", "node_modules", ".gradle", ".cxx", "dist", "ephemeral"}
SKIP_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".ico", ".bin", ".so", ".deb", ".lock",
    ".pyc", ".dill", ".snapshot", ".zip", ".gz",
}

REQUIRED = [
    ("pubspec.yaml", "description: \"X Wallet"),
    ("lib/l10n/app_en.arb", '"appTitle": "X Wallet"'),
    ("android/app/src/main/AndroidManifest.xml", 'android:label="X Wallet"'),
    ("linux/runner/my_application.cc", '"X Wallet"'),
    ("scripts/build-deb.sh", "Name=X Wallet"),
    ("scripts/build-deb.sh", "Package: x-wallet"),
    ("scripts/build-deb.sh", "Provides: bnb-wallet"),
    ("scripts/build-deb.sh", "Replaces: bnb-wallet"),
    ("scripts/build-deb.sh", "Conflicts: bnb-wallet"),
    ("README.md", "# X Wallet"),
]

TECHNICAL_COMPAT = [
    ("pubspec.yaml", "name: bnb_wallet_gui"),
    ("android/app/build.gradle.kts", 'applicationId = "com.jackh0006.xwallet"'),
    ("android/app/build.gradle.kts", 'namespace = "com.jackh0006.xwallet"'),
    ("lib/vault.dart", "BNBVL004"),
    ("lib/vault.dart", "BNBVL003"),
    ("lib/storage.dart", "bnb-wallet-vault.bnb"),
    ("lib/storage.dart", "device_secret_v2"),
]


def tracked_text_files() -> list[Path]:
    files = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if path.suffix.lower() in SKIP_SUFFIXES:
            continue
        try:
            path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        files.append(path)
    return files


def main() -> int:
    errors: list[str] = []
    for path in tracked_text_files():
        rel = str(path.relative_to(ROOT))
        if rel == "scripts/check_branding.py":
            continue
        text = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), 1):
            for needle in FORBIDDEN:
                if needle in line:
                    errors.append(
                        f"{rel}:{lineno}: forbidden old identity {needle!r}: "
                        f"{line.strip()[:120]}"
                    )

    # The user-visible .deb name is exactly "X Wallet": the version belongs in
    # the package Version field (and the About subtitle), never in Name=.
    build_deb = (ROOT / "scripts" / "build-deb.sh").read_text(encoding="utf-8")
    for line in build_deb.splitlines():
        stripped = line.strip()
        if stripped.startswith("Name=") and stripped not in {
            "Name=X Wallet",
            "Name=X Wallet (Cold)",
        }:
            errors.append(f"scripts/build-deb.sh: unexpected display name: {stripped}")
        if stripped.startswith("Name=") and any(ch.isdigit() for ch in stripped):
            errors.append(f"scripts/build-deb.sh: display name carries a version: {stripped}")
        if stripped.startswith("Description:") and not stripped.startswith(
            "Description: X Wallet —"
        ):
            errors.append(f"scripts/build-deb.sh: description must start with 'X Wallet —': {stripped}")

    settings = (ROOT / "lib" / "screens" / "settings_page.dart").read_text(
        encoding="utf-8"
    )
    if "'X Wallet $appVersion'" in settings:
        errors.append(
            "lib/screens/settings_page.dart: About title must be 'X Wallet' with "
            "the version on a separate line"
        )

    for rel, needle in REQUIRED:
        path = ROOT / rel
        if not path.is_file():
            errors.append(f"missing required file: {rel}")
            continue
        if needle not in path.read_text(encoding="utf-8"):
            errors.append(f"{rel}: missing required X Wallet marker: {needle}")

    for rel, needle in TECHNICAL_COMPAT:
        path = ROOT / rel
        if not path.is_file() or needle not in path.read_text(encoding="utf-8"):
            errors.append(f"{rel}: compatibility identifier changed or missing: {needle}")

    version = re.search(
        r"^version:\s*([^\s#]+)",
        (ROOT / "pubspec.yaml").read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    if not version or version.group(1) != "1.5.4+16":
        errors.append(f"pubspec version is not 1.5.4+16: {version.group(1) if version else 'missing'}")
    if not (ROOT / "docs" / "releases" / "1.5.4.md").is_file():
        errors.append("missing docs/releases/1.5.4.md")

    version_file = ROOT / "VERSION"
    if not version_file.is_file() or version_file.read_text(encoding="utf-8").strip() != version.group(1):
        errors.append("VERSION is missing or does not match pubspec.yaml")
    citation = (ROOT / "CITATION.cff").read_text(encoding="utf-8")
    if 'version: "1.5.4"' not in citation:
        errors.append("CITATION.cff version is not 1.5.3")

    app_version_file = ROOT / "lib" / "app_version.dart"
    if not app_version_file.is_file():
        errors.append("missing lib/app_version.dart")
    else:
        app_version_text = app_version_file.read_text(encoding="utf-8")
        match = re.search(
            r"^const String appVersion = '([^']+)';",
            app_version_text,
            re.MULTILINE,
        )
        expected = version.group(1).split("+", 1)[0] if version else ""
        if not match or match.group(1) != expected:
            errors.append("lib/app_version.dart does not match pubspec.yaml version")

    if errors:
        for error in errors:
            print(f"BRANDING FAIL: {error}", file=sys.stderr)
        return 1
    print("Branding: PASS (X Wallet; compatibility identifiers preserved)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
