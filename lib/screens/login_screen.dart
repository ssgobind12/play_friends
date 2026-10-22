import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/forgot_password_dialog.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;
  bool _isLoading = false;

  int _failedPasswordAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkExistingLockout();
  }

  Future<void> _checkExistingLockout() async {
    try {
      final raw = await LocalStorageService.getString('pf_login_lockout_until');
      if (raw != null) {
        final lockoutMillis = int.tryParse(raw) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (lockoutMillis > now) {
          final remaining = ((lockoutMillis - now) / 1000).ceil();
          if (remaining > 0) {
            _startLockoutTimer(remaining);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _triggerLockout() async {
    _failedPasswordAttempts = 5;
    const cooldownSeconds = 60;
    _startLockoutTimer(cooldownSeconds);
    try {
      final lockoutUntil =
          DateTime.now().millisecondsSinceEpoch + (cooldownSeconds * 1000);
      await LocalStorageService.setString(
          'pf_login_lockout_until', lockoutUntil.toString());
    } catch (_) {}
  }

  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSecondsRemaining = seconds;
      _errorMessage =
          'Too many failed attempts (5/5). Account locked for security. Please try again after $_lockoutSecondsRemaining seconds.';
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsRemaining > 1) {
        setState(() {
          _lockoutSecondsRemaining--;
          _errorMessage =
              'Too many failed attempts (5/5). Account locked for security. Please try again after $_lockoutSecondsRemaining seconds.';
        });
      } else {
        timer.cancel();
        _clearLockout();
      }
    });
  }

  Future<void> _clearLockout() async {
    _lockoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _failedPasswordAttempts = 0;
        _lockoutSecondsRemaining = 0;
        _errorMessage = null;
      });
    }
    try {
      await LocalStorageService.remove('pf_login_lockout_until');
    } catch (_) {}
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_lockoutSecondsRemaining > 0) {
      setState(() {
        _errorMessage =
            'Account locked for security. Please try again after $_lockoutSecondsRemaining seconds.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await AuthService().loginAsync(
      _identifierController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      await _clearLockout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${AuthService().currentUser?.name}!'),
          backgroundColor: AppColors.surfaceLight,
        ),
      );
    } else {
      _failedPasswordAttempts++;
      if (_failedPasswordAttempts >= 5) {
        await _triggerLockout();
      } else {
        final remaining = 5 - _failedPasswordAttempts;
        setState(() {
          _errorMessage =
              '$error ($remaining attempts remaining before 1-minute lockout)';
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    ForgotPasswordDialog.show(
      context,
      initialEmail: _identifierController.text.contains('@')
          ? _identifierController.text
          : '',
      onPasswordResetSuccess: (email, newPassword) {
        if (!mounted) return;
        _clearLockout();
        setState(() {
          _identifierController.text = email;
          _passwordController.text = newPassword;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.onlineGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password reset successful for $email! Tap "Login to Play".',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceLight,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding Logo
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Play Friends',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Social gaming with friends & local duels',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Error banner
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: AppColors.dangerRose, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lockoutSecondsRemaining > 0
                                ? Icons.timer_outlined
                                : Icons.error_outline_rounded,
                            size: 20,
                            color: AppColors.dangerRose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.dangerRose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Identifier Input (Email, Tag, or Mobile)
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email, Gamer Tag, or Mobile',
                      hintText: 'e.g. ssgobind12@gamil.com or 8573029430',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.primaryPurpleLight),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primaryBlueLight, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email or gamer tag.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.primaryBlueLight),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primaryPurpleLight, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your password.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // Remember me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primaryPurple,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) =>
                                setState(() => _rememberMe = val ?? true),
                          ),
                          const Text(
                            'Remember Me',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryBlueLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _lockoutSecondsRemaining > 0)
                          ? null
                          : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lockoutSecondsRemaining > 0
                            ? AppColors.cardBorder
                            : AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : _lockoutSecondsRemaining > 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        size: 18, color: AppColors.dangerRose),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Try again in ${_lockoutSecondsRemaining}s',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.dangerRose,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Login to Play',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Play as Guest
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.speed_rounded, size: 18),
                      label: const Text('Continue as Guest'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        AuthService().loginAsGuest();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Logged in as ${AuthService().currentUser?.name}!'),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(color: AppColors.cardBorder, height: 28),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register Here',
                          style: TextStyle(
                            color: AppColors.primaryBlueLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
