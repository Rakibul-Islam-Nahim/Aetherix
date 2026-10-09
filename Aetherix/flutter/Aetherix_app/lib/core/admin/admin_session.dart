import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_config.dart';

/// Admin login session. Persists the short-lived admin JWT so the
/// panel stays open across screen pops, and clears it on logout.
class AdminSession {
  AdminSession(this._prefs);

  static const _tokenKey = 'aetherix.admin.jwt';
  static const _expiresKey = 'aetherix.admin.jwt.expires_at';

  final SharedPreferences _prefs;

  String? get token {
    final t = _prefs.getString(_tokenKey);
    final exp = _prefs.getInt(_expiresKey);
    if (t == null || t.isEmpty) return null;
    if (exp != null &&
        DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp))) {
      return null;
    }
    return t;
  }

  bool get isAuthenticated => token != null;

  Future<void> save({
    required String token,
    required int expiresInMinutes,
  }) async {
    final expiresAt = DateTime.now()
        .add(Duration(minutes: expiresInMinutes))
        .millisecondsSinceEpoch;
    await _prefs.setString(_tokenKey, token);
    await _prefs.setInt(_expiresKey, expiresAt);
  }

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_expiresKey);
  }
}

final adminSessionProvider = Provider<AdminSession>((ref) {
  return AdminSession(ref.watch(sharedPrefsProvider));
});
