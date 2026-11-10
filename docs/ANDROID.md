# X Wallet on Android — simple guide

This guide uses short sentences on purpose.

## 1. Install

1. Download **`x-wallet-1.5.3-android-arm64.apk`** for almost every modern phone, or **`universal`** if you are unsure.
2. Tap the file.
3. Android may ask to allow installs from this app. Allow it for the file manager, then tap **Install**.
4. Open **X Wallet**.

The app is the same wallet as the Linux app: same logo, same vault, same tokens, same spending controls, and the same cold-signing protocol. The UI is English-only.

## 2. Create or import a wallet

1. Open the **Wallet** tab.
2. Tap **Create a new wallet** or **Import a wallet**.
3. Write the recovery words on paper. Do not save them in a photo or a chat.
4. Choose a path. Most wallets use **MetaMask / Trust / BIP-44**.
5. Tap **Save to vault** once.
6. Type a password. Type it again. Tap **Create vault**.
7. You will see a green **Saved in vault** mark.

## 3. Lock and unlock

1. Tap **Lock**.
2. Tap **Open saved wallets**.
3. Type the same password.
4. Tap a wallet, then **Use**.

The password is not shortened or trimmed. Spaces count.

The wallet also locks itself when the app goes to the background and after the
idle timeout, even if you have not set a PIN. A PIN is a convenience gate, not
the lock itself.

## 4. Backup

1. Open **Settings**.
2. Tap **Storage**.
3. Tap **Export backup**.
4. Choose a place with the Android file picker.
5. Keep the file and the password separately.

To restore, tap **Restore backup**, choose the file, and enter its password.

## 5. Tor on Android

X Wallet does not hide a Tor program inside the app. On Android it uses **Orbot**, a separate app made by the Tor Project.

1. Install **Orbot** from <https://orbot.app/>.
2. Open Orbot and turn on its VPN/proxy.
3. Make sure Orbot's SOCKS port is **9050**.
4. In X Wallet open **Settings → Privacy route**.
5. Tap **Tor settings**, choose **Existing Tor or Orbot**, host `127.0.0.1`, port `9050`.
6. Tap **Enable Tor**.

If Orbot is off, X Wallet fails closed. It does not quietly use a direct connection.

## 6. PIN and biometrics

1. Open **Settings → Security**.
2. Turn on **Enable app lock** and set a 6-digit PIN. Trivial PINs are refused.
3. If the phone has strong biometrics, unlocking asks for the fingerprint or
   face first; the PIN is the fallback.
4. **Erase after 10 wrong PINs** is on by default. It deletes the local vault
   and device key; only your paper recovery words can restore the wallet.

## 7. Cold signing

1. On the offline phone choose **Cold** wallet mode.
2. Tap **Export for online device**.
3. The app shows a QR code. You can also save it to a file.
4. On the online phone choose **Online** mode and import the pairing.
5. Check the fingerprint on both screens.
6. Carry the request to the cold phone, review it, hold to sign, and carry the signed response back.

A private-key-only wallet can also pair and sign. It does not need a recovery
phrase.

Camera QR scanning is **not implemented** in 1.5.0. Use the displayed QR and
the file/paste options. This is listed in the release limitations.

## 8. File sharing

Android uses the system file picker for backups and cold-wallet files. The app does not request broad storage permission. You choose the exact file or folder each time.

## 9. USD values and activity

- **Activity** shows pending transfers and saved receipts, with All / Pending /
  Done / Failed filters.
- **Show USD values** in Settings → Display uses public CoinGecko prices. The
  request contains only fixed coin IDs, never your address or balance. Turn it
  off if you do not want the request at all.
- **Inspect any address** is under Settings → Security. It is a read-only
  public lookup.

## 10. If something looks wrong

- **Wrong password:** check the keyboard language and spaces. The vault uses the password exactly as typed.
- **No saved wallet:** tap **Save to vault** once and look for the green **Saved in vault** mark.
- **Tor will not connect:** open Orbot and wait until it says Connected. Then try again.
- **App shows an old version:** uninstall the old copy first if it was signed with a different key, then install the new APK.
