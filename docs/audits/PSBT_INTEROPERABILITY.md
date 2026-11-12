# PSBT interoperability — status

**NOT IMPLEMENTED.** X-Wallet 2.0.0 does not parse, create, sign or finalize
PSBT.

The design is in `docs/audits/PSBT_IMPLEMENTATION_PLAN.md`. No interoperability
test exists because there is no implementation to test.

Do not describe the wallet as PSBT-compatible or offline-signing capable until:

1. v0/v2 parse and serialize round-trip tests pass.
2. Unknown fields are preserved.
3. Malformed/conflicting maps fail closed.
4. An independent implementation can sign/finalize an X-Wallet PSBT.
5. X-Wallet can finalize a PSBT signed by an independent implementation.
6. A physical two-device workflow succeeds.

Current UI does not expose PSBT.
