# Builder and AI No-Access Guarantee — X Wallet 1.5.0

**Guarantee:** the X Wallet Linux and Android applications contain no channel
that lets DeepSeek, the AI assistant, or the builder read, copy, receive, or
control user data at runtime.

This guarantee covers:

- the published Linux `.deb`;
- the published Android arm64 APK;
- the published Android universal APK;
- the published source archive and SBOM.

## Guaranteed properties

| Guarantee | Evidence |
|---|---|
| No AI service call | No `openai`, `anthropic`, `deepseek`, `chatgpt`, or model endpoint in source or compiled artifacts |
| No telemetry or analytics SDK | Artifact and dependency scans found none of `firebase`, `analytics`, `sentry`, `amplitude`, `mixpanel`, `segment`, `crashlytics`, `appsflyer` |
| No builder-controlled server | The only runtime hosts are BSC RPC nodes, BscScan, GitHub, Orbot, the public CoinGecko price API, and the public ipify IP echo |
| No account or sign-up | The app has no login, account ID, subscription, or cloud profile |
| No remote control or remote update | The app has no command channel, remote config, or background updater |
| Keys stay local | Vault, recovery phrase, private keys, signing, and spending policy are local-only |
| No network in key modules | `test/data_boundary_test.dart` proves vault, KDF, wallet-core, cold-codec, send-intent, and spending-policy modules have no network path |
| One network choke point | All HTTP passes through `lib/net/privacy_client.dart` |
| Minimal Android permissions | Only `INTERNET`, `USE_BIOMETRIC`, and `USE_FINGERPRINT` |
| No file-system overreach on Android | The system file picker grants only the file the user chooses |
| No startup phone-home | The Linux release binary made no external TCP connection at startup |
| Signed, verifiable artifacts | Linux `.deb`, both APKs, source, and SBOM are covered by `SHA256SUMS.asc` |

## Who can see or control what

| Party | Control over the app or funds | What they can see |
|---|---|---|
| **DeepSeek / AI assistant** | **No runtime control** — no AI endpoint, SDK, account, or command channel in the app | Public source, public releases, this chat. Not a user device or wallet. |
| **Builder** | **No runtime control** — cannot reach into an installed app | Public repository and releases. No live wallet access. |
| **Google / Firebase / analytics** | **No app control** — no Firebase, analytics, ads, telemetry, or AI SDK in the app | Android/Play system telemetry is outside X Wallet. The app itself does not call Google services. |
| **RPC provider** | **Cannot sign or change a signed transaction** — the review is verified against the signed bytes | IP, public addresses, and public transaction data. Never the seed, private keys, password, or signing material. |
| **BscScan** | No control — optional history lookup only | The address/history query the user makes. |
| **Orbot / Tor** | No control — route only | Reduced network metadata. |
| **Blockchain** | No control — public ledger | Public on-chain data. |

## What leaves the app

- RPC requests to the node the user chooses.
- Optional BscScan history requests if the user adds a key.
- External links only when the user taps them.
- Encrypted backups and cold-wallet files only when the user chooses a destination.

No seed phrase, private key, vault password, or signing key is sent to any
server.

## Verified in the signed artifacts

- The compiled Linux and Android apps contain only BSC RPC, BscScan, GitHub,
  and Orbot hosts.
- No `openai`, `anthropic`, `deepseek`, `firebase`, `analytics`, `sentry`, or
  similar SDK is present.
- Android permissions are only `INTERNET`, `USE_BIOMETRIC`, and
  `USE_FINGERPRINT`.
- All HTTP passes through one privacy client.
- Vault, KDF, wallet-core, cold-codec, send-intent, and spending-policy modules
  contain no network path.
- Sending is signed locally; the reviewed transaction is verified against the
  signed bytes.
- Startup trace showed no external TCP connection.

## What the builder and AI can see

- Public source code.
- Public release files and their hashes.
- Public issues and pull requests.

## What they cannot see

- A user device or installed wallet.
- Vault contents or vault password.
- Recovery phrase or private keys.
- Balances, recipients, transaction history, activity logs, or receipts.
- Signing material or spending-policy values.
- Any AI/builder telemetry: there is no SDK, endpoint, API key, or account for
  DeepSeek, OpenAI, Anthropic, or any builder-controlled service.

## Runtime proof

The Linux 1.4.1 release binary was started against a copied wallet directory
under `strace -f -e trace=connect,sendto`. It made only local D-Bus, X11, and
AT-SPI Unix-socket connections. No external TCP connection was established.
`ss -tnp` showed no established connection for the wallet process.

## Artifact proof

The signed Linux and Android `libapp.so` files contain only these runtime hosts:

```
https://1rpc.io
https://api.bscscan.com
https://api.coingecko.com
https://api.ipify.org
https://bsc-dataseed.bnbchain.org
https://bsc-dataseed.nariox.org
https://bsc-dataseed-public.bnbchain.org
https://bsc-mainnet.public.blastapi.io
https://bsc-rpc.publicnode.com
https://bscscan.com
https://bsc-testnet-rpc.publicnode.com
https://data-seed-prebsc-1-s1.bnbchain.org:8545
https://github.com
https://orbot.app
https://rpc.48.club
https://testnet.bscscan.com
```

No builder or AI domain is present.

## Android-specific proof in 1.5.0

- The Android APK contains no AI, analytics, ads, or builder SDK. The only
  native libraries are Flutter, the app, JNI helpers, and the project-built
  `libargon2-arm.so`.
- `libargon2-arm.so` is an offline key-derivation library. It has no network
  code and cannot read or upload anything.
- The Android manifest declares only `INTERNET`, `USE_BIOMETRIC`, and
  `USE_FINGERPRINT`; only the launcher activity is exported.
- `allowBackup=false`, `dataExtractionRules` excludes app data, cleartext is
  disabled, and only system CAs are trusted.
- `FLAG_SECURE` blocks screenshots/recents; `filterTouchesWhenObscured` rejects
  overlay touches.
- The release is signed by `db12869c…9748d3`; the historical
  `10c13aa9…25b85` is denylisted.

DeepSeek and the builder have **no runtime channel** into the app: no endpoint,
SDK, API key, account, remote config, push service, or updater. They can read
the public source and public releases, and nothing from a user's wallet.

## Verify it yourself

```bash
# No AI, telemetry, or builder SDK in source
grep -rniE "firebase|analytics|sentry|openai|anthropic|deepseek|chatgpt|telemetry|remote.?config" lib pubspec.yaml

# Android permissions
aapt dump permissions x-wallet-1.5.0-android-universal.apk

# Runtime hosts in the compiled Android app
unzip -p x-wallet-1.5.0-android-universal.apk lib/arm64-v8a/libapp.so > libapp.so
strings libapp.so | grep -oE 'https?://[^/]+' | sort -u

# Linux startup trace
strace -f -e trace=connect,sendto ./bnb_wallet_gui
```

**Owner signing fingerprint:**
`CC819EF5E109A1518E840379D8C0CEC84BCCE06B`

**Android release signer:**
`db12869c9127914ff2b8f64cc0a14ddc9be481bf8b4713fb26bb0bd0bd9748d3`

CoinGecko receives only a fixed list of public coin IDs; it never receives a wallet address, balance, vault, or identifier. ipify receives only the request itself and is used to display the public IP of the active route when the user runs the route test.

This guarantee is issued for the published 1.5.0 source and signed artifacts.
Device-level hardening controls are documented in
[SECURITY_LIMITATIONS.md](../SECURITY_LIMITATIONS.md).
