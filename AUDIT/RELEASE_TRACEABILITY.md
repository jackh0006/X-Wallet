# Release traceability

## Identity chain

| Item | Value |
|---|---|
| Tag `v1.5.3` | `34d31e1cc8375b5bbd491edba751c9f1760b9df0` |
| Evidence `sourceCommit` | `4867ff1e9e19fd49d39345a0481acfe5a154d6f4` (first squash) |
| Tested code `checksCommit` | `b84c6feeeb1a7feb2aa7123939b206606adbec84` |
| `main` with docs fixes | `8583393bf3dc98400bc772346ea7608ad1c104be` |
| `.deb` SHA-256 | `e972b14665775753b51e21380c7fd905ceafe9de14ab05611d500de3202c2a2f` |
| Android arm64 SHA-256 | `afad66426f7a94cc5c747a0f32534a8d2b6713f3720bfd0ee397721e5e7c3b65` |
| Android universal SHA-256 | `65556978890133e19c65ace433b42e534565419336f2168f2381a046f249a969` |
| Android signer | `2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a` |
| GPG signer | `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |

## Verdict

The artifacts are correctly signed and hashed, and the tested code is
documented through a squash-merge chain. The tag is **not** the same commit as
the evidence or the tested code, and the tag tree predates the CITATION/VERSION
fixes. This is a **traceability defect**, not an artifact-forgery finding.

The correct fix is a new patch release whose tag is placed on the final
documentation commit and whose artifacts are rebuilt from that exact commit.
Do not rewrite the existing tag or release.
