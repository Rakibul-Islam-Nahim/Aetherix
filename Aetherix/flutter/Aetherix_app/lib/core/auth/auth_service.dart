import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_config.dart';
import 'token_store.dart';

class AuthService {
  AuthService(this._dio, this._store);
  final Dio _dio;
  final TokenStore _store;

  /// Returns a usable JWT, registering a fresh device on first call.
  Future<String> ensureToken({
    required String deviceName,
    String devicePlatform = 'android',
  }) async {
    final cached = await _store.read();
    if (cached != null && cached.isNotEmpty) return cached;

    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register-device',
      data: {'name': deviceName, 'platform': devicePlatform},
    );
    final body = r.data!;
    final token = body['access_token'] as String;
    final userId = body['user_id'] as int;
    final minutes = body['expires_in_minutes'] as int;
    await _store.write(
      token: token,
      userId: userId,
      expiresInMinutes: minutes,
    );
    return token;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioProvider), ref.watch(tokenStoreProvider));
});

/// One-shot bootstrap: ensures the device is registered before the UI
/// makes any other API call. Calls complete on the first frame.
final authBootstrapProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authServiceProvider);
  await auth.ensureToken(
    deviceName: 'nahim-phone',
    devicePlatform: 'android',
  );
});