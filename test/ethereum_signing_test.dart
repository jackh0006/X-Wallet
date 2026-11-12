import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  // Canonical EIP-155 example from the specification.
  const eip155Raw =
      '0xf86c098504a817c800825208943535353535353535353535353535353535353535'
      '880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff'
      '63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b2'
      '97fb1966a3b6d83';
  final key = EthPrivateKey.fromHex(
    '0x4646464646464646464646464646464646464646464646464646464646464646',
  );

  test('Ethereum legacy signing matches the EIP-155 example', () async {
    final client = Web3Client(
      'http://127.0.0.1:8545',
      MockClient((_) async => http.Response('{}', 500)),
    );
    final signed = await client.signTransaction(
      key,
      Transaction(
        to: EthereumAddress.fromHex(
          '0x3535353535353535353535353535353535353535',
        ),
        value: EtherAmount.inWei(BigInt.parse('1000000000000000000')),
        gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
        maxGas: 21000,
        nonce: 9,
      ),
      chainId: 1,
    );
    expect(
      bytesToHex(signed, include0x: true, padToEvenLength: true),
      eip155Raw,
    );
  });

  test(
    'the same transaction on Sepolia produces different signed bytes',
    () async {
      final client = Web3Client(
        'http://127.0.0.1:8545',
        MockClient((_) async => http.Response('{}', 500)),
      );
      final tx = Transaction(
        to: EthereumAddress.fromHex(
          '0x3535353535353535353535353535353535353535',
        ),
        value: EtherAmount.inWei(BigInt.parse('1000000000000000000')),
        gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
        maxGas: 21000,
        nonce: 0,
      );
      final mainnet = await client.signTransaction(key, tx, chainId: 1);
      final sepolia = await client.signTransaction(key, tx, chainId: 11155111);
      expect(
        bytesToHex(mainnet, include0x: true),
        isNot(bytesToHex(sepolia, include0x: true)),
      );
    },
  );

  test('cold signer accepts Ethereum chain 1 and binds the chain ID', () {
    final from = key.address.eip55With0x;
    final request = ColdTxRequest(
      version: 1,
      chainId: 1,
      from: from,
      to: '0x3535353535353535353535353535353535353535',
      value: '0xde0b6b3a7640000',
      gasLimit: '0x5208',
      maxFeePerGas: '0x4a817c800',
      maxPriorityFeePerGas: '0x4a817c800',
      nonce: 0,
      data: '0x',
      assetInfo: const ColdTxAssetInfo(isNative: true, symbol: 'ETH'),
      expiresAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      id: 'eth-chain-1-test',
    );

    final signed = WalletCore.signTransactionWithKey(
      privateKey: key,
      request: request,
    );
    expect(signed.chainId, 1);
    expect(signed.rawSignedTx, startsWith('0x02'));
    expect(signed.signedTxHash, startsWith('0x'));

    final wrongChain = ColdTxRequest(
      version: 1,
      chainId: 56,
      from: from,
      to: request.to,
      value: request.value,
      gasLimit: request.gasLimit,
      maxFeePerGas: request.maxFeePerGas,
      maxPriorityFeePerGas: request.maxPriorityFeePerGas,
      nonce: request.nonce,
      data: request.data,
      assetInfo: request.assetInfo,
      expiresAt: request.expiresAt,
      createdAt: request.createdAt,
      id: 'eth-chain-56-test',
    );
    final other = WalletCore.signTransactionWithKey(
      privateKey: key,
      request: wrongChain,
    );
    expect(other.signedTxHash, isNot(signed.signedTxHash));
  });
}
