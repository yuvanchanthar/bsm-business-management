import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
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

  static const Duration _authResolveTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _navigate();
  }

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
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final auth = context.read<AuthController>();
    try {
      await _waitForAuthResolution(auth);
    } on TimeoutException {
      // ignore: avoid_print
      print('[SplashScreen] Auth resolve timeout; going to Login.');
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
      backgroundColor: const Color(0xFF0A2E12),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: const _SplashBody(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SPLASH BODY
// ─────────────────────────────────────────────────────────────
class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    final double sh = MediaQuery.of(context).size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background image ────────────────────────────────────────────────
        Image.asset('assets/images/splash_bg.png', fit: BoxFit.cover),

        // ── Top golden-sun glow overlay ─────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sh * 0.52,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.6),
                radius: 0.9,
                colors: [
                  const Color(0xFFFFE347).withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Main content ────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _LogoGroup(),
              const SizedBox(height: 14),
              const _BsmAgroTitle(),
              const SizedBox(height: 10),
              const _Tagline(),
              const Spacer(flex: 5),
              const _ProgressBar(),
              const SizedBox(height: 12),
              const _WelcomeText(),
              const SizedBox(height: 20),
              const _FooterSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LOGO GROUP  (bird emblem  +  big "BSM" text side by side)
// ─────────────────────────────────────────────────────────────
class _LogoGroup extends StatelessWidget {
  const _LogoGroup();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 195,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Bird emblem with glowing ring ──────────────────────────────
          SizedBox(
            width: 160,
            height: 195,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing circle behind emblem
                Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8DC63F).withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8DC63F).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Emblem image (tight-cropped, transparent background)
                Image.asset(
                  'assets/images/logo_emblem.png',
                  width: 160,
                  height: 195,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // ── "BSM" text ──────────────────────────────────────────────────
          Text(
            'BSM',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 100,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -2.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(3, 5),
                ),
                Shadow(
                  color: const Color(0xFF8DC63F).withValues(alpha: 0.15),
                  blurRadius: 25,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BSM AGRO TITLE
// ─────────────────────────────────────────────────────────────
class _BsmAgroTitle extends StatelessWidget {
  const _BsmAgroTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.eco, color: Color(0xFF8DC63F), size: 14),
            SizedBox(width: 3),
            Icon(Icons.eco, color: Color(0xFF8DC63F), size: 14),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'B S M   A G R O',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF8DC63F),
            letterSpacing: 3.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TAGLINE
// ─────────────────────────────────────────────────────────────
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.eco, color: Color(0xFF8DC63F), size: 11),
        const SizedBox(width: 4),
        Container(
          width: 40,
          height: 1,
          color: const Color(0xFF8DC63F).withValues(alpha: 0.4),
        ),
        const SizedBox(width: 8),
        Text(
          'Growing Better Futures',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.95),
            fontStyle: FontStyle.italic,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 1,
          color: const Color(0xFF8DC63F).withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.eco, color: Color(0xFF8DC63F), size: 11),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PROGRESS BAR  (thin glowing green track)
// ─────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: const Color(0xFF8DC63F).withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Container(
          width: 120,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            gradient: const LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF39B54A),
                Color(0xFF8DC63F),
                Color(0xFF39B54A),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF39B54A).withValues(alpha: 0.85),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WELCOME TEXT
// ─────────────────────────────────────────────────────────────
class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.eco, color: Color(0xFF8DC63F), size: 13),
        const SizedBox(width: 6),
        Text(
          'Welcome to BSM',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8DC63F),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.eco, color: Color(0xFF8DC63F), size: 13),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FOOTER SECTION  (curved dome + 3 badges)
// ─────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return CustomPaint(
      size: Size(width, 145),
      painter: _FooterPainter(),
      child: SizedBox(
        width: width,
        height: 145,
        child: Padding(
          padding: const EdgeInsets.only(top: 52, bottom: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              _FeatureItem(
                icon: Icons.eco_outlined,
                title: 'Quality',
                subtitle: 'Products',
              ),
              _VerticalDivider(),
              _FeatureItem(
                icon: Icons.shield_outlined,
                title: 'Trusted',
                subtitle: 'By Farmers',
              ),
              _VerticalDivider(),
              _FeatureItem(
                icon: Icons.spa_outlined,
                title: 'Sustainable',
                subtitle: 'Tomorrow',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark fill
    final Path shape = Path()
      ..moveTo(0, 42)
      ..quadraticBezierTo(size.width / 2, 0, size.width, 42)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF020D04).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill,
    );

    // Curved border path
    final Path border = Path()
      ..moveTo(0, 42)
      ..quadraticBezierTo(size.width / 2, 0, size.width, 42);

    final Rect rect = Rect.fromLTWH(0, 0, size.width, 42);

    // Outer glow
    canvas.drawPath(
      border,
      Paint()
        ..color = const Color(0xFF8DC63F).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Golden gradient highlight
    canvas.drawPath(
      border,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF8DC63F).withValues(alpha: 0.1),
            const Color(0xFFD4AF37),
            const Color(0xFFF5C842),
            const Color(0xFFD4AF37),
            const Color(0xFF8DC63F).withValues(alpha: 0.1),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF8DC63F), size: 26),
        const SizedBox(height: 5),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: const Color(0xFF8DC63F).withValues(alpha: 0.25),
    );
  }
}
