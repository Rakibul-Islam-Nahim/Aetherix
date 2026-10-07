import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/token_store.dart';

/// Reads the API base URL from a dart-define injected at build time.
/// On the VPS we build with:
///   flutter build apk --dart-define=AETHERIX_API_BASE_URL=https://...
final apiBaseUrlProvider = Provider<String>((ref) {
  const fromDefine = String.fromEnvironment(
    'AETHERIX_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  return fromDefine;
});

/// SharedPreferences singleton initialised on app start.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope.overrides');
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(sharedPrefsProvider));
});

final dioProvider = Provider<Dio>((ref) {
  final base = ref.watch(apiBaseUrlProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  // Bearer token is added by an interceptor that reads from TokenStore.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Don't attach a token to the register-device endpoint itself.
        if (!options.path.endsWith('/auth/register-device')) {
          final token = await tokenStore.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ),
  );
  return dio;
});