import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Severity of a toast. Drives the banner's color and icon.
enum ToastKind { error, success, warning, info }

/// One in-app banner message. The overlay handles all animation and
/// dismissal — callers just construct a Toast and post it.
@immutable
class Toast {
  const Toast({
    required this.title,
    required this.kind,
    this.body,
    this.duration = const Duration(seconds: 3),
    this.id,
  });

  /// Short, all-caps title (e.g. "NETWORK ERROR").
  final String title;

  /// Optional secondary line with more detail (server response, URL, etc.).
  final String? body;

  final ToastKind kind;

  /// Auto-dismiss timeout. Pass [Duration.zero] to keep the banner until
  /// the user taps it.
  final Duration duration;

  /// Optional identity for de-duplication (e.g. dio request id). If two
  /// toasts with the same id land in quick succession, the second is
  /// dropped.
  final Object? id;

  IconData get icon {
    switch (kind) {
      case ToastKind.error:
        return Icons.error_outline;
      case ToastKind.success:
        return Icons.check_circle_outline;
      case ToastKind.warning:
        return Icons.warning_amber_outlined;
      case ToastKind.info:
        return Icons.info_outline;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Toast && other.id != null && id != null && other.id == id;

  @override
  int get hashCode => id?.hashCode ?? identityHashCode(this);
}

/// Single source of truth for the toast queue. The overlay listens to
/// the [toastControllerProvider] and renders the latest toasts.
class ToastController extends StateNotifier<List<Toast>> {
  ToastController() : super(const []);

  /// Max banners on screen at once. Older ones are dropped if this is
  /// exceeded.
  static const int _maxVisible = 3;

  void post(Toast t) {
    // De-dupe by id — common when the same dio error fires from many
    // providers at once.
    if (t.id != null && state.any((existing) => existing.id == t.id)) {
      return;
    }
    final next = [...state, t];
    if (next.length > _maxVisible) {
      next.removeRange(0, next.length - _maxVisible);
    }
    state = next;
  }

  void dismiss(Toast t) {
    state = state.where((existing) => !identical(existing, t)).toList();
  }

  void clear() => state = const [];
}

final toastControllerProvider =
    StateNotifierProvider<ToastController, List<Toast>>(ToastController.new);

// ── Convenience helpers ──────────────────────────────────────────────

void showErrorToast(
  WidgetRef ref,
  String title, {
  String? body,
  Object? id,
  Duration? duration,
}) {
  ref.read(toastControllerProvider.notifier).post(
        Toast(
          title: title,
          body: body,
          kind: ToastKind.error,
          id: id,
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
}

void showSuccessToast(
  WidgetRef ref,
  String title, {
  String? body,
  Object? id,
}) {
  ref.read(toastControllerProvider.notifier).post(
        Toast(title: title, body: body, kind: ToastKind.success, id: id),
      );
}

void showWarningToast(
  WidgetRef ref,
  String title, {
  String? body,
  Object? id,
}) {
  ref.read(toastControllerProvider.notifier).post(
        Toast(title: title, body: body, kind: ToastKind.warning, id: id),
      );
}

void showInfoToast(
  WidgetRef ref,
  String title, {
  String? body,
  Object? id,
}) {
  ref.read(toastControllerProvider.notifier).post(
        Toast(title: title, body: body, kind: ToastKind.info, id: id),
      );
}

/// Pulls the most informative message out of a [DioException] —
/// preferring the server's `detail` string over `e.message` (which is
/// often empty or truncated). Falls back to a contextual default.
///
/// The (title, body) pair it returns is suitable for [showErrorToast]
/// or for showing inline form errors. Body is the long detail, title
/// is the short category.
({String title, String body}) describeDioError(
  Object error, {
  String fallback = 'Request failed',
}) {
  if (error is! DioException) {
    return (title: 'UNEXPECTED ERROR', body: error.toString());
  }

  final code = error.response?.statusCode;
  final detail = _extractDetail(error.response?.data);

  // Network-level problems (no response received).
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return (title: 'CONNECTION TIMEOUT', body: 'Server did not respond in time');
    case DioExceptionType.sendTimeout:
      return (title: 'SEND TIMEOUT', body: 'Request took too long to send');
    case DioExceptionType receiveTimeout:
      return (title: 'RECEIVE TIMEOUT', body: 'Server response was too slow');
    case DioExceptionType.connectionError:
      return (title: 'NETWORK ERROR', body: detail ?? 'Could not reach the server. Check your connection.');
    case DioExceptionType.cancel:
      return (title: 'REQUEST CANCELED', body: detail ?? 'The request was canceled');
    case DioExceptionType.badCertificate:
      return (title: 'BAD CERTIFICATE', body: 'Server certificate could not be verified');
    case DioExceptionType.unknown:
      if (code == null) {
        return (title: 'NETWORK ERROR', body: detail ?? error.message ?? 'Could not reach the server');
      }
      break;
    case DioExceptionType.badResponse:
      break;
  }

  // HTTP-level response. The server's `detail` field is the truth.
  if (code != null) {
    final cat = _categoryForStatus(code);
    final msg = detail ?? _defaultForStatus(code) ?? error.message ?? fallback;
    return (title: '$cat ($code)', body: msg);
  }

  return (title: fallback.toUpperCase(), body: error.message ?? error.toString());
}

/// Post a toast from a thrown object (DioException, plain Exception, etc.).
void showDioErrorToast(
  WidgetRef ref,
  Object error, {
  String fallbackTitle = 'REQUEST FAILED',
  String? fallbackBody,
  Object? id,
}) {
  final d = describeDioError(error, fallback: fallbackBody ?? fallbackTitle);
  showErrorToast(ref, d.title, body: d.body, id: id);
}

String? _extractDetail(Object? data) {
  if (data == null) return null;
  if (data is String) {
    final s = data.trim();
    return s.isEmpty ? null : s;
  }
  if (data is Map) {
    final d = data['detail'];
    if (d == null) return null;
    if (d is String && d.isNotEmpty) return d;
    return d.toString();
  }
  return data.toString();
}

String _categoryForStatus(int code) {
  if (code == 401) return 'UNAUTHORIZED';
  if (code == 403) return 'FORBIDDEN';
  if (code == 404) return 'NOT FOUND';
  if (code >= 400 && code < 500) return 'CLIENT ERROR';
  if (code >= 500) return 'SERVER ERROR';
  return 'HTTP ERROR';
}

String? _defaultForStatus(int code) {
  if (code == 401) return 'Authentication required or credentials are wrong';
  if (code == 403) return 'You do not have permission to do that';
  if (code == 404) return 'The requested resource was not found';
  if (code == 408) return 'The request timed out';
  if (code == 429) return 'Too many requests — try again in a moment';
  if (code >= 500) return 'The server is having trouble. Try again shortly.';
  return null;
}
