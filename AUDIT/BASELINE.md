# Audit baseline

- Repository: https://github.com/jackh0006/X-Wallet
- Default branch: `main`
- Baseline commit: `8583393bf3dc98400bc772346ea7608ad1c104be`
- Latest release tag: `v1.5.3` (tag object `5362102`, commit `34d31e1cc8375b5bbd491edba751c9f1760b9df0`)
- Version: `1.5.3+15`
- Licence: AGPL-3.0-or-later
- Supported platforms: Linux amd64, Android arm64/universal
- Supported networks: BNB Smart Chain mainnet 56, testnet 97
- Working tree at audit start: clean
- Audit branch: `audit/1.5.3-self-audit` (local; fixes not pushed)
- Tracked files: 414
- Toolchain: Flutter 3.47.6, Dart 3.13.5, Node 24, Python 3.12, OpenJDK 21, Android build-tools 36.0.0
- Environment limits: no physical Android device, no Anvil in PATH, no independent runner, no screen reader, no root/apt install smoke, `unshare -rn` blocked (user namespaces), Docker registry unreachable.

## Release identity caveat

The tag `v1.5.3` predates the documentation fixes that corrected `CITATION.cff`
from 1.1.0 to 1.5.3 and added `VERSION`, `AI_REVIEW_PACKET.md` and the refreshed
threat model. The tag's source tree is therefore **not byte-identical** to
`main` (8583393). The built binaries are from the tested code commit
`b84c6fe`; the tag and evidence chain are documented in
`AUDIT/RELEASE_TRACEABILITY.md`. Do not claim that the tag, main and evidence
are the same commit without qualification.
