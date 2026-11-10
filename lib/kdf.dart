import 'dart:ffi';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:dargon2_core/dargon2_core.dart';

/// One Argon2id implementation, with an explicit, observable backend.
///
/// The production desktop/mobile builds ship the reference C implementation
/// (`libargon2.so` / `argon2.dll` / the macOS dylib).  `flutter test` runs on
/// `flutter_tester`, which does not bundle it, so the same class falls back to
/// the system shared library and finally to the pure-Dart implementation from
/// `package:cryptography`.  All three are Argon2id v1.3 with identical
/// parameters; the fallback is a performance path, never a parameter change.
class Argon2Kdf {
  Argon2Kdf._();

  static const int keyLength = 32;

  static DArgon2Native? _native;
  static bool _nativeTried = false;

  /// `native`, `system`, or `dart`. Diagnostics only; contains no secrets.
  static String lastBackend = 'uninitialised';

  static DArgon2Native? _nativeOrNull() {
    if (_nativeTried) return _native;
    _nativeTried = true;
    try {
      _native = DArgon2Native(_Argon2LibraryLoader());
      return _native;
    } catch (_) {
      _native = null;
      return null;
    }
  }

  /// Derives [keyLength] bytes with Argon2id v1.3.
  ///
  /// [memoryKiB] is in KiB, matching RFC 9106 and the `cryptography` package.
  static Future<List<int>> derive({
    required List<int> password,
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
  }) async {
    final native = _nativeOrNull();
    if (native != null) {
      try {
        final result = await native.hashPasswordBytes(
          password,
          salt: Salt(salt),
          iterations: iterations,
          memory: memoryKiB,
          parallelism: parallelism,
          length: keyLength,
          type: Argon2Type.id,
          version: Argon2Version.V13,
        );
        if (result.rawBytes.length == keyLength) {
          lastBackend = Argon2Kdf._nativeLoadPath == null
              ? 'native'
              : 'system (${Argon2Kdf._nativeLoadPath})';
          return List<int>.from(result.rawBytes);
        }
      } catch (_) {
        // Fall through to the independent pure-Dart implementation.  This is
        // not a security downgrade: the algorithm and parameters are fixed.
        _native = null;
      }
    }
    lastBackend = 'dart';
    final argon = cryptography.Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: keyLength,
    );
    final derived = await argon.deriveKey(
      secretKey: cryptography.SecretKey(password),
      nonce: salt,
    );
    return derived.extractBytes();
  }

  static String? _nativeLoadPath;

  /// Test/diagnostic hook: force a fresh backend decision.
  static void resetForTest() {
    _native = null;
    _nativeTried = false;
    _nativeLoadPath = null;
    lastBackend = 'uninitialised';
  }
}

/// Loads the reference Argon2 library from the Flutter bundle first, then the
/// platform's normal search path.  Fails with a clear error instead of
/// returning a half-initialised FFI binding.
class _Argon2LibraryLoader implements LibLoader {
  @override
  DynamicLibrary loadLib() {
    final candidates = <String>[
      if (Platform.isAndroid) ...['libargon2-arm.so', 'libargon2.so'],
      if (Platform.isLinux) ...[
        '${File(Platform.resolvedExecutable).parent.path}/lib/libargon2.so',
        'libargon2.so.1',
        'libargon2.so',
      ],
      if (Platform.isMacOS) ...[
        '${File(Platform.resolvedExecutable).parent.path}/../Frameworks/libargon2.1.dylib',
        'libargon2.1.dylib',
        'libargon2.dylib',
      ],
      if (Platform.isWindows) 'argon2.dll',
    ];
    for (final candidate in candidates) {
      try {
        final library = DynamicLibrary.open(candidate);
        Argon2Kdf._nativeLoadPath = candidate;
        return library;
      } catch (_) {
        // Try the next location.
      }
    }
    throw UnsupportedError('Argon2 native library is not available');
  }

  @override
  String getPath() => Argon2Kdf._nativeLoadPath ?? 'argon2';
}
