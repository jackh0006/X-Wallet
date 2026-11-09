# Release Security

## Linux

- Built from the tagged source archive.
- Package: `x-wallet-1.4.1-amd64.deb`.
- Detached GPG signature with owner key
  `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`.
- `SHA256SUMS` covers the Linux package, both APKs, source archive, and SBOM.
- Fixed-path reproducibility is recorded.

## Android

- Application ID: `com.jackh0006.xwallet`.
- Label: **X Wallet**.
- Builds: arm64-only and universal (arm64-v8a, armeabi-v7a, x86_64).
- Signed with the new release key outside the repository.
- Signer certificate SHA-256:
  `db12869c9127914ff2b8f64cc0a14ddc9be481bf8b4713fb26bb0bd0bd9748d3`.
- Historical compromised signer
  `10c13aa91cc14288df995095c6b620ff60f3c10e77fd6615635b150463e25b85`
  is denylisted.
- `apksigner` v3 signature and certificate fingerprint are checked.
- `android:debuggable` is not enabled in the release manifest.
- `allowBackup=false`, cleartext traffic disabled, only INTERNET and biometric
  permissions.
- No keystore, password, or private key is in Git.

## Release checklist

1. Run format, analyze, full suite, Anvil, mutation, backup E2E, cold oracle.
2. Build Linux `.deb` and both APKs from the same commit.
3. Verify APK ABI contents and signer certificate.
4. Run package smoke and release identity.
5. Generate SBOM, manifest, checksums, and GPG signatures.
6. Run the release gate; publish only when it is VERIFIED.
7. Back up the Android keystore outside the repository.
