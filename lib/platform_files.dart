import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Android storage-access-framework bridge for backup and cold-wallet files.
///
/// On desktop the existing file paths are used. Android has no user-visible
/// app temp directory, so the user chooses the destination/source with the
/// system file picker. The app never needs broad storage permission.
class PlatformFiles {
  PlatformFiles._();

  static const MethodChannel _channel = MethodChannel(
    'com.jackh0006.xwallet/files',
  );

  static bool get isAndroid => Platform.isAndroid;

  static Future<bool> saveBytes(String name, Uint8List bytes) async {
    if (!isAndroid) return false;
    final saved = await _channel.invokeMethod<bool>('saveBytes', {
      'name': name,
      'bytes': bytes,
    });
    return saved == true;
  }

  static Future<Uint8List?> openBytes() async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<Uint8List>('openBytes');
  }

  static Future<bool> saveText(String name, String text) =>
      saveBytes(name, Uint8List.fromList(utf8.encode(text)));

  static Future<String?> openText() async {
    final bytes = await openBytes();
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }
}
