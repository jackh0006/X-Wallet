# X Wallet Threat Model

Detailed model: [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).

## Assets

Recovery phrase, private keys, vault password, signed transactions, spending
policy, balances, recipients, activity history, release signing keys.

## Trust boundaries

1. User and device.
2. Local vault and app sandbox.
3. RPC/explorer network.
4. Release build and signing pipeline.
5. Android system and file picker.

## Attackers

- Malware or a same-UID attacker on an unlocked device.
- A malicious or lying RPC provider.
- A phishing recipient, fake token, or address-poisoning attacker.
- A network observer or DNS/TLS attacker.
- A supply-chain attacker in dependencies or CI.
- A person with a stolen backup or exposed signing key.

## Controls

- Argon2id + XChaCha20-Poly1305, device-bound vault layer.
- Local-only keys, atomic storage, locks, auto-lock, screenshot blocking.
- Exact review, chain-ID binding, hold-to-confirm, spending freeze/allowlist/limit.
- TLS validation, pinning, Tor/SOCKS/HTTP proxy, fail-closed routing.
- Canonical token registry and unverified-lookalike warning.
- Signed releases, SBOM, checksums, reproducibility, denylist for the old
  Android signer.

## Out of scope / not verified

- A fully compromised operating system or rooted phone.
- Physical cold-wallet isolation and two-device hardware operation.
- Secure memory erasure in Dart/Android managed memory.
- Independent third-party assurance.
- Real-fund transaction testing by the project.
