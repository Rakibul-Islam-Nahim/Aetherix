import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_config.dart';
import 'admin_session.dart';

/// Strips a trailing ``/api/v1`` from the public base URL so admin
/// calls hit the server root.
///
/// The user-facing API is mounted at ``/api/v1`` but admin routes
/// (``/admin/*``) live at the root — historically the admin client
/// was mistakenly built on top of the public base, which produced
/// 405s when the request reached ``/api/v1/admin/login``.
String _adminBase(String publicBase) {
  if (publicBase.endsWith('/api/v1')) {
    return publicBase.substring(0, publicBase.length - '/api/v1'.length);
  }
  if (publicBase.endsWith('/api/v1/')) {
    return publicBase.substring(0, publicBase.length - '/api/v1/'.length);
  }
  return publicBase;
}

/// One device row, as returned by GET /admin/devices.
class AdminDevice {
  const AdminDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.model,
    required this.userId,
    required this.username,
    required this.userBlocked,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String platform;
  final String? model;
  final int userId;
  final String username;
  final bool userBlocked;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  /// Best display string for the "device" column in the admin table.
  String get displayName =>
      (model == null || model!.isEmpty) ? name : '$name  ·  $model';

  factory AdminDevice.fromJson(Map<String, dynamic> j) => AdminDevice(
        id: j['id'] as int,
        name: j['name'] as String,
        platform: j['platform'] as String,
        model: j['model'] as String?,
        userId: j['user_id'] as int,
        username: j['username'] as String,
        userBlocked: j['user_blocked'] as bool,
        lastSeenAt: j['last_seen_at'] == null
            ? null
            : DateTime.parse(j['last_seen_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Dio wrapper for the /admin/* endpoints.
///
/// A fresh Dio is built per request so the latest [AdminSession] token
/// is always picked up. The base URL follows whatever the user has
/// set in `apiBaseUrlProvider`.
class AdminApi {
  AdminApi(this._ref);

  final Ref _ref;

  Dio _build() {
    final base = _adminBase(_ref.read(apiBaseUrlProvider));
    final session = _ref.read(adminSessionProvider);
    return Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          if (session.token != null) 'Authorization': 'Bearer ${session.token}',
        },
      ),
    );
  }

  /// Hits /admin/login with the password. On success, returns the
  /// minted admin token + ttl.
  Future<({String token, int expiresInMinutes})> login(String password) async {
    final r = await _build().post<Map<String, dynamic>>(
      '/admin/login',
      data: {'password': password},
    );
    final body = r.data!;
    return (
      token: body['access_token'] as String,
      expiresInMinutes: body['expires_in_minutes'] as int,
    );
  }

  Future<List<AdminDevice>> listDevices() async {
    final r = await _build().get<List<dynamic>>('/admin/devices');
    return (r.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(AdminDevice.fromJson)
        .toList();
  }

  Future<AdminDevice> block(int deviceId) async {
    final r = await _build().post<Map<String, dynamic>>(
      '/admin/devices/$deviceId/block',
    );
    return AdminDevice.fromJson(r.data!);
  }

  Future<AdminDevice> unblock(int deviceId) async {
    final r = await _build().post<Map<String, dynamic>>(
      '/admin/devices/$deviceId/unblock',
    );
    return AdminDevice.fromJson(r.data!);
  }

  Future<void> deleteDevice(int deviceId) async {
    await _build().delete<void>('/admin/devices/$deviceId');
  }
}

final adminApiProvider = Provider<AdminApi>(AdminApi.new);
