import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_config.dart';
import '../theme/app_theme.dart';
import '../ui/toast.dart';
import 'alert_preferences.dart';
import 'notification_service.dart';

/// Bridges the user's [AlertPreferences] and the [NotificationService]:
///   * When a new article arrives in the news feed, decide whether it
///     matches the user's filters and, if so, post a system
///     notification.
///   * When the user toggles alerts on for the first time, ask for
///     POST_NOTIFICATIONS and surface a banner if the user denies.
///
/// The class intentionally has no UI — it is invoked from
/// (a) the news-feed listener (so a new article triggers a
/// notification) and (b) the settings page (so the toggle triggers
/// the permission flow).
class AlertDelivery {
  AlertDelivery(this._ref);

  final Ref _ref;
  static const _permissionAskedKey = 'aetherix.notif.permission_asked';

  /// Decide whether [article] should fire a notification. Returns the
  /// tag + tier if so, or null if the article should be silent.
  ({AlertTag tag, ImportanceTier tier})? shouldNotify(ArticleSnapshot a) {
    final prefs = _ref.read(alertPreferencesProvider);
    if (!prefs.enabled) return null;
    final tag = _parseTag(a.tag);
    if (tag == null) return null;
    final tier = ImportanceTier.fromScore(a.importanceScore);
    if (!prefs.matches(tag, tier)) return null;
    return (tag: tag, tier: tier);
  }

  /// Called by the news-feed listener for every fresh article.
  Future<void> checkAndNotify(ArticleSnapshot a) async {
    final decision = shouldNotify(a);
    if (decision == null) return;
    final svc = _ref.read(notificationServiceProvider);
    if (!svc.permissionGranted) {
      // Quietly skip — Settings page will surface a banner if the
      // user later tries to enable alerts. Don't spam the user with
      // permission dialogs from the background.
      return;
    }
    await svc.showArticleNotification(
      id: a.id,
      title: a.title,
      body: a.summary ?? 'New ${decision.tier.label.toLowerCase()} '
          '${decision.tag.label} article',
      payload: 'article:${a.id}',
    );
  }

  /// Called from the settings page when the user toggles alerts on
  /// for the first time. Prompts for permission if we haven't asked
  /// before. Subsequent toggles just persist the preference.
  Future<NotificationAskResult> ensurePermission() async {
    final prefs = _ref.read(sharedPrefsProvider);
    final alreadyAsked =
        prefs.getBool(_permissionAskedKey) ?? false;
    final svc = _ref.read(notificationServiceProvider);

    if (svc.permissionGranted) {
      // Already granted at the OS level — nothing to do.
      return NotificationAskResult.granted;
    }

    if (alreadyAsked) {
      // We asked before and the user denied. Don't re-prompt; tell
      // them where to flip the system switch instead.
      return NotificationAskResult.denied;
    }

    final granted = await svc.requestPermission();
    await prefs.setBool(_permissionAskedKey, true);

    if (!granted) {
      return NotificationAskResult.denied;
    }
    return NotificationAskResult.granted;
  }

  AlertTag? _parseTag(String? raw) {
    if (raw == null) return null;
    // The backend returns the human label (e.g. "Cyber Security"),
    // not the enum name ("cyberSecurity"). Match against the label.
    for (final t in AlertTag.values) {
      if (t.label == raw) return t;
    }
    return null;
  }
}

enum NotificationAskResult {
  /// User already had permission, or just granted it.
  granted,

  /// User has denied (or has previously denied and we shouldn't re-ask).
  denied,
}

/// What the news feed hands to the alert system. A snapshot of the
/// fields needed for the filter decision — keeps the dependency on
/// the article model one-way.
class ArticleSnapshot {
  const ArticleSnapshot({
    required this.id,
    required this.title,
    required this.tag,
    required this.importanceScore,
    this.summary,
  });

  final int id;
  final String title;
  final String? tag;
  final double? importanceScore;
  final String? summary;
}

final alertDeliveryProvider =
    Provider<AlertDelivery>((ref) => AlertDelivery(ref));
