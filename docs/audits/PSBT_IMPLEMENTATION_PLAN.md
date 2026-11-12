# PSBT implementation plan (design only)

Status: **DESIGNED, NOT IMPLEMENTED**. No PSBT import/export/sign/finalize
code exists in X-Wallet 2.0.0 yet.

## Scope

- BIP174 PSBT v0.
- BIP370 PSBT v2.
- BIP371 Taproot fields.
- BTC first, then LTC. DOGE has no SegWit/Taproot PSBT requirement in this
  wallet; P2PKH PSBT is not exposed unless a clear user need exists.

## Common model

```text
PsbtDocument
  version: 0 | 2
  globalMap: Map<key, value>
  inputs: List<PsbtInput>
  outputs: List<PsbtOutput>
  unknownGlobal: List<KeyValue>
```

Each map preserves unknown key-value pairs byte-for-byte. Keys are
`<keytype><keydata>` and values are raw bytes. Parsing rejects duplicate keys,
truncated key-values, non-canonical compact-size integers and trailing bytes.

## PSBT v0 input fields

| Field | Requirement |
|---|---|
| `non_witness_utxo` | Required when the input is not SegWit; validated against the prevout txid |
| `witness_utxo` | Required for SegWit/Taproot; amount and script checked against the unsigned tx |
| `sighash_type` | Optional; default SIGHASH_ALL |
| `redeem_script` / `witness_script` | Required for P2SH/P2WSH; script hash must match |
| `bip32_derivation` | Public key + master fingerprint + path |
| `partial_sig` | ECDSA signature + pubkey; verified before finalization |
| `final_script_sig` / `final_script_witness` | Only after all required signatures verify |
| `taproot_key_sig` | BIP371; Schnorr signature over the correct sighash |
| `taproot_internal_key` | BIP371; must match the derived key/tweak |
| `taproot_bip32_derivation` | BIP371 |
| unknown fields | Preserved |

## PSBT v2 differences

- Global tx version, locktime, input/output counts.
- Per-input prevout txid/vout, sequence, amount, script.
- Per-output amount and script.
- No duplicate v0 unsigned transaction; the plan must either upgrade or reject
  mixed v0/v2 fields.
- v2 parsing must reject missing required fields and count mismatches.

## Signing rules

1. Rebuild the unsigned transaction from the PSBT maps.
2. Decode every output and compare against the user-reviewed recipient, amount,
   change and fee.
3. Verify each `witness_utxo`/`non_witness_utxo` matches the input prevout.
4. Verify the script type and ownership before signing.
5. Refuse unknown sighash flags except explicitly supported ones.
6. Sign once per matching key; never sign an input whose ownership is unclear.
7. Verify the produced signature before adding it.
8. Finalize only when the input’s threshold is satisfied and all scripts match.
9. Preserve unknown fields.
10. Re-serialize and re-parse; fail closed on any mismatch.

## Adversarial cases

- Duplicate keys, oversized values, truncated compact integers.
- Negative/overflow amounts, output sum overflow.
- Prevout mismatch, wrong network, wrong script type.
- `witness_utxo` amount/script mismatch.
- Unknown/malformed Taproot internal key or merkle root.
- Signature with wrong sighash or high-S (where low-S is required).
- PSBT with an unsigned tx that differs from the maps.
- Inputs referencing another wallet’s key.
- Mixed v0/v2 fields.
- Finalized input with missing signature.

## Interoperability tests

- `bitcoinjs-lib` / `bitcoind` PSBT fixtures.
- BIP174 published test vectors.
- BIP370/BIP371 fixtures where available.
- Round-trip: parse → serialize → parse, byte-identical for known fields.
- Sign in X-Wallet, verify/finalize with an independent implementation.
- Sign in an independent implementation, finalize in X-Wallet.
- Taproot key-path sign/finalize with an independent implementation.

## UI

- “Export unsigned PSBT” on the send review.
- “Import PSBT” and “Review PSBT” with the same decoded transaction screen.
- “Sign PSBT” only on the offline device.
- “Finalize and broadcast” on the online device.
- No private keys or xprv in the PSBT.

## Exit criteria

PSBT is complete only when v0/v2 parse, sign, finalize, round-trip and
independent interoperability tests pass, and a physical two-device offline
workflow succeeds. Until then the UI must say **PSBT NOT AVAILABLE**.
