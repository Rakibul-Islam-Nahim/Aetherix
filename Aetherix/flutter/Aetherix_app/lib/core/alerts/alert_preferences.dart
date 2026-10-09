import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_config.dart';
import '../theme/app_theme.dart';

/// Tags the backend actually emits (kept in sync with
/// backend/app/services/tag_normalize.py — the 4-tag allowlist).
enum AlertTag {
  cyberSecurity('Cyber Security'),
  technology('Technology'),
  ai('AI'),
  hacking('Hacking');

  const AlertTag(this.label);
  final String label;
}

/// User-controllable alert preferences. Persisted to SharedPreferences.
///
/// Two independent filters combine into "should I notify?":
///   * `enabledTags`     — only articles whose tag set intersects this
///                         set are considered. Empty set = no tag filter
///                         (notify for any tag the user enabled at least
///                         one of).
///   * `minImportance`   — only articles at or above this tier.
@immutable
class AlertPreferences {
  const AlertPreferences({
    required this.enabledTags,
    required this.minImportance,
    required this.enabled,
  });

  /// Default: all tags on, "High or above" threshold, alerts on.
  factory AlertPreferences.defaults() => const AlertPreferences(
        enabledTags: {
          AlertTag.cyberSecurity,
          AlertTag.technology,
          AlertTag.ai,
          AlertTag.hacking,
        },
        minImportance: ImportanceTier.high,
        enabled: true,
      );

  final Set<AlertTag> enabledTags;
  final ImportanceTier minImportance;
  final bool enabled;

  AlertPreferences copyWith({
    Set<AlertTag>? enabledTags,
    ImportanceTier? minImportance,
    bool? enabled,
  }) =>
      AlertPreferences(
        enabledTags: enabledTags ?? this.enabledTags,
        minImportance: minImportance ?? this.minImportance,
        enabled: enabled ?? this.enabled,
      );

  /// True iff [tag] + [tier] would surface a notification, given the
  /// current preferences.
  bool matches(AlertTag tag, ImportanceTier tier) {
    if (!enabled) return false;
    if (enabledTags.isNotEmpty && !enabledTags.contains(tag)) return false;
    // Tier ordinal ascending: low < medium < high < critical.
    return tier.index >= minImportance.index;
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'min_importance': minImportance.name,
        'enabled_tags': enabledTags.map((t) => t.name).toList(),
      };

  static AlertPreferences fromJson(Map<String, dynamic> j) {
    final tags = (j['enabled_tags'] as List?)
            ?.map((s) => AlertTag.values.firstWhere(
                  (t) => t.name == s,
                  orElse: () => AlertTag.technology,
                ))
            .toSet() ??
        {};
    final tier = ImportanceTier.values.firstWhere(
      (t) => t.name == j['min_importance'],
      orElse: () => ImportanceTier.high,
    );
    return AlertPreferences(
      enabled: j['enabled'] as bool? ?? true,
      minImportance: tier,
      enabledTags: tags,
    );
  }
}

class AlertPreferencesController extends StateNotifier<AlertPreferences> {
  AlertPreferencesController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'aetherix.alert_prefs_v1';

  static AlertPreferences _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AlertPreferences.defaults();
    try {
      // Manual JSON so we don't need dart:convert in the model file.
      final m = <String, dynamic>{};
      for (final part in raw.split(';')) {
        final i = part.indexOf('=');
        if (i < 0) continue;
        final k = part.substring(0, i);
        final v = part.substring(i + 1);
        if (k == 'enabled') {
          m[k] = v == '1';
        } else if (k == 'min_importance') {
          m[k] = v;
        } else if (k == 'enabled_tags') {
          m[k] = v.isEmpty ? <String>[] : v.split(',');
        }
      }
      return AlertPreferences.fromJson(m);
    } catch (_) {
      return AlertPreferences.defaults();
    }
  }

  Future<void> _persist() async {
    final j = state.toJson();
    final raw = [
      'enabled=${state.enabled ? 1 : 0}',
      'min_importance=${j['min_importance']}',
      'enabled_tags=${(j['enabled_tags'] as List).join(',')}',
    ].join(';');
    await _prefs.setString(_key, raw);
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    await _persist();
  }

  Future<void> setMinImportance(ImportanceTier t) async {
    state = state.copyWith(minImportance: t);
    await _persist();
  }

  Future<void> toggleTag(AlertTag t) async {
    final next = Set<AlertTag>.from(state.enabledTags);
    if (next.contains(t)) {
      next.remove(t);
    } else {
      next.add(t);
    }
    state = state.copyWith(enabledTags: next);
    await _persist();
  }

  Future<void> reset() async {
    state = AlertPreferences.defaults();
    await _persist();
  }
}

final alertPreferencesProvider =
    StateNotifierProvider<AlertPreferencesController, AlertPreferences>(
  (ref) => AlertPreferencesController(ref.watch(sharedPrefsProvider)),
);
