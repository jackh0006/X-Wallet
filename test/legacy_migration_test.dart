import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/storage.dart';

void main() {
  test(
    'legacy app directory is copied without deleting the original',
    () async {
      final root = await Directory.systemTemp.createTemp('x-wallet-migrate-');
      final legacy = Directory('${root.path}/legacy');
      final current = Directory('${root.path}/current');
      await legacy.create();
      await File('${legacy.path}/bnb-wallet-vault.bnb').writeAsString('vault');
      await File('${legacy.path}/device_secret_v2.drawer')
          .writeAsString('secret');
      await File('${legacy.path}/shared_preferences.json').writeAsString('{}');
      await File('${legacy.path}/bnb-wallet-log.bin').writeAsString('log');
      await File('${legacy.path}/.bnb-wallet-storage.lock').writeAsString('');

      final copied = await AppStorage.migrateLegacyDirectoriesForTest(
        currentPath: current.path,
        legacyPaths: [legacy.path],
      );

      expect(copied, isTrue);
      expect(
        await File('${current.path}/bnb-wallet-vault.bnb').readAsString(),
        'vault',
      );
      expect(
        await File('${current.path}/device_secret_v2.drawer').readAsString(),
        'secret',
      );
      expect(
        await File('${current.path}/shared_preferences.json').readAsString(),
        '{}',
      );
      expect(
        await File('${current.path}/.bnb-wallet-storage.lock').exists(),
        isFalse,
      );
      expect(
        await File('${legacy.path}/bnb-wallet-vault.bnb').exists(),
        isTrue,
      );

      if (Platform.isLinux) {
        final mode =
            (await File(
              '${current.path}/device_secret_v2.drawer',
            ).stat()).mode &
            511;
        expect(mode, 384);
      }

      await root.delete(recursive: true);
    },
  );

  test('a current vault is never overwritten by a legacy vault', () async {
    final root = await Directory.systemTemp.createTemp('x-wallet-migrate-');
    final legacy = Directory('${root.path}/legacy');
    final current = Directory('${root.path}/current');
    await legacy.create();
    await current.create();
    await File('${legacy.path}/bnb-wallet-vault.bnb').writeAsString('legacy');
    await File('${legacy.path}/device_secret_v2.drawer')
        .writeAsString('secret');
    await File('${current.path}/bnb-wallet-vault.bnb').writeAsString('current');

    await AppStorage.migrateLegacyDirectoriesForTest(
      currentPath: current.path,
      legacyPaths: [legacy.path],
    );

    expect(
      await File('${current.path}/bnb-wallet-vault.bnb').readAsString(),
      'current',
    );
    expect(
      await File('${current.path}/device_secret_v2.drawer').readAsString(),
      'secret',
    );

    await root.delete(recursive: true);
  });
}
