import 'package:flutter/material.dart';

import '../chains.dart';

/// Unmistakable network label. Colour is never the only signal: the text
/// always says MAINNET, TESTNET or CUSTOM.
class NetworkBadge extends StatelessWidget {
  const NetworkBadge({super.key, required this.network, this.compact = false});

  final String network;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final known = Chains.all.any((chain) => chain.key == network);
    final chain = Chains.byKey(network);
    final isTest = known && chain.isTestnet;
    final label = !known
        ? 'CUSTOM NETWORK'
        : '${chain.shortName.toUpperCase()} · ${isTest ? 'TESTNET' : 'MAINNET'}';
    final color = !known
        ? const Color(0xFF8E24AA)
        : isTest
        ? const Color(0xFFF9A825)
        : const Color(0xFF2E7D32);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9.5 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
