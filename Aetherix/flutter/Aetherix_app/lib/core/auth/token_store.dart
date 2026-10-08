import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT issued by /auth/register-device.
///
/// Works on Android, iOS, Windows, and Web — uses SharedPreferencesAsync
/// which has a real web implementation (localStorage). On web the token
/// therefore survives a page reload.
class TokenStore {
  TokenStore(this._prefs);

  static const _key = 'aetherix.jwt';
  static const _userKey = 'aetherix.user_id';
  static const _expiresKey = 'aetherix.jwt.expires_at';

  final SharedPreferences _prefs;

  Future<String?> read() async {
    final token = _prefs.getString(_key);
    final expiresAt = _prefs.getInt(_expiresKey);
    if (token == null) return null;
    if (expiresAt != null) {
      final expires = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      if (DateTime.now().isAfter(expires)) {
        await clear();
        return null;
      }
    }
    return token;
  }

  Future<void> write({
    required String token,
    required int userId,
    required int expiresInMinutes,
  }) async {
    final expiresAt = DateTime.now()
        .add(Duration(minutes: expiresInMinutes))
        .millisecondsSinceEpoch;
    await _prefs.setString(_key, token);
    await _prefs.setInt(_userKey, userId);
    await _prefs.setInt(_expiresKey, expiresAt);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    await _prefs.remove(_userKey);
    await _prefs.remove(_expiresKey);
  }

  int? get cachedUserId => _prefs.getInt(_userKey);
}