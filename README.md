<div align="center">
  <img src="assets/icon/x-wallet-256.png" alt="X Wallet" width="128" />
  <h1>X Wallet</h1>
  <p><strong>Your keys. Your device. Your EVM wallet.</strong></p>
  <p>A free, open-source, self-custodial desktop wallet for Linux.</p>

  [![Latest release](https://img.shields.io/github/v/release/jackh0006/X-Wallet?label=release&sort=semver)](https://github.com/jackh0006/X-Wallet/releases/latest)
  [![Verify CI](https://github.com/jackh0006/X-Wallet/actions/workflows/verify.yml/badge.svg?branch=main)](https://github.com/jackh0006/X-Wallet/actions/workflows/verify.yml)
  [![CodeQL](https://github.com/jackh0006/X-Wallet/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/jackh0006/X-Wallet/actions/workflows/codeql.yml)
  [![License: AGPL-3.0-or-later](https://img.shields.io/badge/license-AGPL--3.0--or--later-blue)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-Linux%20amd64-lightgrey)](https://github.com/jackh0006/X-Wallet/releases/latest)
  [![OpenSSF Scorecard](https://img.shields.io/ossf-scorecard/github.com/jackh0006/X-Wallet?label=OpenSSF%20Scorecard)](https://securityscorecards.dev/viewer/?uri=github.com/jackh0006/X-Wallet)
  [![Tests](https://img.shields.io/badge/tests-59%20files%20%7C%20344%20declarations-brightgreen)](docs/TEST_EVIDENCE.md)
</div>

<!-- BEGIN GENERATED:status -->
> **X Wallet 1.3.1+8** · 59 test files · 344 test declarations
>
> [Download the latest release](https://github.com/jackh0006/X-Wallet/releases/latest) · [Full test evidence](docs/TEST_EVIDENCE.md) · [Release status](docs/GENERATED_STATUS.md)
<!-- END GENERATED:status -->

## Contents

- [Why X Wallet](#why-x-wallet)
- [Supported networks](#supported-networks)
- [Download, verify, install](#download-verify-install)
- [Quick start](#quick-start)
- [Feature tour](#feature-tour)
- [Security and encryption](#security-and-encryption)
- [Proof: test evidence](#proof-test-evidence)
- [X Wallet advantages](#x-wallet-advantages)
- [Risk and responsible use](#risk-and-responsible-use)
- [Documentation](#documentation)
- [Contributing and security](#contributing-and-security)
- [License](#license)

## Why X Wallet

X Wallet is built for people who want a real desktop wallet, not a browser tab
or a phone-only app.

- **Self-custodial by design.** The recovery phrase and signing keys stay on
  your device. There is no account, no custody, and no sign-up.
- **Native Linux package.** A real `.deb` with a desktop launcher, upgrade
  path, and user-data preservation.
- **Cold signing built in.** Create an offline signer and an online companion
  from the same open-source application; private-key-only wallets can pair and
  sign too.
- **Multiple wallets in one vault.** Add, switch, rename, and remove wallets
  with one vault password.
- **Any vault password, honestly scored.** Short and long passphrases are
  accepted; a live strength meter shows Very weak through Very strong.
- **USDT and USDC by default.** BNB, USDT, and USDC appear in every BSC wallet
  with contracts read from the chain.
- **Verified public RPC doors.** Default nodes include BNB Chain, PublicNode,
  1RPC, Blast, and 48.club public endpoints.
- **Privacy is a setting, not an afterthought.** Tor, SOCKS5, HTTPS proxies,
  custom RPC nodes, TLS pinning, and fail-closed routing.
- **Review before you sign.** Full recipient, chain, nonce, fee, maximum-cost,
  and calldata checks, with hold-to-confirm.
- **Encrypted local history.** Vault, activity log, and receipts are protected
  at rest with Argon2id and XChaCha20-Poly1305.
- **Free and open source.** AGPL-3.0-or-later, no subscription, no paywall, no
  ads, and no analytics SDK in the locked dependency inventory.
- **Evidence, not slogans.** 59 test files, 344 test declarations, mutation
  testing, CodeQL, SBOM, a reproducible build, and an independent ethers.js
  cross-check.

## Supported networks

Version **1.3.1** enables **BNB Smart Chain** mainnet (56) and testnet (97).
The codebase uses EVM address, transaction, and signing primitives. Additional
EVM networks are planned; support begins only when a release documents it.

## Download, verify, install

Get the latest release from:

**<https://github.com/jackh0006/X-Wallet/releases/latest>**

```bash
# 1. Download the package and checksums from the release page.
# 2. Verify the download.
sha256sum x-wallet-1.3.1-amd64.deb
sha256sum -c SHA256SUMS
gpg --import x-wallet-signing-key.asc
gpg --fingerprint CC819EF5E109A1518E840379D8C0CEC84BCCE06B
gpg --verify SHA256SUMS.asc SHA256SUMS

# 3. Install.
sudo apt install ./x-wallet-1.3.1-amd64.deb
```

The Debian package is `x-wallet`. It replaces `bnb-wallet`, preserves the
existing user-data directory, and keeps `/usr/bin/bnb-wallet` as a
compatibility alias.

The release is signed with owner key
`CC819EF5E109A1518E840379D8C0CEC84BCCE06B`. Verify the fingerprint through an
independent channel before trusting it.

## Quick start

1. Install X Wallet and open it from your application menu.
2. Create a new wallet or import an existing BIP-39 recovery phrase.
3. Write the recovery phrase on paper and verify the backup.
4. Check the derived address against an independent record.
5. Receive a small test amount first, then send a small test transaction.
6. Choose a custom RPC node or enable Tor/SOCKS routing if you want more
   control over network privacy.

## Feature tour

### Encrypted local vault

The vault uses Argon2id (64 MiB, t=3, p=4) and XChaCha20-Poly1305 with a
double-wrapped envelope: a password-derived layer and a device-bound layer.
Writes are atomic, permissions are hardened, and the v1 vault format migrates
on save.

### Transaction review that shows the details

Before signing, X Wallet shows the full checksummed recipient, chain, nonce,
fee fields, maximum cost, and token calldata. Hold-to-confirm prevents a
single accidental tap. Address-poisoning checks and an uncertain-broadcast
state are part of the flow.

### Cold and offline signing

The offline signer has no network path. The online companion prepares the
request and broadcasts the signed result. Pairing, expiry, replay protection,
and field allowlists are enforced, and a separate ethers.js implementation
reconstructs and verifies the signed bytes.

### Privacy routing

Choose direct HTTPS, HTTP/HTTPS proxy, SOCKS5, or Tor. Standard certificate and
hostname validation always runs before any SPKI pin. Privacy mode fails closed;
it does not silently fall back to a direct connection.

### Local history and receipts

Activity records and receipt images are stored in encrypted local envelopes.
Lock, PIN backoff, idle lock, and erase-all-data controls are built in.

## Security and encryption

| Control | Implementation |
|---|---|
| Vault key derivation | Argon2id, 64 MiB, t=3, p=4 |
| Vault encryption | XChaCha20-Poly1305, double-wrapped envelope, authenticated header |
| Device binding | Device secret in the platform secure store, separate from the vault file |
| Storage | Atomic writes, restrictive permissions, no-follow checks, process lock |
| Transaction integrity | Local signing with chain, nonce, recipient, value, fee, and calldata checks |
| Cold signing | Offline signer has no network; companion prepares and broadcasts signed bytes |
| Transport | TLS validation first, SPKI pins second, Tor/SOCKS/proxy, fail-closed routing |
| Release integrity | Signed `SHA256SUMS`, SHA-256, CycloneDX SBOM, reproducible fixed-path build |

Read [Cryptography](docs/CRYPTO.md), [Threat model](docs/THREAT_MODEL.md), and
the [AI and human review guide](docs/AI_REVIEW.md) for the full design and
evidence map.

## Proof: test evidence

Every mark below is from already-recorded local evidence or a green GitHub
Actions run. No new tests were invented for this page.

### Code quality and policy

| Mark | Test | Command / evidence | What it proves |
|---|---|---|---|
| ✅ PASS | Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | Source is consistently formatted and easier to review. |
| ✅ PASS | Static analysis | `flutter analyze --no-pub` | No analyzer issues in the wallet code. |
| ✅ PASS | Default test suite | `bash scripts/test-suite.sh` — 52/52 files, 0 failed, 0 timed out, 674 s | Unit, widget, vault, network, and security tests pass. |
| ✅ PASS | Test inventory | `python3 scripts/test_inventory.py --check` — 59 files / 344 declarations | Every test file is accounted for; none is silently missing. |
| ✅ PASS | Mutation testing | `python3 scripts/security_mutation_check.py` — 5/5 killed, 97 s | Deliberately broken security checks are caught. |
| ✅ PASS | Branding validator | `python3 scripts/check_branding.py` | User-facing product identity is consistent. |
| ✅ PASS | Free-use validator | `python3 scripts/check_free_product.py` | No subscription, paywall, ads, or payment SDK. |

### Cryptography, vault, and signing

| Mark | Test | Command / evidence | What it proves |
|---|---|---|---|
| ✅ PASS | Production KDF | `test/kdf_production_test.dart` — native Argon2id 64 MiB, t=3, p=4 | Real key derivation works and the pure-Dart path agrees. |
| ✅ PASS | Independent cold signature | `verification/` ethers.js oracle — 8 substitutions rejected | A separate implementation rebuilds and verifies signed transactions; tampering fails. |
| ✅ PASS | Cold wallet protocol/service | `cold_wallet_protocol_test`, `cold_wallet_service_test` | Pairing, expiry, replay, substitution, persistence, and broadcast rules are enforced. |
| ✅ PASS | Backup/restore E2E | `test/backup_restore_e2e_test.dart` — 4/4 | Create, backup, wipe, restore, wrong password, tamper, and truncation cases pass. |
| ✅ PASS | Release signing tools | `bash scripts/test_release_signing.sh` — 6 cases | Valid signatures pass; wrong key, tampered package/sums, missing signature, and unknown key are rejected. |
| ✅ PASS | Android signer inventory | `bash scripts/test_android_inventory.sh` | Signer fingerprints are read correctly and passwords do not leak into output. |

### Chain, transactions, and privacy

| Mark | Test | Command / evidence | What it proves |
|---|---|---|---|
| ✅ PASS | Real EVM integration | Anvil 1.9.0, chain 97 — 3/3 | Native transfer, wrong-chain rejection, and ERC-20 deploy/mint/transfer/approve/revoke/revert work against a real EVM node. |
| ✅ PASS | RPC adversarial tests | `test/rpc_adversarial_test.dart` | Wrong chain, malformed JSON/HTML, oversized balances, and unsafe URLs are rejected. |
| ✅ PASS | TLS pinning | `test/tls_pinning_test.dart` | Standard certificate validation runs first; a pin cannot bypass CA/hostname checks. |
| ✅ PASS | Privacy routing | Tor/proxy/privacy test files | Traffic follows the configured route; no silent fallback. |
| ✅ PASS | Transaction review | `send_intent_test`, `tx_lifecycle_test`, `hold_to_confirm_test` | Recipient, chain, nonce, fees, calldata, maximum cost, and hold-to-confirm are checked before signing. |

### Release, build, and supply chain

| Mark | Test | Command / evidence | What it proves |
|---|---|---|---|
| ✅ PASS | Linux release build | `flutter build linux --release` | The desktop release bundle builds successfully. |
| ✅ PASS | Debian package build | `bash scripts/build-deb.sh` | A real `x-wallet-1.3.1-amd64.deb` is produced. |
| ✅ PASS | Package sanity | `dpkg-deb -x` + `ldd` + secret-name scan | Native libraries resolve and no secret-bearing filenames are packaged. |
| ✅ PASS | Install / launch / upgrade / uninstall | `scripts/package-smoke.sh` on Ubuntu 24.04 | Install, launch, upgrade from `bnb-wallet` 1.0.9 with data preserved, uninstall, and reinstall all work. |
| ✅ PASS | Fixed-path reproducibility | `bash scripts/reproducibility-check.sh` — archive `dffb5b35…` | Two builds produce the identical archive and manifest. |
| ✅ PASS | Cross-runner reproducibility | CI workflow run `42315071276` | Separate runners reproduce the same fixed-path archive. |
| ✅ PASS | Secret scan | `bash scripts/secret-scan.sh` | No secrets in the current tree. |
| ✅ PASS | Dependency advisory audit | `python3 scripts/dependency-audit.py` | No current advisory flags for the locked dependencies. |
| ✅ PASS | License inventory | `python3 scripts/license-check.py` | Every dependency license is inventoried. |
| ✅ PASS | SBOM | `python3 scripts/sbom.py` — 116 packages | The full dependency inventory is published and hashed. |
| ✅ PASS | Release evidence identity | `python3 scripts/check_release_identity.py` | Manifest, SBOM, evidence, and artifact hashes bind to one source commit. |
| ✅ PASS | Release identity negative tests | `scripts/test_release_identity.py` — 15/15 | Stale, tampered, malformed, and ambiguous identities are rejected. |
| ✅ PASS | Localization | `test/localization_test.dart` | The runtime `Text` layer follows the selected locale. |
| ✅ PASS | Spending safety | `test/spending_policy_test.dart` — 5/5 | Freeze signing, allowlist, and native per-transaction limit are enforced before signing. |
| ✅ PASS | Data boundary | `test/data_boundary_test.dart` — 4/4 | No telemetry/AI SDK; no network in key modules; a single HTTP choke point. |
| ✅ PASS | Hosted CI | `main`: `verify`, `docs-sync`, `integration`, `package-smoke`, `CodeQL` | Every required workflow is green. |
| ✅ PASS | CodeQL | C/C++, JavaScript/TypeScript, Python, Actions | Static security analysis runs across four languages. |
| ✅ PASS | Generated-docs sync | `python3 scripts/generate_docs.py --check` | Generated status and README blocks match the committed files. |

The full command-by-command record is in
**[docs/TEST_EVIDENCE.md](docs/TEST_EVIDENCE.md)** and
**[docs/TEST_RESULTS.md](docs/TEST_RESULTS.md)**.

## X Wallet advantages

X Wallet is designed for a different starting point: a native Linux desktop,
local key custody, and a built-in cold-signing workflow.

### What you get with X Wallet

| Advantage | Why it matters |
|---|---|
| **Native Linux `.deb`** | A real desktop application with launcher integration, an upgrade path, and data preservation. |
| **Built-in cold/offline signing** | The offline signer and online companion live in one open-source codebase. |
| **Tor / SOCKS5 / proxy routing** | Privacy is a first-class setting, with fail-closed routing. |
| **Double-wrapped local vault** | Argon2id plus XChaCha20-Poly1305, with a device-bound layer. |
| **Exact transaction review** | Full recipient, chain, nonce, fee, maximum-cost, and calldata checks before signing. |
| **Encrypted local history** | Activity logs and receipts are protected at rest. |
| **No account, no KYC, no ads** | No sign-up, no subscription, no paywall, and no analytics SDK in the locked dependency inventory. |
| **Open source and reproducible** | AGPL-3.0-or-later, SBOM, checksums, and a fixed-path reproducible build. |
| **Data-preserving package migration** | Upgrading from the previous package keeps existing wallet data and compatibility aliases. |
| **344 test declarations** | Evidence is published: unit, widget, security, mutation, integration, and release tests. |

### Compared by wallet style

This is a design comparison, not a safety ranking. “Varies” means the feature
depends on the specific product or configuration.

| Capability | X Wallet | Browser-extension wallets | Mobile wallets | Hardware wallets |
|---|---|---|---|---|
| Native Linux desktop package | **Built in** | Browser-bound | Phone-first | Companion app |
| Local encrypted vault | **Built in** | Varies | Varies | On device |
| Built-in cold/offline signing | **Built in** | Varies | Varies | Requires hardware |
| Tor / SOCKS5 routing | **Built in** | Varies | Varies | Varies |
| Hold-to-confirm review | **Built in** | Varies | Varies | Varies |
| Open-source code | **AGPL-3.0** | Varies | Varies | Varies |
| Reproducible fixed-path build | **Yes** | Varies | Varies | Varies |
| No account required | **Yes** | Varies | Varies | Yes |

## Risk and responsible use

X Wallet is a self-custodial software wallet. You control the keys, so you also
control the security boundary.

- **Device security.** A compromised operating system, malware, or an attacker
  with the same user account can read an unlocked session.
- **Recovery phrase.** Write it on paper and store it offline. There is no
  recovery service.
- **RPC trust.** A node operator can see your addresses and requests. Use your
  own node or the privacy routing options for more control.
- **Large amounts.** For significant holdings, split the balance across
  vault accounts and use cold/offline signing with the operating controls in
  `docs/RISK_CONTROLS.md`.
- **Network fees.** Blockchain fees are paid to the network, not to X Wallet.
- **Download integrity.** Download only from the official release page, verify
  the published SHA-256, and verify `SHA256SUMS.asc` against the signing
  fingerprint obtained independently.

## Documentation

| Guide | What it covers |
|---|---|
| [Project completion](docs/PROJECT_COMPLETION.md) | What X Wallet is, install, recovery, and support status |
| [AI and human review guide](docs/AI_REVIEW.md) | Repository map, verification commands, and 0–100 rubric |
| [Security scorecard](docs/SECURITY_SCORECARD.md) | Internal self-assessment, evidence, and OpenSSF Scorecard |
| [Test evidence](docs/TEST_EVIDENCE.md) | Every command and result in one place |
| [Test results](docs/TEST_RESULTS.md) | Recorded test runs and environment |
| [Security](SECURITY.md) | Security policy and reporting |
| [Threat model](docs/THREAT_MODEL.md) | Assets, adversaries, and controls |
| [Crypto](docs/CRYPTO.md) | KDF, vault envelopes, and key handling |
| [Backup and recovery](docs/BACKUP_AND_RECOVERY.md) | Recovery phrase and vault recovery |
| [Cold wallet](docs/COLD_WALLET.md) | Offline signer and companion workflow |
| [Network guide](docs/network/NETWORK_GUIDE.md) | RPC, Tor, proxies, and privacy |
| [Privacy setup](docs/PRIVACY_SETUP.md) | VPN/VLESS before Tor, Tor chaining, proxy commands, and logs |
| [Rename compatibility](docs/RENAME_COMPATIBILITY.md) | Preserved identifiers and package migration |
| [Risk controls](docs/RISK_CONTROLS.md) | Spending controls and safe operation for larger balances |
| [Data control and AI boundary](docs/DATA_CONTROL.md) | What stays local and what leaves the device |
| [High-value custody](docs/HIGH_VALUE_CUSTODY.md) | Custody tiers and operating guidance |
| [Release evidence](docs/RELEASE_EVIDENCE.md) | How releases are built and verified |
| [Update playbook](docs/UPDATE_PLAYBOOK.md) | Change-scoped verification and the fast release path |
| [Verified defaults](docs/DEFAULTS.md) | Default tokens, public RPC doors, and the checks behind them |

## Contributing and security

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

Report security issues privately to **jackh109867@gmail.com**. Never send a
seed phrase, private key, password, or live wallet file.

## License

X Wallet is free software under the **GNU Affero General Public License v3.0 or
later**. See [LICENSE](LICENSE).

X Wallet is free to use: no subscription, paid license, paywall, advertisement,
or payment is required for core wallet functions. Blockchain network fees are
paid to the network, not to X Wallet. Donations are optional and separate.
