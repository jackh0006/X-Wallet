# CONTRIBUTING.md

Thanks for looking at this wallet. It is AGPL-3.0-or-later (see `LICENSE`).

## Ground rules

1. **Privacy first, no exceptions.** Any change that adds a network call
   must route through `RpcService` + `net/privacy_client.dart` (UA scrub,
   SOCKS5/Tor honored, no silent fallbacks). Proxies that "helpfully"
   call out to third services will be refused.
2. **Secrets never move.** Seed words, private keys, vault payload must not
   be logged, clipboarded, hashed into a story line, or sent to disk unencrypted.
   `ClipboardGuard` exists for a reason.
3. **No invented constants.** Fees, block times, ETA windows must be measured
   from the chain (fee history / block stamps), never hardcoded.
4. **Plain words.** User-facing strings explain themselves in plain language;
   a user who never read this file must understand every dialog.
5. **Tests for every pure layer.** Fee math, guards, storage, receipts:
   covered. The automated suite must stay deterministic and offline
   (no `RpcService()` construction in pure tests).

## Practical steps

```bash
flutter pub get
flutter analyze --no-pub     # must stay clean: 0 errors, 0 warnings
bash scripts/test-suite.sh   # light suites 2-wide, kdf suites sequential
python3 scripts/check_token_sources.py   # when touching token_sources.json
python3 scripts/sbom.py --out docs/SBOM.json  # after dependency changes
scripts/build-deb.sh                     # local deb, signed with the release key
```

Deb releases are built and signed by the maintainer only; send PRs against
the repo and the maintainer builds them.

## Reporting a problem

Security-sensitive: write directly to **jackh109867@gmail.com** BEFORE any
public disclosure; you will get a reply. Everything else: open an issue with
the version (`About` screen), the deb hash, and console output — never paste
seed words or keys anywhere, and a responsible report contains no secrets.
