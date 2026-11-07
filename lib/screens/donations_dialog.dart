import 'package:flutter/material.dart';

import 'common.dart';

/// Public donation addresses published by the author in the related
/// `BNB-Terminal-Wallet` repository. They are shown with their published
/// network label and are never part of the wallet's balance.
class DonationAddress {
  const DonationAddress(this.network, this.asset, this.address);
  final String network;
  final String asset;
  final String address;
}

const List<DonationAddress> donationAddresses = [
  DonationAddress(
    'Bitcoin',
    'BTC',
    'bc1q8t0fn2yrsy4lh3m0pz34uj27t8vxjeavkjym83',
  ),
  DonationAddress('Dogecoin', 'DOGE', 'D6ZdMQ7mHGGmuH9prpZ2zjpnG5Q3WVRDtC'),
  DonationAddress(
    'Ethereum',
    'ETH',
    '0xdad428900a4359be8f76b3062df34211582e09eb',
  ),
  DonationAddress(
    'Ethereum',
    'USDT (ERC-20)',
    '0xdad428900a4359be8f76b3062df34211582e09eb',
  ),
  DonationAddress('TRON', 'TRX', 'TMpb6RNTuGNM1eTakm9kjds1mRTPYYJesf'),
  DonationAddress(
    'TRON',
    'USDT (TRC-20)',
    'TMpb6RNTuGNM1eTakm9kjds1mRTPYYJesf',
  ),
  DonationAddress(
    'BNB Smart Chain',
    'BNB',
    '0xdad428900a4359be8f76b3062df34211582e09eb',
  ),
  DonationAddress(
    'BNB Smart Chain',
    'USDT (BEP-20)',
    '0xdad428900a4359be8f76b3062df34211582e09eb',
  ),
  DonationAddress(
    'Solana',
    'SOL',
    'BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL',
  ),
  DonationAddress(
    'Solana',
    'USDT (SPL)',
    'BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL',
  ),
  DonationAddress(
    'Solana',
    'USDC (SPL)',
    'BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL',
  ),
  DonationAddress('XRP Ledger', 'XRP', 'rNUAhaATFLvosdu9m9M95bupRBtZ8eqpj9'),
  DonationAddress(
    'TON',
    'TON',
    'UQCu6-3yGyQ5dzvcCxr2gobuvx5ddbS9EC690qtey92P5_wX',
  ),
  DonationAddress(
    'Litecoin',
    'LTC',
    'ltc1q2gs89cfy3mumr7gu9w0zl9rllf80q67m5rmma8',
  ),
];

Future<void> showDonationsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Project donations'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional support for maintenance. These are the author\'s '
                'public addresses, not your wallet balance. Verify the full '
                'address in the project repository before sending.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Donations are irreversible. This dialog never appears in a '
                'transaction confirmation.',
                style: TextStyle(color: Color(0xFF6E6E6E), fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: donationAddresses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = donationAddresses[index];
                    return ListTile(
                      dense: true,
                      title: Text('${item.network} · ${item.asset}'),
                      subtitle: SelectableText(
                        item.address,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Copy ${item.asset} address',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => copyText(
                              dialogContext,
                              item.address,
                              '${item.asset} donation address',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Show ${item.asset} address as QR',
                            icon: const Icon(Icons.qr_code, size: 18),
                            onPressed: () =>
                                showQrDialog(dialogContext, item.address),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
