import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/dio_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Central auth state manager. Provided at the root of the widget tree.
class AuthController extends ChangeNotifier {
  late final TokenService _tokenService;
  late final ApiService _apiService;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Must be called once at startup after TokenService resolves.
  Future<void> init(TokenService tokenService) async {
    _tokenService = tokenService;
    _apiService = ApiService(_tokenService);
    await checkTokenAndAutoLogin();
  }

  /// Reads existing token; if valid tries to fetch profile, else unauthenticated.
  Future<void> checkTokenAndAutoLogin() async {
    if (!_tokenService.hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Restore cached user instantly for UI
    _currentUser = _tokenService.getUser();
    _status = AuthStatus.authenticated;
    notifyListeners();

    // Silently refresh profile from server
    try {
      final user = await _apiService.getProfile();
      _currentUser = user;
      await _tokenService.saveUser(user);
      notifyListeners();
    } catch (_) {
      // If 401 or network error, let user keep using cached data.
      // A 401 response fires only if the server actively rejects the token.
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.login(
        email: email,
        password: password,
      );
      await _tokenService.saveToken(response.token);
      await _tokenService.saveUser(response.user);
      _currentUser = response.user;
      _status = AuthStatus.authenticated;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      // We do NOT log the user in automatically after registration.
      // The user must go to the login screen and enter their credentials.
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _tokenService.clearAll();
    DioClient.reset(); // fresh Dio on next login
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _friendlyMessage(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    return raw.isNotEmpty ? raw : 'An unexpected error occurred.';
  }
}
