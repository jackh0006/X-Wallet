import 'chains.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:bip32_plus/bip32_plus.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:wallet/wallet.dart';
import 'package:collection/collection.dart';
import 'package:web3dart/web3dart.dart';

import 'cold_tx_codec.dart';
import 'cold_wallet.dart';

/// Pure wallet helpers for the X Wallet.
///
/// Everything here is deterministic and has no network access. Secrets are
/// returned as [EthPrivateKey] objects; callers must never log them.
class WalletCore {
  WalletCore._();

  static const String zeroAddress =
      '0x0000000000000000000000000000000000000000';
  static const String defaultPath = "m/44'/60'/0'/0/0";

  /// Popular derivation paths, each listed exactly once. Most EVM wallets
  /// (MetaMask, Trust Wallet, SafePal, Ledger Live, Trezor) use the same first
  /// account path; the dialog explains that instead of repeating the path
  /// under every brand name. Account indexes are generated separately.
  /// Standard EVM derivation paths. `{index}` is the wallet/address index.
  ///
  /// MetaMask, Trust Wallet, SafePal, Ledger Live and Trezor all use the
  /// first BIP-44 path for their first account. The Ledger Live form changes
  /// the account level, while the legacy MEW form appends the index directly.
  static const Map<String, String> standardPaths = {
    'MetaMask / Trust / BIP-44': "m/44'/60'/0'/0/{index}",
    'Ledger Live (account index)': "m/44'/60'/{index}'/0/0",
    'Ledger Legacy / MEW': "m/44'/60'/0'/{index}",
    'BIP-49 (rare EVM)': "m/49'/60'/0'/0/{index}",
    'BIP-84 (rare EVM)': "m/84'/60'/0'/0/{index}",
    'BIP-86 (rare EVM)': "m/86'/60'/0'/0/{index}",
    'Custom': '',
  };

  static const Map<String, String> standardPathDescriptions = {
    'MetaMask / Trust / BIP-44':
        'The normal first-account path used by MetaMask, Trust Wallet, '
        'SafePal, Ledger Live and Trezor.',
    'Ledger Live (account index)':
        'Ledger Live account-level path. The index is the account number.',
    'Ledger Legacy / MEW': 'Older MyEtherWallet and Ledger setups. The index is appended directly.',
    'BIP-49 (rare EVM)':
        'Rare EVM compatibility path. Most wallets do not use it.',
    'BIP-84 (rare EVM)':
        'Rare EVM compatibility path. Most wallets do not use it.',
    'BIP-86 (rare EVM)':
        'Rare EVM compatibility path. Most wallets do not use it.',
    'Custom': 'Enter any BIP-32 path manually.',
  };

  /// Builds a path from a standard label and index.
  static String pathForLabel(String label, int index) {
    if (index < 0) throw ArgumentError('Account index cannot be negative.');
    final template = standardPaths[label];
    if (template == null) throw ArgumentError('Unknown derivation path.');
    return template.replaceAll('{index}', '$index');
  }

  /// Builds the standard BIP-44 path for an address index (0 = first address).
  static String standardPathForAccount(int index) {
    if (index < 0) throw ArgumentError('Account index cannot be negative.');
    return "m/44'/60'/0'/0/$index";
  }

  /// Generates a BIP-39 mnemonic using a secure random source.
  /// [wordCount] can be 12 or 24 (BIP-39 standard).
  static String generateMnemonic({int wordCount = 24}) {
    if (wordCount != 12 && wordCount != 24) {
      throw ArgumentError('BIP-39 supports only 12 or 24 words.');
    }
    final mnemonic = Mnemonic.generate(
      Language.english,
      length: wordCount == 12 ? MnemonicLength.words12 : MnemonicLength.words24,
    );
    return mnemonic.sentence;
  }

  /// Generates a brand-new secp256k1 private key using a secure RNG.
  ///
  /// A raw private key has no checksum or recovery phrase. The caller must
  /// show it exactly once and require the user to back it up offline.
  static EthPrivateKey generatePrivateKey() {
    return EthPrivateKey.createRandom(Random.secure());
  }

  /// Validates a BIP-39 mnemonic. Returns true when the checksum is valid.
  static bool validateMnemonic(String phrase) {
    try {
      Mnemonic.fromSentence(phrase.trim(), Language.english);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Derives the private key for [path] (default BIP-44 Ethereum path).
  static EthPrivateKey derivePrivateKey({
    required String phrase,
    String passphrase = '',
    String path = defaultPath,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final child = root.derivePath(path);
    final key = child.privateKey;
    if (key == null) {
      throw ArgumentError('Could not derive a private key from that path.');
    }
    return EthPrivateKey(key);
  }

  /// Creates a private key from a 0x-prefixed 64-hex string.
  static EthPrivateKey privateKeyFromHex(String hex) {
    final cleaned = hex.trim();
    if (!cleaned.startsWith('0x') && !cleaned.startsWith('0X')) {
      throw ArgumentError('Private key must start with 0x.');
    }
    final body = cleaned.substring(2);
    if (body.length != 64) {
      throw ArgumentError('Private key must be 64 hexadecimal characters.');
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(body)) {
      throw ArgumentError('Private key contains invalid characters.');
    }
    return EthPrivateKey.fromHex(cleaned);
  }

  /// Normalizes a private key hex string stored in a vault record.
  ///
  /// Older vaults and some import paths can store a key with a leading `00`
  /// byte (66 hex characters) or with leading zero bytes stripped. A valid
  /// EVM private key is exactly 32 bytes, so leading zero bytes are
  /// insignificant. This accepts those representations without weakening
  /// user-facing import validation in [privateKeyFromHex].
  static String normalizePrivateKeyHex(String input) {
    var body = input.trim();
    if (body.startsWith('0x') || body.startsWith('0X')) {
      body = body.substring(2);
    }
    body = body.toLowerCase();
    if (body.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(body)) {
      throw ArgumentError('Private key contains invalid characters.');
    }
    body = body.replaceFirst(RegExp(r'^0+'), '');
    if (body.isEmpty) {
      throw ArgumentError('Private key cannot be zero.');
    }
    if (body.length > 64) {
      throw ArgumentError('Private key is longer than 32 bytes.');
    }
    body = body.padLeft(64, '0');
    return '0x$body';
  }

  /// Parses a private key from a vault record, accepting insignificant
  /// leading zero bytes. Use [privateKeyFromHex] for direct user input.
  static EthPrivateKey privateKeyFromVaultHex(String input) =>
      privateKeyFromHex(normalizePrivateKeyHex(input));

  /// Creates a private key from WIF (Wallet Import Format) string.
  static EthPrivateKey privateKeyFromWIF(String wif) {
    final cleaned = wif.trim();
    try {
      final decoded = _decodeBase58Check(cleaned);
      if (decoded.length != 33 && decoded.length != 34) {
        throw ArgumentError('Invalid WIF length');
      }
      if (decoded[0] != 0x80) {
        throw ArgumentError('Invalid WIF version prefix');
      }
      int keyLength = 32;
      if (decoded.length == 34 && decoded[33] == 0x01) {
        keyLength = 32;
      } else if (decoded.length == 33) {
        keyLength = 32;
      } else {
        throw ArgumentError('Invalid WIF format');
      }
      final privateKeyBytes = decoded.sublist(1, 1 + keyLength);
      return EthPrivateKey(Uint8List.fromList(privateKeyBytes));
    } catch (e) {
      throw ArgumentError('Invalid WIF format: $e');
    }
  }

  /// Decodes a base58check encoded string.
  static Uint8List _decodeBase58Check(String input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final alphabetMap = {
      for (var i = 0; i < alphabet.length; i++) alphabet[i]: i,
    };

    int leadingOnes = 0;
    for (final c in input.codeUnits) {
      if (c == '1'.codeUnitAt(0)) {
        leadingOnes++;
      } else {
        break;
      }
    }

    BigInt num = BigInt.zero;
    for (final c in input.codeUnits) {
      final char = String.fromCharCode(c);
      final val = alphabetMap[char];
      if (val == null) throw ArgumentError('Invalid base58 character: $char');
      num = num * BigInt.from(58) + BigInt.from(val);
    }

    var bytes = _encodeBigIntAsUnsigned(num);
    bytes = bytes.sublist(bytes.indexWhere((b) => b != 0));
    bytes = Uint8List.fromList(List.filled(leadingOnes, 0) + bytes);

    if (bytes.length < 4) throw ArgumentError('Invalid base58check length');
    final payload = bytes.sublist(0, bytes.length - 4);
    final checksum = bytes.sublist(bytes.length - 4);
    final hash1 = keccak256(payload);
    final hash2 = keccak256(hash1);
    final expectedChecksum = hash2.sublist(0, 4);
    if (!const ListEquality().equals(checksum, expectedChecksum)) {
      throw ArgumentError('Invalid base58check checksum');
    }
    return payload;
  }

  /// EIP-55 checksummed address for a private key.
  static String addressFromPrivateKey(EthPrivateKey key) =>
      key.address.eip55With0x;

  /// 0x-prefixed 64-hex private key.
  static String privateKeyHex(EthPrivateKey key) =>
      bytesToHex(key.privateKey, include0x: true);

  /// WIF (Wallet Import Format) for a private key - compressed.
  static String privateKeyWIF(EthPrivateKey key) {
    return 'WIF encoding not yet implemented. Use hex: ${privateKeyHex(key)}';
  }

  /// EIP-55 checksummed form of any valid 20-byte hex address.
  static String checksumAddress(String input) {
    final body = _strip0x(input.trim());
    if (body.length != 40 || !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(body)) {
      throw ArgumentError('Invalid EVM address.');
    }
    final lower = body.toLowerCase();
    final hash = keccak256(Uint8List.fromList(lower.codeUnits));
    final hashHex = bytesToHex(hash);
    final out = StringBuffer('0x');
    for (var i = 0; i < lower.length; i++) {
      final c = lower[i];
      if (c.compareTo('a') >= 0 && c.compareTo('f') <= 0) {
        final nibble = int.parse(hashHex[i], radix: 16);
        out.write(nibble >= 8 ? c.toUpperCase() : c);
      } else {
        out.write(c);
      }
    }
    return out.toString();
  }

  /// True when [input] is a syntactically valid 0x EVM address.
  static bool isValidAddress(String input) {
    try {
      final body = _strip0x(input.trim());
      return body.length == 40 && RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(body);
    } catch (_) {
      return false;
    }
  }

  /// True when a mixed-case address carries the correct EIP-55 checksum.
  /// All-lowercase and all-uppercase forms are accepted (they are not
  /// checksummed); a mixed-case typo is rejected instead of being silently
  /// "repaired" into a different valid-looking address.
  static bool isChecksumValid(String input) {
    final body = _strip0x(input.trim());
    if (body.length != 40 || !RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(body)) {
      return false;
    }
    final hasLower = RegExp(r'[a-f]').hasMatch(body);
    final hasUpper = RegExp(r'[A-F]').hasMatch(body);
    if (!hasLower || !hasUpper) return true;
    return checksumAddress('0x$body').substring(2) == body;
  }

  /// True when [input] is the all-zero address.
  static bool isZeroAddress(String input) =>
      _strip0x(input.trim()).toLowerCase() == _strip0x(zeroAddress);

  /// Creates an Ethereum V3 keystore JSON for [key] protected by [password].
  static String createV3Keystore(EthPrivateKey key, String password) {
    final wallet = Wallet.createNew(key, password, Random.secure());
    return wallet.toJson();
  }

  /// Decrypts an Ethereum V3 keystore JSON. Throws on wrong password.
  static EthPrivateKey decryptV3Keystore(String json, String password) {
    final wallet = Wallet.fromJson(json, password);
    return wallet.privateKey;
  }

  /// Strict decimal amount parsing to base units, matching v1 exactly.
  static BigInt parseAmount(String text, int decimals) {
    final value = text.trim();
    if (value.isEmpty) throw ArgumentError('Amount is empty.');
    if (value.startsWith('-') || value.startsWith('+')) {
      throw ArgumentError('Amount must be positive.');
    }
    if (!RegExp(r'^[0-9.]+$').hasMatch(value) || value == '.') {
      throw ArgumentError('Amount contains invalid characters.');
    }
    if (value.split('.').length > 2) {
      throw ArgumentError('Amount has more than one decimal point.');
    }
    final dot = value.indexOf('.');
    final whole = dot == -1 ? value : value.substring(0, dot);
    final frac = dot == -1 ? '' : value.substring(dot + 1);
    if (frac.length > decimals) {
      throw ArgumentError('Amount has too many decimals for this asset.');
    }
    var base = whole.isEmpty ? '0' : whole;
    base += frac;
    for (var i = frac.length; i < decimals; i++) {
      base += '0';
    }
    final trimmed = base.replaceFirst(RegExp(r'^0+'), '');
    final normalized = trimmed.isEmpty ? '0' : trimmed;
    final max =
        '115792089237316195423570985008687907853269984665640564039457584007913129639935';
    if (normalized.length > max.length ||
        (normalized.length == max.length && normalized.compareTo(max) > 0)) {
      throw ArgumentError('Amount overflows the maximum token amount.');
    }
    return BigInt.parse(normalized);
  }

  /// Formats base units as a human-readable decimal string.
  static String formatUnits(BigInt value, int decimals) {
    if (decimals <= 0) return value.toString();
    final negative = value.isNegative;
    final abs = value.abs();
    final text = abs.toString().padLeft(decimals + 1, '0');
    final whole = text.substring(0, text.length - decimals);
    var frac = text.substring(text.length - decimals);
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    final out = frac.isEmpty ? whole : '$whole.$frac';
    return negative ? '-$out' : out;
  }

  /// Formats wei as BNB/ETH with up to 18 decimals.
  static String formatEther(BigInt wei) => formatUnits(wei, 18);

  /// Short display form: 0x1234…abcd.
  static String shortAddress(String address, [int chars = 6]) {
    if (address.length <= chars * 2 + 2) return address;
    return '${address.substring(0, chars + 2)}…${address.substring(address.length - chars)}';
  }

  /// Address-poisoning hint: a lookalike that shares the first OR last 4 hex
  /// chars with a known address while being a different address. Real "drip"
  /// attacks usually hijack only one of the two — the common case is a
  /// matching suffix — so either side matching is enough to warn.
  static bool sharesAffixes(String known, String candidate) {
    if (!isValidAddress(known) || !isValidAddress(candidate)) return false;
    final a = _strip0x(known).toLowerCase();
    final b = _strip0x(candidate).toLowerCase();
    if (a == b) return false;
    return a.substring(0, 4) == b.substring(0, 4) ||
        a.substring(36) == b.substring(36);
  }

  static String _strip0x(String value) =>
      value.startsWith('0x') || value.startsWith('0X')
      ? value.substring(2)
      : value;

  /// ABI words are 32 bytes and carry an address in their low 20 bytes.
  /// Taking the whole word made every standard `transfer`/`approve` review
  /// throw "Invalid EVM address"; only the last 40 hex characters are the
  /// address.
  static String _addressFromAbiWord(String word) {
    final body = _strip0x(word);
    if (body.length < 40) {
      throw ArgumentError('ERC-20 calldata has a truncated address word');
    }
    return '0x${body.substring(body.length - 40)}';
  }

  /// A token call must target the contract the review claims it targets.
  /// `assetInfo` is attacker-supplied; without this check a request can show
  /// canonical USDT metadata while the signed call targets another token.
  static void _requireTokenContract(ColdTxRequest request) {
    final contract = request.assetInfo.contractAddress?.toLowerCase();
    if (contract == null) return;
    if (contract != request.to.toLowerCase()) {
      throw ArgumentError(
        'Token contract does not match the transaction recipient',
      );
    }
  }

  /// Encodes a non-negative BigInt as big-endian unsigned bytes.
  static Uint8List _encodeBigIntAsUnsigned(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('Value must be non-negative');
    }
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    final bytes = <int>[];
    var v = value;
    while (v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xFF)).toInt());
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  // ============================================================
  // R5: Cold Wallet Mode (§10f) — pure offline crypto functions
  // ============================================================

  /// Derives the extended public key (xpub) for the account level
  /// `m/44'/60'/0'` from a mnemonic. This can be shared with the online
  /// companion to derive addresses, but WARNING: anyone with the xpub can
  /// link ALL future addresses of this account. Default pairing uses
  /// address list instead (see [deriveAddressList]).
  static String deriveXpub({required String phrase, String passphrase = ''}) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    // Account level: m/44'/60'/0'
    final account = root.derivePath("m/44'/60'/0'");
    final xpub = account.neutered().toBase58();
    return xpub;
  }

  /// Derives a list of addresses from the seed, starting at index 0.
  /// Used for the default cold pairing (address list, not xpub).
  static List<String> deriveAddressList({
    required String phrase,
    String passphrase = '',
    int count = 20,
    int startIndex = 0,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final account = root.derivePath("m/44'/60'/0'");
    final addresses = <String>[];
    for (var i = startIndex; i < startIndex + count; i++) {
      final child = account.derivePath("0/$i");
      final key = child.privateKey;
      if (key != null) {
        final pk = EthPrivateKey(key);
        addresses.add(pk.address.eip55With0x);
      }
    }
    return addresses;
  }

  /// Derives addresses for a custom derivation path.
  /// Returns list of addresses for the given path pattern.
  static List<String> deriveAddressesCustomPath({
    required String phrase,
    String passphrase = '',
    required String pathPattern,
    int count = 20,
    int startIndex = 0,
  }) {
    final mnemonic = Mnemonic.fromSentence(
      phrase.trim(),
      Language.english,
      passphrase: passphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
    final root = BIP32.fromSeed(seed);
    final account = root.derivePath(pathPattern);
    final addresses = <String>[];
    for (var i = startIndex; i < startIndex + count; i++) {
      final child = account.derivePath("$i");
      final key = child.privateKey;
      if (key != null) {
        final pk = EthPrivateKey(key);
        addresses.add(pk.address.eip55With0x);
      }
    }
    return addresses;
  }

  /// Computes the cold pairing fingerprint over the chain and EVERY paired
  /// address, not just the first one. 16 hex chars (64 bits) plus shape codes
  /// make accidental collisions vanishingly unlikely; a substituted address
  /// list changes the fingerprint.
  static String computeFingerprint(
    String firstAddress, {
    List<String>? addresses,
    int chainId = 56,
  }) {
    final list = (addresses == null || addresses.isEmpty)
        ? <String>[firstAddress]
        : addresses;
    final canonical =
        '$chainId|${list.map((a) => _strip0x(a).toLowerCase()).join('|')}';
    final hash = crypto.sha256.convert(utf8.encode(canonical)).bytes;
    final first8 = hash.take(8).toList();
    final hex = bytesToHex(Uint8List.fromList(first8));
    final shapes = hash.take(4).map((b) => _shapeForByte(b)).join(' ');
    return '$hex $shapes';
  }

  static String _shapeForByte(int byte) {
    const shapes = ['●', '■', '▲', '◆'];
    return shapes[byte % shapes.length];
  }

  /// Parses and decodes a ColdTxRequest on the cold device.
  /// Returns a human-readable summary and validates the transaction.
  /// Throws if the transaction cannot be decoded, is expired, or is invalid.
  static ColdTxDecodeResult decodeTxRequest({
    required ColdTxRequest request,
    required List<String> coldAddresses,
    required Map<String, ColdTxAssetInfo> knownTokens,
    bool allowUnknownData = false,
  }) {
    if (request.version != 1) {
      throw ArgumentError(
        'Unsupported cold request version: ${request.version}',
      );
    }
    if (Chains.byChainId(request.chainId) == null) {
      throw ArgumentError('Unsupported chainId: ${request.chainId}');
    }

    final expiresAt = DateTime.tryParse(request.expiresAt);
    if (expiresAt == null) {
      throw ArgumentError('Request expiry is not a valid ISO-8601 timestamp');
    }
    if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
      throw ArgumentError('This signing request has expired');
    }
    final createdAt = DateTime.tryParse(request.createdAt);
    if (createdAt != null &&
        createdAt.toUtc().isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        )) {
      throw ArgumentError('Request creation time is in the future');
    }

    final fromLower = request.from.toLowerCase();
    if (!coldAddresses.any((a) => a.toLowerCase() == fromLower)) {
      throw ArgumentError('From address does not belong to this cold wallet');
    }

    final fields = _fieldsFromRequest(request);
    final dataHex = _strip0x(request.data).toLowerCase();

    String? functionName;
    String? decodedTo;
    BigInt? decodedValue;
    String? warning;

    if (dataHex.isNotEmpty) {
      if (dataHex.startsWith('a9059cbb')) {
        if (dataHex.length != 136) {
          throw ArgumentError('ERC-20 transfer calldata has the wrong length');
        }
        functionName = 'transfer';
        final toHex = _addressFromAbiWord(dataHex.substring(8, 72));
        decodedTo = checksumAddress(toHex);
        decodedValue = BigInt.parse(dataHex.substring(72, 136), radix: 16);
        if (request.assetInfo.isNative) {
          throw ArgumentError(
            'ERC-20 calldata was supplied but the asset is marked native',
          );
        }
        final contract = request.assetInfo.contractAddress?.toLowerCase();
        if (contract != null && contract != request.to.toLowerCase()) {
          throw ArgumentError(
            'Token contract does not match the transaction recipient',
          );
        }
        _requireTokenContract(request);
        if (fields.value != BigInt.zero) {
          throw ArgumentError(
            'ERC-20 transfer must not also carry a native value',
          );
        }
      } else if (dataHex.startsWith('095ea7b3')) {
        functionName = 'approve';
        if (dataHex.length != 136) {
          throw ArgumentError('ERC-20 approve calldata has the wrong length');
        }
        // Word 1 is the spender (the address that receives the allowance).
        // The old decoder ignored it, so a review could show an approval
        // amount without ever naming who could spend it.
        decodedTo = checksumAddress(
          _addressFromAbiWord(dataHex.substring(8, 72)),
        );
        decodedValue = BigInt.parse(dataHex.substring(72, 136), radix: 16);
        _requireTokenContract(request);
        warning =
            'This is an APPROVE transaction: the spender can move the '
            'allowance you grant. Verify the spender address.';
      } else if (dataHex.startsWith('39509351')) {
        functionName = 'increaseAllowance';
        if (dataHex.length != 136) {
          throw ArgumentError(
            'ERC-20 increaseAllowance calldata has the wrong length',
          );
        }
        decodedTo = checksumAddress(
          _addressFromAbiWord(dataHex.substring(8, 72)),
        );
        decodedValue = BigInt.parse(dataHex.substring(72, 136), radix: 16);
        _requireTokenContract(request);
        warning =
            'This INCREASES an existing allowance. Verify the spender and '
            'the added amount.';
      } else if (dataHex.startsWith('23b872dd')) {
        functionName = 'transferFrom';
        if (dataHex.length != 200) {
          throw ArgumentError(
            'ERC-20 transferFrom calldata has the wrong length',
          );
        }
        // transferFrom(from, to, amount): the recipient is word 2.
        decodedTo = checksumAddress(
          _addressFromAbiWord(dataHex.substring(72, 136)),
        );
        decodedValue = BigInt.parse(dataHex.substring(136, 200), radix: 16);
        _requireTokenContract(request);
        warning =
            'This is a TRANSFER-FROM: it moves tokens from another address. '
            'Verify the recipient and amount.';
      } else if (!allowUnknownData) {
        throw ArgumentError(
          'Unknown calldata (function 0x${dataHex.substring(0, 8)}). '
          'Enable "Advanced: sign unknown data" in settings to proceed.',
        );
      }
    } else {
      if (!request.assetInfo.isNative) {
        throw ArgumentError(
          'Native calldata is empty but the asset is marked as a token',
        );
      }
    }

    ColdTxAssetInfo assetInfo = request.assetInfo;
    if (!request.assetInfo.isNative &&
        request.assetInfo.contractAddress != null) {
      final addr = request.assetInfo.contractAddress!.toLowerCase();
      if (knownTokens.containsKey(addr)) {
        assetInfo = knownTokens[addr]!;
      } else {
        assetInfo = ColdTxAssetInfo(
          isNative: false,
          contractAddress: request.assetInfo.contractAddress,
          isUnknown: true,
          warning:
              'Token not recognized on this device. Verify contract address.',
        );
      }
    }

    if ((functionName == 'approve' || functionName == 'increaseAllowance') &&
        decodedValue != null) {
      final huge = BigInt.from(2).pow(255);
      if (decodedValue >= huge) {
        warning =
            '${warning != null ? '$warning; ' : ''}UNLIMITED approval — the '
            'spender can move your entire token balance';
      }
    }

    return ColdTxDecodeResult(
      chainId: request.chainId,
      from: request.from,
      to: request.to,
      value: fields.value,
      gasLimit: fields.gasLimit,
      maxFeePerGas: fields.maxFeePerGas,
      maxPriorityFeePerGas: fields.maxPriorityFeePerGas,
      nonce: request.nonce,
      data: request.data,
      functionName: functionName,
      decodedTo: decodedTo,
      decodedValue: decodedValue,
      assetInfo: assetInfo,
      totalPossibleFee: fields.maxFeePerGas * fields.gasLimit,
      expiresAt: expiresAt.toUtc(),
      warning: warning,
    );
  }

  /// Signs a transaction on the cold device.
  ///
  /// The EIP-1559 signing payload is built by [ColdTxCodec]; the signature is
  /// over `keccak256(0x02 || rlp([...]))` exactly once.  The raw transaction
  /// is built from the same fields, so the signed bytes and the digest can
  /// never drift apart.
  static ColdTxSignature signTransaction({
    required String phrase,
    required ColdTxRequest request,
    String passphrase = '',
    String path = defaultPath,
  }) {
    final privateKey = derivePrivateKey(
      phrase: phrase,
      passphrase: passphrase,
      path: path,
    );
    return signTransactionWithKey(privateKey: privateKey, request: request);
  }

  /// Signs a cold request with an already-derived private key.
  ///
  /// This is the private-key-only path: a wallet imported as a raw key can
  /// still export a pairing and sign offline without pretending it has a
  /// recovery phrase. The request fields and `from` address are checked in
  /// exactly the same way as the phrase path.
  static ColdTxSignature signTransactionWithKey({
    required EthPrivateKey privateKey,
    required ColdTxRequest request,
  }) {
    if (request.version != 1) {
      throw ArgumentError(
        'Unsupported cold request version: ${request.version}',
      );
    }
    if (request.id == null || request.id!.isEmpty) {
      throw ArgumentError('Cold request is missing its unique ID');
    }
    if (Chains.byChainId(request.chainId) == null) {
      throw ArgumentError('Unsupported chainId: ${request.chainId}');
    }
    final expiresAt = DateTime.tryParse(request.expiresAt);
    if (expiresAt == null ||
        DateTime.now().toUtc().isAfter(expiresAt.toUtc())) {
      throw ArgumentError('This signing request has expired');
    }

    final fields = _fieldsFromRequest(request);
    if (privateKey.address.eip55With0x.toLowerCase() !=
        request.from.toLowerCase()) {
      throw ArgumentError(
        'Private key does not match the "from" address in the request',
      );
    }

    final payload = fields.unsignedPayload();
    final signature = privateKey.signToEcSignature(
      payload,
      chainId: request.chainId,
      isEIP1559: true,
    );
    final recoveryId = signature.v;
    if (recoveryId < 0 || recoveryId > 3) {
      throw StateError('Invalid ECDSA recovery ID: $recoveryId');
    }
    final yParity = recoveryId & 1;
    final raw = ColdTxCodec.signedPayload(
      fields,
      yParity: yParity,
      r: signature.r,
      s: signature.s,
    );
    final rawHex = bytesToHex(raw, include0x: true, padToEvenLength: true);
    final txHash = bytesToHex(
      ColdTxCodec.digestOfPayload(raw),
      include0x: true,
    );

    return ColdTxSignature(
      version: 1,
      requestId: request.id!,
      requestHash: fields.signingDigestHex,
      chainId: request.chainId,
      from: privateKey.address.eip55With0x,
      r: _hex32(signature.r),
      s: _hex32(signature.s),
      v: '0x${recoveryId.toRadixString(16)}',
      yParity: yParity,
      signedTxHash: txHash,
      signedAt: DateTime.now().toUtc().toIso8601String(),
      rawSignedTx: rawHex,
    );
  }

  /// Strictly verifies a cold signature on the online companion.
  ///
  /// It reconstructs the unsigned digest, parses the supplied raw transaction,
  /// compares every field, checks r/s/yParity and the transaction hash, and
  /// finally recovers the signer.  Any mismatch fails closed.
  static ColdVerifyResult verifyColdSignatureDetailed({
    required ColdTxRequest request,
    required ColdTxSignature signature,
    required String expectedFrom,
  }) {
    try {
      if (request.version != 1 || signature.version != 1) {
        return const ColdVerifyResult.fail('Unsupported protocol version');
      }
      if (request.id == null || request.id!.isEmpty) {
        return const ColdVerifyResult.fail('Request has no unique ID');
      }
      if (signature.requestId != request.id) {
        return const ColdVerifyResult.fail('Request ID mismatch');
      }
      if (signature.chainId != request.chainId) {
        return const ColdVerifyResult.fail('Chain ID mismatch');
      }
      if (request.from.toLowerCase() != expectedFrom.toLowerCase() ||
          signature.from.toLowerCase() != expectedFrom.toLowerCase()) {
        return const ColdVerifyResult.fail('Signer address mismatch');
      }
      if (signature.rawSignedTx == null ||
          signature.rawSignedTx!.trim().isEmpty) {
        return const ColdVerifyResult.fail('Raw signed transaction is missing');
      }

      final fields = _fieldsFromRequest(request);
      final digest = fields.signingDigest();
      final digestHex = bytesToHex(digest, include0x: true);
      if (signature.requestHash == null ||
          signature.requestHash!.toLowerCase() != digestHex.toLowerCase()) {
        return const ColdVerifyResult.fail(
          'Request hash does not match the transaction',
        );
      }

      final raw = _parseHexBytes(signature.rawSignedTx!, 'rawSignedTx');
      final parsed = ColdTxCodec.parseSigned(raw);
      if (!parsed.fields.sameTransaction(fields)) {
        return const ColdVerifyResult.fail(
          'Raw transaction fields do not match the request',
        );
      }

      if (signature.yParity == null || signature.yParity != parsed.yParity) {
        return const ColdVerifyResult.fail('yParity mismatch');
      }
      final v = _parseHexInt(signature.v, 'v');
      if (v < 0 || v > 3 || (v & 1) != parsed.yParity) {
        return const ColdVerifyResult.fail(
          'Recovery ID is invalid or does not match yParity',
        );
      }
      final r = _parseHexBigInt(signature.r, 'r');
      final s = _parseHexBigInt(signature.s, 's');
      if (r != parsed.r || s != parsed.s) {
        return const ColdVerifyResult.fail('Signature r/s mismatch');
      }
      if (signature.signedTxHash.toLowerCase() != parsed.hash.toLowerCase()) {
        return const ColdVerifyResult.fail(
          'Signed transaction hash does not match the raw bytes',
        );
      }

      final matches = <String>[];
      for (final recoveryId in {parsed.yParity, parsed.yParity + 2}) {
        try {
          final recoveredPublicKey = ecRecover(
            digest,
            MsgSignature(parsed.r, parsed.s, 27 + recoveryId),
          );
          final address = EthereumAddress(
            publicKeyToAddress(recoveredPublicKey),
          ).eip55With0x;
          if (address.toLowerCase() == expectedFrom.toLowerCase()) {
            matches.add(address);
          }
        } catch (_) {
          // A wrong recovery candidate is expected to fail; try the next one.
        }
      }
      if (matches.length != 1) {
        return const ColdVerifyResult.fail(
          'Signature does not recover to exactly one expected signer',
        );
      }

      return ColdVerifyResult.ok(
        rawSignedTx: parsed.rawHex,
        txHash: parsed.hash,
        from: matches.single,
      );
    } catch (error) {
      return ColdVerifyResult.fail('Verification failed: $error');
    }
  }

  static bool verifyColdSignature({
    required ColdTxRequest request,
    required ColdTxSignature signature,
    required String expectedFrom,
  }) => verifyColdSignatureDetailed(
    request: request,
    signature: signature,
    expectedFrom: expectedFrom,
  ).ok;

  static ColdTxFields _fieldsFromRequest(ColdTxRequest request) {
    final fields = ColdTxFields(
      chainId: request.chainId,
      nonce: BigInt.from(request.nonce),
      maxPriorityFeePerGas: _parseHexBigInt(
        request.maxPriorityFeePerGas,
        'maxPriorityFeePerGas',
      ),
      maxFeePerGas: _parseHexBigInt(request.maxFeePerGas, 'maxFeePerGas'),
      gasLimit: _parseHexBigInt(request.gasLimit, 'gasLimit'),
      to: request.to,
      value: _parseHexBigInt(request.value, 'value'),
      data: _parseHexBytes(request.data, 'data'),
      accessList: const [],
    );
    ColdTxCodec.validateFields(
      chainId: fields.chainId,
      nonce: fields.nonce,
      maxPriorityFeePerGas: fields.maxPriorityFeePerGas,
      maxFeePerGas: fields.maxFeePerGas,
      gasLimit: fields.gasLimit,
      to: fields.to,
      value: fields.value,
      data: fields.data,
      accessList: fields.accessList,
    );
    return fields;
  }

  static BigInt _parseHexBigInt(String value, String field) {
    final clean = _strip0x(value.trim());
    if (clean.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw ArgumentError('Invalid hex value for $field');
    }
    return BigInt.parse(clean, radix: 16);
  }

  static int _parseHexInt(String value, String field) {
    final parsed = _parseHexBigInt(value, field);
    if (parsed > BigInt.from(0x7fffffff)) {
      throw ArgumentError('$field is too large');
    }
    return parsed.toInt();
  }

  static Uint8List _parseHexBytes(String value, String field) {
    final clean = _strip0x(value.trim());
    if (clean.isEmpty) return Uint8List(0);
    if (clean.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw ArgumentError('Invalid hex bytes for $field');
    }
    return Uint8List.fromList(hexToBytes(clean));
  }

  static String _hex32(BigInt value) =>
      '0x${value.toRadixString(16).padLeft(64, '0')}';

  static String formatFee(BigInt feeWei) => formatEther(feeWei);
}

/// Result of strict cold-signature verification.  [reason] is safe to show to
/// the user; it never contains secret material.
class ColdVerifyResult {
  const ColdVerifyResult._({
    required this.ok,
    required this.reason,
    this.rawSignedTx,
    this.txHash,
    this.from,
  });

  const ColdVerifyResult.fail(String reason)
    : this._(ok: false, reason: reason);

  factory ColdVerifyResult.ok({
    required String rawSignedTx,
    required String txHash,
    required String from,
  }) => ColdVerifyResult._(
    ok: true,
    reason: 'Signature matches the exact requested transaction',
    rawSignedTx: rawSignedTx,
    txHash: txHash,
    from: from,
  );

  final bool ok;
  final String reason;
  final String? rawSignedTx;
  final String? txHash;
  final String? from;
}

/// One place that decides what may NEVER reach the system clipboard through
/// the ordinary copy helper. The explicit reveal/copy dialogs in the wallet
/// screen use their own confirmation and a short auto-clear timer instead.
class ClipboardGuard {
  const ClipboardGuard._();

  static bool secretFree(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (_looksLikeMnemonic(t)) return false;
    // Bare 64-hex keys. A 0x-prefixed 64-hex string is ambiguous (private
    // key vs transaction hash), so it stays copyable for public hashes; the
    // copy helper below additionally refuses secret-labelled copies and the
    // reveal dialogs always require an explicit warning.
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(t)) return false;
    // Bitcoin/Ethereum WIF (base58check, version byte 0x80).
    if (RegExp(r'^[5KL][1-9A-HJ-NP-Za-km-z]{50,51}$').hasMatch(t)) {
      return false;
    }
    // Web3 v3 keystore JSON.
    if (t.startsWith('{') &&
        t.contains('"crypto"') &&
        t.contains('"ciphertext"')) {
      return false;
    }
    return true;
  }

  static bool _looksLikeMnemonic(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    const lengths = <int>{12, 15, 18, 21, 24};
    if (!lengths.contains(words.length)) return false;
    final alpha = RegExp(r'^[a-z]{3,12}$');
    return words.every(alpha.hasMatch);
  }
}
