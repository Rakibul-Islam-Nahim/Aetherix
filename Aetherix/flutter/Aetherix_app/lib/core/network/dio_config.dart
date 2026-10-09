import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/token_store.dart';
import '../ui/toast.dart';

/// Reads the API base URL.
///
/// Priority:
///   1. dart-define `AETHERIX_API_BASE_URL` (set per build)
///   2. Saved override from the in-app settings screen
///   3. Platform-aware default (web → localhost, Android → 10.0.2.2, else localhost)
///
/// You can change it at runtime via `apiBaseUrlProvider`'s notifier.
class ApiBaseUrlController extends StateNotifier<String> {
  ApiBaseUrlController(this._prefs, String initial)
      : super(initial.isEmpty ? _defaultBaseUrl() : initial);

  final SharedPreferences _prefs;
  static const _key = 'aetherix.api_base_url';

  Future<void> set(String url) async {
    state = url;
    await _prefs.setString(_key, url);
  }

  String loadSaved() => _prefs.getString(_key) ?? '';
}

String _defaultBaseUrl() {
  // Production build for the VPS:
  //   flutter build web --dart-define=AETHERIX_API_BASE_URL=https://...
  // For dev:
  //   web   → http://localhost:8000/api/v1   (run backend on the same host)
  //   android emulator → http://10.0.2.2:8000/api/v1
  //   other → http://localhost:8000/api/v1
  if (kIsWeb) return 'http://localhost:8000/api/v1';
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
  } catch (_) {
    // Platform is unavailable on web; fall through.
  }
  return 'http://localhost:8000/api/v1';
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope.overrides');
});

final apiBaseUrlProvider = StateNotifierProvider<ApiBaseUrlController, String>(
  (ref) {
    const fromDefine = String.fromEnvironment(
      'AETHERIX_API_BASE_URL',
      defaultValue: '',
    );
    final prefs = ref.watch(sharedPrefsProvider);
    final saved = prefs.getString(ApiBaseUrlController._key) ?? '';
    final initial = fromDefine.isNotEmpty
        ? fromDefine
        : (saved.isNotEmpty ? saved : _defaultBaseUrl());
    return ApiBaseUrlController(prefs, initial);
  },
);

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
  // Failures are surfaced to the global toast surface; the request is
  // still rejected so the caller can render its own inline UI.
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
      onError: (e, handler) {
        // De-dupe by method+path+type so a single broken endpoint
        // doesn't fill the screen with the same banner.
        final id = '${e.requestOptions.method} ${e.requestOptions.path}';
        try {
          showDioErrorToast(ref, e, id: id);
        } catch (_) {
          // Provider may have been disposed during shutdown; ignore.
        }
        handler.next(e);
      },
    ),
  );
  return dio;
});