import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final dioProvider = Provider<Dio>((ref) {
  final base = ref.watch(apiBaseUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  // Bearer token is added by an interceptor that reads from secure storage.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // TODO: load token from flutter_secure_storage once added.
        handler.next(options);
      },
    ),
  );
  return dio;
});