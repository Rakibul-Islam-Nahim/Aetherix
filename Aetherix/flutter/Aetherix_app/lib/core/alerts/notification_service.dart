import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps `flutter_local_notifications` so the rest of the app doesn't
/// have to know about plugin details.
///
/// Currently in-app only: the user opens the app, new articles land
/// in the feed, we fire a local notification. Boot-resilient
/// background polling is intentionally out of scope (see plan).
class NotificationService {
  NotificationService();

  static const _channelId = 'aetherix_alerts';
  static const _channelName = 'Aetherix Alerts';
  static const _channelDescription =
      'New articles that match your alert preferences.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;

  bool get permissionGranted => _permissionGranted;

  /// Idempotent — safe to call from `initState` of any widget.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Create the channel up front. On Android 8+ notifications fail
    // silently without a registered channel.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    // Ask for permission proactively on first launch. We don't surface
    // a UI prompt here — SettingsPage handles that. This just primes
    // the plugin state.
    _permissionGranted = await _checkPermission();
  }

  /// Returns true if notifications are allowed at the OS level.
  /// Combines the runtime permission (Android 13+) and the channel
  /// enable state (Android 8+).
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    // `requestNotificationsPermission` is a no-op (returns true) on
    // Android < 13; on 13+ it shows the system dialog and returns
    // the user's choice.
    final granted = await androidPlugin?.requestNotificationsPermission() ?? true;
    _permissionGranted = granted ?? false;
    return _permissionGranted;
  }

  Future<bool> _checkPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.areNotificationsEnabled() ?? true;
    _permissionGranted = granted ?? false;
    return _permissionGranted;
  }

  /// Fire a notification for a new article. No-op if permission is
  /// denied — caller should have checked `permissionGranted` first.
  Future<void> showArticleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_permissionGranted) {
      // Try to refresh — maybe the user granted it in system settings
      // since we last checked.
      _permissionGranted = await _checkPermission();
      if (!_permissionGranted) return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancels a previously shown notification by id.
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancels every notification we have shown.
  Future<void> cancelAll() => _plugin.cancelAll();
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
