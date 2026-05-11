import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../core/app_colors.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  static const Duration _authResolveTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();
    _navigate();
  }

  /// Waits until [auth.status] becomes non-unknown.
  /// Uses a listener (no busy loop) and a bounded timeout to avoid hanging.
  Future<AuthStatus> _waitForAuthResolution(AuthController auth) async {
    final current = auth.status;
    if (current != AuthStatus.unknown) return current;

    void Function()? removeListener;
    try {
      final completer = Completer<AuthStatus>();

      void onAuthChanged() {
        final s = auth.status;
        if (s != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete(s);
        }
      }

      auth.addListener(onAuthChanged);
      removeListener = () => auth.removeListener(onAuthChanged);

      return await completer.future.timeout(_authResolveTimeout);
    } finally {
      removeListener?.call();
    }
  }

  Future<void> _navigate() async {
    // Let the animation play, then evaluate auth state
    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    final auth = context.read<AuthController>();

    // Wait for the controller to finish init, but never forever.
    try {
      await _waitForAuthResolution(auth);
    } on TimeoutException {
      // Production-safe fallback: treat as unauthenticated.
      // If auth later resolves, the user can login normally.
      // ignore: avoid_print
      print(
        '[SplashScreen] Auth status did not resolve within '
        '${_authResolveTimeout.inSeconds}s; navigating to LoginScreen.',
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => auth.isAuthenticated
            ? const MainNavigation()
            : const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo container
                Image.asset(
                  'assets/images/logo.png',
                  width: 250,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  'BSM Agro Industry',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agricultural Management Platform',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.primaryGreen.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryGreen.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
