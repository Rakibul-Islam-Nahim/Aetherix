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
///
/// Uses ``ref.read`` (not ``ref.watch``) for the AuthService so this
/// provider runs once and does not re-run whenever the AuthService
/// itself is rebuilt (which used to cause an infinite refetch loop
/// with the new Riverpod family semantics).
final authBootstrapProvider = FutureProvider<void>((ref) async {
  final auth = ref.read(authServiceProvider);
  await auth.ensureToken(
    deviceName: 'nahim-phone',
    devicePlatform: 'android',
  );
});