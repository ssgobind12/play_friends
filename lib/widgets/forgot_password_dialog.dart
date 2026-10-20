import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/brevo_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final void Function(String email, String newPassword) onPasswordResetSuccess;

  const ForgotPasswordDialog({
    super.key,
    required this.initialEmail,
    required this.onPasswordResetSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialEmail,
    required void Function(String email, String newPassword) onPasswordResetSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ForgotPasswordDialog(
        initialEmail: initialEmail,
        onPasswordResetSuccess: onPasswordResetSuccess,
      ),
    );
  }

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _step = 1; // 1 = Enter Email, 2 = Verify OTP & Set New Password
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  int _resendCountdown = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail.trim();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 45);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _otpControllers.map((c) => c.text.trim()).join();

  void _autofillCode(String code) {
    if (code.length == 6) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = code[i];
      }
      _otpFocusNodes.last.requestFocus();
      setState(() => _errorMessage = null);
    }
  }

  void _sendOtp() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid registered email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = AuthService().sendForgotPasswordOtp(email);

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      _startCountdown();
      setState(() {
        _step = 2;
        _errorMessage = null;
      });
    }
  }

  void _resendOtp() {
    if (_resendCountdown == 0) {
      final email = _emailController.text.trim().toLowerCase();
      AuthService().sendForgotPasswordOtp(email);
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes.first.requestFocus();
      _startCountdown();
      setState(() => _errorMessage = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A fresh 6-digit password reset OTP has been sent.'),
          backgroundColor: AppColors.surfaceLight,
        ),
      );
    }
  }

  void _resetPassword() {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _currentOtp;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit OTP code.');
      return;
    }

    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = AuthService().resetPasswordWithOtp(
      email: email,
      otp: otp,
      newPassword: newPass,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.of(context).pop();
      widget.onPasswordResetSuccess(email, newPass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOtp = _step == 2
        ? AuthService().getLatestOtpForEmail(
            _emailController.text.trim(),
            purpose: 'forgot_password',
          )
        : null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryBlueLight.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 28,
                color: AppColors.primaryBlueLight,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _step == 1 ? 'Forgot Password?' : 'Enter OTP & New Password',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              _step == 1
                  ? 'Enter your registered email to receive a one-time 6-digit OTP code.'
                  : 'We have generated a 6-digit OTP code for ${_emailController.text.trim()}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 16),

            // Error banner
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.dangerRose, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.dangerRose, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.dangerRose,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // STEP 1: ENTER EMAIL
            if (_step == 1) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Registered Email Address',
                  hintText: 'alex@playfriends.io',
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.primaryPurpleLight),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send 6-Digit OTP',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _sendOtp,
                ),
              ),
            ],

            // STEP 2: ENTER OTP & NEW PASSWORD
            if (_step == 2) ...[
              // Simulated Email Inbox Notification Banner
              if (activeOtp != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E284A), Color(0xFF161E38)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: BrevoConfig.isConfigured
                          ? AppColors.onlineGreen.withValues(alpha: 0.6)
                          : AppColors.primaryBlueLight.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            BrevoConfig.isConfigured
                                ? Icons.mark_email_read_rounded
                                : Icons.mark_email_unread_rounded,
                            color: BrevoConfig.isConfigured
                                ? AppColors.onlineGreen
                                : AppColors.primaryBlueLight,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              BrevoConfig.isConfigured
                                  ? 'Brevo Live Reset Email Dispatched'
                                  : 'Simulated Email Inbox Notification',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BrevoConfig.isConfigured
                                    ? AppColors.onlineGreen
                                    : AppColors.primaryBlueLight,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (BrevoConfig.isConfigured ? AppColors.onlineGreen : AppColors.primaryBlue)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              BrevoConfig.isConfigured ? 'LIVE BREVO' : 'SIMULATION',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: BrevoConfig.isConfigured ? AppColors.onlineGreen : AppColors.primaryBlueLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        BrevoConfig.isConfigured
                            ? 'Password reset OTP sent via Brevo to ${_emailController.text.trim()}.'
                            : 'Subject: Reset Password OTP for ${_emailController.text.trim()}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Code: ',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryPurpleLight),
                                ),
                                child: Text(
                                  activeOtp,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.flash_on_rounded, size: 12),
                            label: const Text('Auto-fill', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _autofillCode(activeOtp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 6-digit OTP row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    height: 52,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.cardBg,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryPurpleLight,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // Resend countdown
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't get code? ",
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.coinAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _resendOtp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Resend 6-Digit OTP',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlueLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // New Password
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password (Min 6 chars)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primaryBlueLight),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Confirm New Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded,
                      color: AppColors.primaryPurpleLight),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Update Password Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify OTP & Reset Password',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
