import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../core/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/phone_field_with_country.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _fullPhoneNumber = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ── Register action ───────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_fullPhoneNumber.isEmpty) {
      _showError('Phone number is required');
      return;
    }

    final auth = context.read<AuthController>();
    if (auth.isLoading) return;

    final normalizedPhone = _fullPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: normalizedPhone,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account created successfully. Please login',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF388E3C), // Green
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _showError(auth.errorMessage ?? 'Registration failed. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo ────────────────────────────────────────────────
                Image.asset(
                  'assets/images/logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),

                // ── Header ──────────────────────────────────────────────
                Text(
                  'Create Account',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join the modern agronomist network and\nmanage your business with precision.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // ── Full Name ────────────────────────────────────────────
                CustomTextField(
                  label: 'FULL NAME',
                  hintText: 'John Doe',
                  controller: _nameController,
                  validator: _validateName,
                ),
                const SizedBox(height: 24),

                // ── Email ────────────────────────────────────────────────
                CustomTextField(
                  label: 'EMAIL (OPTIONAL)',
                  hintText: 'name@agro.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  validator: _validateEmail,
                  suffixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Phone ────────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHONE NUMBER',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PhoneFieldWithCountry(
                      hintText: '+1 (555) 000-0000',
                      onChanged: (phone) {
                        setState(() {
                          _fullPhoneNumber = phone.completeNumber;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Password ─────────────────────────────────────────────
                CustomTextField(
                  label: 'PASSWORD',
                  hintText: '••••••••',
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 48),

                // ── CTA Button ───────────────────────────────────────────
                Consumer<AuthController>(
                  builder: (_, auth, _) => PrimaryButton(
                    text: 'Create Account',
                    isLoading: auth.isLoading,
                    onPressed: auth.isLoading ? null : _handleRegister,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Login Link ───────────────────────────────────────────
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: GoogleFonts.inter(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // ── Terms ────────────────────────────────────────────────
                Center(
                  child: Text(
                    "By signing up, you agree to BSM Agro Industry's Terms of Service\nand Privacy Policy.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textHint,
                      fontSize: 12,
                      height: 1.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
