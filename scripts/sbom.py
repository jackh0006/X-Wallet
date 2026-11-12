#!/usr/bin/env python3
"""Generate a deterministic CycloneDX-style inventory for locked dependencies.

The wallet is built from pubspec.lock and its independent cold-signing oracle
is built from verification/package-lock.json.  Both lockfiles are part of the
release boundary, so neither may be omitted from the SBOM.

Usage: python3 scripts/sbom.py [--lock pubspec.lock]
       [--npm-lock verification/package-lock.json] [--out docs/SBOM.json]

Deterministic: no timestamps, no random serial numbers — the same lock file
always yields the same SBOM bytes, so two builds can be compared directly.
"""
import hashlib
import json
import os
import re
import sys
import uuid

DEFAULT_LOCK = "pubspec.lock"
DEFAULT_NPM_LOCK = "verification/package-lock.json"
DEFAULT_OUT = "docs/SBOM.json"
DEFAULT_PUBSPEC = "pubspec.yaml"


def parse_lock(text: str) -> list:
    """Minimal block-style parser for pubspec.lock: every two-space-indented
    key under `packages:` is one entry; we only keep entries that carry a
    resolved version (top-level keys like `sdks:` are dropped)."""
    packages: list = []
    current = None
    for line in text.splitlines():
        top = re.match(r"^  ([a-zA-Z0-9_]+):$", line)
        if top:
            current = {"name": top.group(1)}
            packages.append(current)
            continue
        if current is None:
            continue
        dependency = re.match(r"^    dependency: (.+)$", line)
        version = re.match(r"^    version: \"?([0-9][^\"?]*)\"?", line)
        sha256 = re.match(r"^      sha256: \"?([0-9a-f]{64})\"?", line)
        url = re.match(r"^      url: \"?([^\"]+)\"?", line)
        if dependency:
            current["dependency"] = dependency.group(1).strip().strip("'\"")
        if version:
            current["version"] = version.group(1).strip().strip("'\"")
        if sha256:
            current["sha256"] = sha256.group(1)
        if url:
            current["source"] = url.group(1)
    return [p for p in packages if p.get("version") and p.get("dependency")]


def component(entry: dict) -> dict:
    out = {
        "type": "library",
        "name": entry["name"],
        "version": entry["version"],
        "purl": f"pkg:dart/{entry['name']}@{entry['version']}",
        "scope": "required",
        "properties": [
            {"name": "dependency_class", "value": entry.get("dependency", "")},
            {"name": "download_source", "value": entry.get("source", "")},
        ],
    }
    if entry.get("sha256"):
        out["hashes"] = [{"alg": "SHA-256", "content": entry["sha256"]}]
    return out


def npm_components(path: str) -> tuple[list, int]:
    """Read npm lockfile v3 packages without consulting the network."""
    try:
        with open(path, encoding="utf-8") as handle:
            lock = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read npm lock {path}: {error}") from error

    packages = lock.get("packages")
    if not isinstance(packages, dict) or not isinstance(packages.get(""), dict):
        raise ValueError(f"npm lock {path} has no lockfile-v3 packages map")
    root = packages[""]
    direct = set(root.get("dependencies", {}))
    out = []
    for package_path, entry in packages.items():
        if not package_path.startswith("node_modules/"):
            continue
        name = package_path.removeprefix("node_modules/")
        version = entry.get("version")
        if not isinstance(version, str):
            raise ValueError(f"npm lock entry {package_path} has no version")
        item = {
            "type": "library",
            "name": name,
            "version": version,
            "purl": f"pkg:npm/{name}@{version}",
            "scope": "required",
            "properties": [
                {
                    "name": "dependency_class",
                    "value": "direct verification" if name in direct else "transitive verification",
                },
                {"name": "download_source", "value": entry.get("resolved", "")},
            ],
        }
        integrity = entry.get("integrity")
        if isinstance(integrity, str) and "-" in integrity:
            algorithm, encoded = integrity.split("-", 1)
            algorithm = algorithm.upper()
            # npm records a base64 SRI digest; CycloneDX records hexadecimal.
            import base64
            try:
                item["hashes"] = [{"alg": algorithm, "content": base64.b64decode(encoded).hex()}]
            except ValueError:
                raise ValueError(f"invalid integrity digest for npm package {name}")
        if isinstance(entry.get("license"), str):
            item["licenses"] = [{"license": {"name": entry["license"]}}]
        out.append(item)
    return out, len(direct)


def vendored_components() -> list:
    """Components compiled into the app but not resolved through pubspec.lock."""
    return [
        {
            "type": "library",
            "name": "argon2",
            "version": "reference-20190702",
            "purl": "pkg:generic/argon2@reference-20190702",
            "scope": "required",
            "licenses": [{"license": {"name": "CC0-1.0 OR Apache-2.0"}}],
            "properties": [
                {
                    "name": "vendored_path",
                    "value": "android/app/src/main/cpp/argon2",
                },
                {
                    "name": "purpose",
                    "value": "Native Argon2id KDF for Android (offline, no network)",
                },
            ],
        }
    ]


def package_version(path: str) -> str:
    """Read the release version without requiring a YAML dependency."""
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                match = re.match(r"^version:\s*([0-9][0-9A-Za-z.+-]*)\s*$", line)
                if match:
                    return match.group(1).split("+", 1)[0]
    except OSError as error:
        raise ValueError(f"cannot read {path}: {error}") from error
    raise ValueError(f"no package version in {path}")


def main() -> int:
    args = sys.argv[1:]
    lock_path = DEFAULT_LOCK
    npm_lock_path = DEFAULT_NPM_LOCK
    out_path = DEFAULT_OUT
    if "--lock" in args:
        lock_path = args[args.index("--lock") + 1]
    if "--out" in args:
        out_path = args[args.index("--out") + 1]
    if "--npm-lock" in args:
        npm_lock_path = args[args.index("--npm-lock") + 1]

    try:
        with open(lock_path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        print(f"FAIL cannot read {lock_path}: {error}")
        return 1

    packages = parse_lock(text)
    if not packages:
        print("FAIL no packages resolved in the lock file — run flutter pub get")
        return 1
    try:
        npm, npm_direct = npm_components(npm_lock_path)
    except ValueError as error:
        print(f"FAIL {error}")
        return 1
    try:
        version = package_version(DEFAULT_PUBSPEC)
    except ValueError as error:
        print(f"FAIL {error}")
        return 1

    direct = [p for p in packages if "direct" in p.get("dependency", "")]
    components = sorted(
        [component(p) for p in packages] + npm + vendored_components(),
        key=lambda item: item["purl"],
    )
    # CycloneDX requires a serialNumber URN. Derive a UUIDv5 from the component
    # list so the SBOM stays deterministic (same lockfiles -> same bytes) while
    # remaining a valid URN for consumers such as actions/attest-sbom.
    digest = hashlib.sha256(
        json.dumps(components, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    serial_number = uuid.uuid5(
        uuid.NAMESPACE_URL, f"https://github.com/jackh0006/X-Wallet/sbom/{digest}"
    )
    sbom = {
        "$schema": "http://cyclonedx.org/schema/bom-1.5.schema.json",
        "bomFormat": "CycloneDX",
        "serialNumber": f"urn:uuid:{serial_number}",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "component": {
                "type": "application",
                "name": "bnb_wallet_gui",
                "version": version,
                "description": "Local, non-custodial multi-chain wallet (deb).",
            },
            "properties": [
                {"name": "generated_from", "value": f"{lock_path}, {npm_lock_path}"},
                {"name": "deterministic", "value": "no-timestamp -- same lock, same bytes"},
            ],
        },
        "components": components,
    }

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(sbom, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(
        f"Wrote {out_path}: {len(packages)} packages "
        f"({len(direct)} direct, {len(packages) - len(direct)} transitive Dart; "
        f"{len(npm)} npm, {npm_direct} direct)"
    )
    source_epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if source_epoch:
        print("(SOURCE_DATE_EPOCH noted but SBOM is timestamp-free by design)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
