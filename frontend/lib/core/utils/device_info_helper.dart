import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Resolves a human-readable device name sent to the backend as the
/// `X-Device-Name` header, so the "Devices & sessions" screen can show
/// "Nikhil's iPhone" / "Pixel 7" instead of a generic "ShopXY app".
class DeviceInfoHelper {
  DeviceInfoHelper._();

  static Future<String> deviceName() async {
    if (kIsWeb) return 'ShopXY Web';
    try {
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await plugin.androidInfo;
          // manufacturer + marketing model, e.g. "Google Pixel 7".
          final name = '${a.manufacturer} ${a.model}'.trim();
          return name.isEmpty ? 'Android device' : name;
        case TargetPlatform.iOS:
          final i = await plugin.iosInfo;
          // `.name` is the user-set device name ("Nikhil's iPhone").
          return i.name.isNotEmpty ? i.name : 'iPhone';
        case TargetPlatform.macOS:
          final m = await plugin.macOsInfo;
          return m.computerName.isNotEmpty ? m.computerName : 'Mac';
        case TargetPlatform.windows:
          final w = await plugin.windowsInfo;
          return w.computerName.isNotEmpty ? w.computerName : 'Windows PC';
        default:
          return 'ShopXY (${defaultTargetPlatform.name})';
      }
    } catch (_) {
      // Best-effort — a device-info failure must not block the app.
      return 'ShopXY (${Platform.operatingSystem})';
    }
  }
}
