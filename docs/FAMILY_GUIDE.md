# Family guide: using X Wallet safely

This guide is deliberately cautious. A software wallet can lose money if the
computer is infected, the recovery phrase is copied, or the wrong address is
approved. For amounts that would be difficult to replace, split the balance and keep the larger part in cold/offline custody.

## First installation

1. Download the `.deb`, `.asc`, and `SHA256SUMS` from the same official GitHub
   Release. Check the checksum and GPG signature as shown in the README.
2. Install with `sudo apt install ./x-wallet-<version>-amd64.deb`.
3. Keep the computer updated and use a screen lock. Do not install unknown
   browser extensions or remote-access software.

## Create a wallet

1. Choose **Create wallet** and use a unique vault password of at least 12
   characters. The PIN only locks the app; it is not a replacement for the
   vault password or recovery phrase.
2. Write each of the 24 recovery words on paper, in order. Make two paper
   copies and store them separately in places only your family can access.
3. Do not photograph, scan, print, email, message, or save the words in cloud
   storage. Do not tell them to anyone, including someone claiming to be
   support.
4. Use **Test my backup** if offered. Before depositing meaningful funds,
   restore the paper words on another clean device and compare the address.

## Send safely

1. Start with a tiny test transfer. Wait for confirmation before sending more.
2. Compare the entire recipient address, not only the first and last digits.
   Ask the recipient to confirm it through another channel.
3. Check the network, amount, maximum fee, and total maximum cost on the
   review screen. Hold to confirm only after each is correct.
4. If the app says broadcast status is unknown, do not resend. Check the
   transaction hash and pending nonce first.
5. Reject unexpected token approvals. Prefer an exact approval amount rather
   than an unlimited allowance.

## If a phone or computer is lost or stolen

1. From a clean device, restore the wallet using the paper recovery phrase.
2. Move funds to a newly created wallet with a new paper backup.
3. Change passwords for accounts that were available on the lost device.
4. Treat any seed phrase typed on the lost device as potentially exposed.

## What never to do

- Never enter recovery words or a private key into a website, chat, form, or
  terminal command.
- Never trust an address pasted from the clipboard without independently
  checking it.
- Never accept help from unsolicited messages or install software at a
  stranger's request.
- Never use mainnet money until a backup restore and tiny test send succeeded.
