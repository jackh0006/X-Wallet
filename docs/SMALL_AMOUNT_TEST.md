# Small-Amount Mainnet Test

Use this only after the wallet is installed from a signed release and the
address was checked independently. Use an amount you can afford to lose.

1. Start on BSC testnet (chain 97). Create a disposable wallet.
2. Receive a small testnet amount. Confirm it appears.
3. Send a small testnet amount to a second address you control. Confirm the
   review screen shows the exact chain, recipient, amount, and fee.
4. Switch to BSC mainnet (chain 56). Fund the wallet with a **very small**
   amount, for example the equivalent of a few dollars.
5. Send a tiny amount to your own second address. Check the transaction on
   BscScan. Confirm the recipient and amount are exactly what you approved.
6. Send a tiny amount to a new recipient. Confirm the recipient on the device
   and on BscScan.
7. Lock and unlock the vault. Confirm the balance and a saved receipt remain.
8. Enable **Freeze signing**, the recipient allowlist, and a small
   per-transaction limit. Confirm a blocked send is refused before signing.
9. Export and restore a vault backup on a clean installation.
10. Record every step, transaction hash, and result. Only after all checks pass
    should you consider a larger, still-limited test.

Do not move meaningful savings until an independent review and physical-device
testing are complete.
