import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Singleton that wraps secure storage for auth persistence.
///
/// - Tokens and cached user JSON are stored in [FlutterSecureStorage].
/// - Legacy values from [SharedPreferences] are migrated on startup (best-effort)
///   so existing users keep auto-login without exposing tokens long-term.
class TokenService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  // ── Singleton ────────────────────────────────────────────────────────────
  static TokenService? _instance;
  static SharedPreferences? _prefs; // legacy (migration only)

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // In-memory cache so Dio interceptor can read synchronously.
  String? _cachedToken;
  String? _cachedUserJson;

  TokenService._();

  /// Synchronous accessor — only valid AFTER [getInstance()] has resolved.
  /// (Guaranteed at app startup in main.dart.)
  static TokenService get instance {
    assert(_instance != null,
        'TokenService not initialized. Await TokenService.getInstance() first.');
    return _instance!;
  }

  static Future<TokenService> getInstance() async {
    _instance ??= TokenService._();
    _prefs ??= await SharedPreferences.getInstance();
    await _instance!._initAndMigrate();
    return _instance!;
  }

  Future<void> _initAndMigrate() async {
    // 1) Load from secure storage first (source of truth).
    _cachedToken ??= await _secure.read(key: _tokenKey);
    _cachedUserJson ??= await _secure.read(key: _userKey);

    // 2) Best-effort migration from legacy SharedPreferences if secure is empty.
    //    This preserves auto-login for existing installs.
    final legacyToken = _prefs?.getString(_tokenKey);
    final legacyUser = _prefs?.getString(_userKey);

    final shouldMigrateToken =
        (_cachedToken == null || _cachedToken!.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty;
    final shouldMigrateUser =
        (_cachedUserJson == null || _cachedUserJson!.isEmpty) &&
        legacyUser != null &&
        legacyUser.isNotEmpty;

    if (shouldMigrateToken) {
      _cachedToken = legacyToken;
      await _secure.write(key: _tokenKey, value: legacyToken);
      await _prefs?.remove(_tokenKey);
    }

    if (shouldMigrateUser) {
      _cachedUserJson = legacyUser;
      await _secure.write(key: _userKey, value: legacyUser);
      await _prefs?.remove(_userKey);
    }
  }

  // ── Token ────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secure.write(key: _tokenKey, value: token);
    // Ensure legacy store is cleared if present (defense-in-depth).
    await _prefs?.remove(_tokenKey);
  }

  String? getToken() => _cachedToken;

  Future<void> clearToken() async {
    _cachedToken = null;
    await _secure.delete(key: _tokenKey);
    await _prefs?.remove(_tokenKey);
  }

  bool get hasToken => getToken() != null && getToken()!.isNotEmpty;

  // ── User ─────────────────────────────────────────────────────────────────
  Future<void> saveUser(UserModel user) async {
    final raw = jsonEncode(user.toJson());
    _cachedUserJson = raw;
    await _secure.write(key: _userKey, value: raw);
    await _prefs?.remove(_userKey);
  }

  UserModel? getUser() {
    final raw = _cachedUserJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    _cachedUserJson = null;
    await _secure.delete(key: _userKey);
    await _prefs?.remove(_userKey);
  }

  // ── Nuke everything ───────────────────────────────────────────────────────
  Future<void> clearAll() async {
    await Future.wait([clearToken(), clearUser()]);
  }
}
