# Telemetry audit

- No analytics, ads, crash reporter, Firebase, Sentry, Amplitude, Mixpanel, Segment, AppsFlyer, Adjust, Datadog, PostHog, payment SDK or AI SDK in `pubspec.yaml` or `pubspec.lock` (`test/data_boundary_test.dart`).
- No update check, remote config, favicon/CDN/font fetch, account or email.
- No WebView, JavaScript bridge or remote-debugging code in the Android source reviewed.
- Price APIs are off by default and send only fixed coin IDs.
- `api.ipify.org` is user-initiated from the route-test dialog.
- The only automatic startup traffic is the configured RPC `eth_chainId`, Home balance/nonce/block, and optional BscScan history if a key is configured.

Residual: a proxy/node operator sees the wallet's IP and addresses unless Tor is used. That is disclosed.
