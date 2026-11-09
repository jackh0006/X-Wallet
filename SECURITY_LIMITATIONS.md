# Security Limitations

This file is the correct place for material scope and risk. Advertising pages
should link here instead of hiding these facts.

- **No independent audit.** The project publishes an internal self-audit, not a
  third-party audit or certification.
- **Android runtime not tested here.** The APK build, ABI, permissions, and
  signatures are verified, but no physical phone was connected during this
  audit. Use the Huawei Y9 2019 checklist.
- **Cold wallet is a demonstration/prototype.** Physical air-gap, two-device,
  and hardware-isolation security are NOT TESTED.
- **Large-value custody is not certified.** Small disposable mainnet testing is
  the current honest limit; large amounts require independent review and
  device-level controls.
- **Compromised OS.** Malware, a rooted phone, or a same-UID attacker can read
  an unlocked session.
- **Managed memory.** Dart/Android cannot guarantee secure erasure; `mlockall`
  is Linux-only and best-effort.
- **RPC trust.** Balances, nonces, fees, and history come from the chosen node;
  a lying provider can mislead the review screen but cannot forge a local
  signature.
- **Fixed-path reproducibility.** Different absolute build paths may differ
  because Flutter embeds paths.
- **No physical hardware-wallet support** is claimed in 1.x.
