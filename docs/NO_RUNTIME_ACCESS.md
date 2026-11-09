# Builder and AI No-Access Guarantee — X Wallet 1.4.0

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
| No builder-controlled server | The only runtime hosts are BSC RPC nodes, BscScan, GitHub, and Orbot |
| No account or sign-up | The app has no login, account ID, subscription, or cloud profile |
| No remote control or remote update | The app has no command channel, remote config, or background updater |
| Keys stay local | Vault, recovery phrase, private keys, signing, and spending policy are local-only |
| No network in key modules | `test/data_boundary_test.dart` proves vault, KDF, wallet-core, cold-codec, send-intent, and spending-policy modules have no network path |
| One network choke point | All HTTP passes through `lib/net/privacy_client.dart` |
| Minimal Android permissions | Only `INTERNET`, `USE_BIOMETRIC`, and `USE_FINGERPRINT` |
| No file-system overreach on Android | The system file picker grants only the file the user chooses |
| No startup phone-home | The Linux release binary made no external TCP connection at startup |
| Signed, verifiable artifacts | Linux `.deb`, both APKs, source, and SBOM are covered by `SHA256SUMS.asc` |

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

## Runtime proof

The Linux 1.4.0 release binary was started against a copied wallet directory
under `strace -f -e trace=connect,sendto`. It made only local D-Bus, X11, and
AT-SPI Unix-socket connections. No external TCP connection was established.
`ss -tnp` showed no established connection for the wallet process.

## Artifact proof

The signed Linux and Android `libapp.so` files contain only these runtime hosts:

```
https://1rpc.io
https://api.bscscan.com
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

## Verify it yourself

```bash
# No AI, telemetry, or builder SDK in source
grep -rniE "firebase|analytics|sentry|openai|anthropic|deepseek|chatgpt|telemetry|remote.?config" lib pubspec.yaml

# Android permissions
aapt dump permissions x-wallet-1.4.0-android-universal.apk

# Runtime hosts in the compiled Android app
unzip -p x-wallet-1.4.0-android-universal.apk lib/arm64-v8a/libapp.so > libapp.so
strings libapp.so | grep -oE 'https?://[^/]+' | sort -u

# Linux startup trace
strace -f -e trace=connect,sendto ./bnb_wallet_gui
```

**Owner signing fingerprint:**
`CC819EF5E109A1518E840379D8C0CEC84BCCE06B`

**Android release signer:**
`db12869c9127914ff2b8f64cc0a14ddc9be481bf8b4713fb26bb0bd0bd9748d3`

This guarantee is issued for the published 1.4.0 source and signed artifacts.
Device-level security remains the responsibility of the operating system and
the person holding the device.
