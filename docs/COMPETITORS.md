# Competitor comparison — capabilities, not a safety ranking

**Compiled:** 2026-11-06
**Scope:** desktop Linux EVM use, as relevant to this project; version 1.1.0 enables BNB Smart Chain.
**Method:** public vendor documentation and public source repositories,
accessed on the date above. No competitor product was installed or tested for
this comparison. Every cell that could not be checked from a primary source is
marked **UNVERIFIED**. A vendor feature claim is not an independent security
assessment.

This table must never be used as a claim that X Wallet is "safer" than any
other product. Different threat models need different tools; choose the
custody model that matches the value at risk.

| Property | X Wallet | MetaMask | Trust Wallet | Rabby | SafePal | Ledger Live | Trezor Suite |
|---|---|---|---|---|---|---|---|
| Native Linux desktop app | **Yes** (Flutter/GTK, `.deb`) | No native Linux desktop app; browser extension/mobile | No native Linux desktop app; mobile/extension | Vendor offers a desktop app; Linux support **UNVERIFIED** | No Linux desktop app; mobile + hardware | **Yes** (desktop app) | **Yes** (desktop app) |
| Local key management | Yes, encrypted local vault | Yes, local wallet | Yes, local wallet | Yes, local wallet | Keys in hardware device; app is a companion | Keys in hardware device; app is a companion | Keys in hardware device; app is a companion |
| Hardware-wallet signing | **Out of scope** | Vendor supports Ledger/Trezor | Vendor supports hardware integrations | Vendor supports hardware wallets | Hardware wallet vendor | Ledger devices | Trezor devices |
| Offline / air-gapped signing | Built-in request/sign/verify file and paste protocol; QR **display only** | Not a first-class workflow | Not a first-class workflow | Not a first-class workflow | QR-based hardware signing | Device-based signing | Device-based signing |
| Source code available | Yes, AGPL-3.0-or-later | Extension source published | Core source published | Extension source published | Mostly proprietary | Source published | Source published |
| Published independent audit | **None** for this project | Vendor-published audits exist; scope **UNVERIFIED** here | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | Vendor-published audits exist; scope **UNVERIFIED** here | Vendor-published audits exist; scope **UNVERIFIED** here |
| Transaction simulation / pre-sign warnings | Local rehearsal + node `eth_call`; not a guarantee | Vendor feature; scope **UNVERIFIED** | Vendor feature; scope **UNVERIFIED** | Vendor emphasises pre-sign risk checks; **UNVERIFIED** | Vendor feature; **UNVERIFIED** | Device screen shows transaction fields | Device screen shows transaction fields |
| Recovery phrase export | Yes, local only | Yes | Yes | Yes | Device recovery | Device recovery | Device recovery |
| Accessibility evidence | Keyboard/focus work in progress; no external audit | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** |
| Performance on 2-core / 4 GB Linux | Measured in `docs/GENERATED_STATUS.md` | Not measured here | Not measured here | Not measured here | Not measured here | Not measured here | Not measured here |
| Open-source reproducible build evidence | Partial; see release gate | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** | **UNVERIFIED** |

## What this project can honestly claim as differentiation

1. **Linux-native desktop workflow** with a packaged `.deb`, not a browser
   extension holding the seed in a browser profile.
2. **Offline request/sign/verify protocol in the same codebase**, with strict
   canonical serialization and independent ethers.js verification.
3. **Verifiable release evidence**: recorded check results, SBOM, artifact
   hashes, and a release gate with explicit `VERIFIED` / `PARTIALLY VERIFIED` /
   `INCOMPLETE` / `FAILED` states.
4. **Published scope and evidence**: internal self-audit (not an independent
   audit), signed artifacts, a risk-control guide, and reproducible builds.

## What this project must not claim

- That it is safer than MetaMask, Trust Wallet, Rabby, SafePal, Ledger Live,
  or Trezor Suite.
- That transaction simulation guarantees safety.
- That a local hot wallet protects against a compromised operating system.
- That any competitor lacks a feature merely because this table marks it
  **UNVERIFIED**.

## Sources (accessed 2026-11-06)

- MetaMask: <https://metamask.io/> and <https://docs.metamask.io/>
- Trust Wallet: <https://trustwallet.com/>
- Rabby: <https://rabby.io/>
- SafePal: <https://www.safepal.com/>
- Ledger Live: <https://www.ledger.com/ledger-live>
- Trezor Suite: <https://trezor.io/trezor-suite>

Each vendor's own documentation is the authority for its current features.
Re-check before repeating any claim in marketing material.
