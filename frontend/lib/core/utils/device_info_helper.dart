import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoHelper {
  DeviceInfoHelper._();

  static Future<String> deviceName() async {
    if (kIsWeb) return 'ShopXY Web';
    try {
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await plugin.androidInfo;
          final name = '${a.manufacturer} ${a.model}'.trim();
          return name.isEmpty ? 'Android device' : name;
        case TargetPlatform.iOS:
          final i = await plugin.iosInfo;
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
      return 'ShopXY (${Platform.operatingSystem})';
    }
  }
}
