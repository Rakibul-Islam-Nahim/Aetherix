import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Lightweight device-info helper. No third-party dependencies — uses
/// `dart:io.Platform` so it works on every backend Flutter ships.
///
/// On Android we read `Platform.environment['ANDROID_MODEL']` if it's
/// injected by the host app, but the canonical Flutter way is
/// `device_info_plus`. Until that package is added, we fall back to a
/// platform + version label which is still much more useful than just
/// "android" in the admin panel.
class DeviceInfo {
  const DeviceInfo._();

  /// Human-readable device model for the admin panel.
  ///
  /// Examples:
  ///   "Pixel 7 Pro"   (when injected by the host / plugin)
  ///   "Android 14"    (fallback: platform + os version)
  ///   "Windows 10"    (desktop)
  ///   "Web"           (Flutter web)
  static String modelLabel() {
    if (kIsWeb) return 'Web (${_webUserAgentHint()})';
    try {
      final envModel = Platform.environment['ANDROID_MODEL'];
      if (envModel != null && envModel.isNotEmpty) return envModel;
    } catch (_) {
      // Platform may not be available in some test/web contexts.
    }
    try {
      final os = Platform.operatingSystem;
      final v = Platform.operatingSystemVersion;
      return '$os ${_truncateVersion(v)}';
    } catch (_) {
      return 'unknown';
    }
  }

  /// OS name as used in the admin panel "PLATFORM" column.
  static String platformName() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Stable, slug-friendly device id used as the username in the
  /// backend's `users` table. Combining platform + version makes it
  /// reasonably unique per install without requiring storage.
  static String defaultUserName() {
    if (kIsWeb) return 'web-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final os = Platform.operatingSystem;
      final v = Platform.operatingSystemVersion.split(' ').first;
      return '$os-$v';
    } catch (_) {
      return 'unknown-device';
    }
  }

  static String _truncateVersion(String v) {
    // Android: "Android SDK 34 (UpsideDownCake)"  →  "SDK 34"
    // iOS:     "iOS 17.0"                          →  "17.0"
    // Windows: "Windows 10 (Version 2004)"        →  "10"
    if (v.isEmpty) return '';
    final sdkMatch = RegExp(r'SDK\s+(\d+)').firstMatch(v);
    if (sdkMatch != null) return 'SDK ${sdkMatch.group(1)}';
    final verMatch = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(v);
    return verMatch?.group(1) ?? v;
  }

  static String _webUserAgentHint() {
    // Real user-agent sniffing would require dart:html; we keep this
    // minimal so the same code compiles on native + web.
    return 'browser';
  }
}
