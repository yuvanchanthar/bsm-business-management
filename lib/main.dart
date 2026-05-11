import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'core/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/dio_client.dart';
import 'services/token_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TokenService (SharedPreferences) before runApp
  final tokenService = await TokenService.getInstance();

  runApp(MyApp(tokenService: tokenService));
}

class MyApp extends StatefulWidget {
  final TokenService tokenService;

  const MyApp({super.key, required this.tokenService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthController _authController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    // Wire up the controller with the token service; triggers auto-login check
    _authController.init(widget.tokenService);

    // Centralized 401 handling: logout once, then redirect to login.
    DioClient.onUnauthorized = () async {
      // Avoid loops / repeated navigation when already logged out.
      if (_authController.status == AuthStatus.unauthenticated) return;

      await _authController.logout();

      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>.value(
      value: _authController,
      child: MaterialApp(
        title: 'BSM Agro Industry',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppColors.primaryGreen,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryGreen,
            primary: AppColors.primaryGreen,
            surface: AppColors.background,
          ),
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
          textTheme: GoogleFonts.interTextTheme(
            const TextTheme(),
          ).apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
