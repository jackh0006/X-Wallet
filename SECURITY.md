# Security policy

X Wallet is AI-assisted and self-assessed personal-use software wallet. Do
not report a security issue in a public GitHub issue and do not include seed
phrases, private keys, vault files, passwords, or live transaction data in a
report. AI assistance and self-assessment are not independent review.

## Reporting a vulnerability

Email jackh109867@gmail.com with:

- a concise description and affected version/commit;
- safe reproduction steps using only throwaway keys and a local/test network;
- impact and any suggested mitigation.

The maintainer will acknowledge reports privately, assess impact, prepare a
fix, and coordinate disclosure with the reporter. Target first response:
within 7 days; fix or mitigation plan for a confirmed high issue: within 30
days. There is no bounty program, and this project does not claim a funded
bounty or a long public track record.

### PGP

Release and report key fingerprint:

```
CC819EF5E109A1518E840379D8C0CEC84BCCE06B
```

Public key: `docs/keys/x-wallet-signing-key.asc`. Verify the fingerprint
through an independent channel before trusting it. Encrypt sensitive report
details to this key if you can.

### Safe harbour

Good-faith research on your own test keys, a local node, and testnet is
welcome. Do not test against other people's wallets, mainnet funds, or
third-party infrastructure without permission.

## Security status

Automated checks, source review, and package signatures reduce risk; no
software wallet can prove safety for every environment. Read
[SECURITY_AUDIT.md](SECURITY_AUDIT.md),
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md), and
[docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md) before use. The
version-specific pass/fail record and confirmation rule are in
[docs/RELEASE_EVIDENCE.md](docs/RELEASE_EVIDENCE.md).

This project has **no independent third-party security audit**. The
self-assessment, automated tests, SBOM, and release gate are evidence of
engineering work, not an audit opinion.

## Supported versions

| Version | Status |
|---|---|
| `1.5.3` | Current release; signed Linux package and Android APKs; owner key `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |
| `1.5.1` | Previous release; Android APKs used the older `db12869c…9748d3` signer |
| `1.2.0` | Previous stable release; superseded by 1.3.0 |
| `1.0.10` and earlier | Historical; use their release notes and do not treat old results as evidence for a new build |
| Any APK signed by the historical `10c13aa9…25b85` key | **Blocked and denylisted** |

## Key rotation

If a signing key, seed phrase, device, or release account is suspected
compromised, stop distributing the affected artifact. Create a replacement
identity outside the repository, publish its fingerprint through a trusted
out-of-band channel, and issue a signed release note. The historical Android
release key is compromised; it must never be reused. The full timeline,
impact, owner actions, and current `UNVERIFIED` rotation status are in
[docs/security/INCIDENT_2026-11-KEYSTORE.md](docs/security/INCIDENT_2026-11-KEYSTORE.md).
