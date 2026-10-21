import 'package:flutter/material.dart';
import '../models/country_code.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/country_picker_dialog.dart';
import '../widgets/otp_verification_view.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  CountryCode _selectedCountry = CountryCode.defaultCountries.first;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeGuidelines = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Step state: false = registration form, true = OTP verification step
  bool _showOtpVerification = false;

  Color _selectedColor = AppColors.primaryPurple;
  final List<Color> _avatarColors = const [
    AppColors.primaryPurple,
    AppColors.primaryBlue,
    Color(0xFF10B981), // Emerald
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF6366F1), // Indigo
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await CountryPickerDialog.show(
      context,
      selectedCountry: _selectedCountry,
    );
    if (picked != null) {
      setState(() => _selectedCountry = picked);
    }
  }

  Future<void> _handleInitiateRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeGuidelines) {
      setState(() {
        _errorMessage = 'Please accept the Fair Play Community Guidelines.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Validate details with AuthService (Local + AWS Cloud Check)
    final validationError = await AuthService().validateRegistrationDetailsAsync(
      name: _nameController.text,
      tag: _tagController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phoneNumber: _phoneController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    // Generate 6-digit one-time email OTP (dispatches Brevo email if configured)
    AuthService().generateRegistrationOtp(
      _emailController.text,
      name: _nameController.text,
    );

    // Switch to OTP step
    setState(() {
      _showOtpVerification = true;
      _errorMessage = null;
    });
  }

  Future<void> _handleVerifyRegistrationOtp(String otp) async {
    final email = _emailController.text.trim();
    final isValid = AuthService().verifyRegistrationOtp(email, otp);

    if (!isValid) {
      throw 'Invalid or expired 6-digit OTP code. Please check and try again.';
    }

    // Complete registration
    final registerError = AuthService().register(
      name: _nameController.text,
      tag: _tagController.text,
      email: email,
      password: _passwordController.text,
      phoneNumber: _phoneController.text,
      countryCode: _selectedCountry.code,
      countryFlag: _selectedCountry.flag,
      avatarColor: _selectedColor,
    );

    if (registerError != null) {
      throw registerError;
    }

    if (mounted) {
      Navigator.of(context).pop(); // Back to main app (now authenticated)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.onlineGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Email verified! Welcome, ${AuthService().currentUser?.name}! 500 bonus coins awarded!',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceLight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewInitial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'P';

    return Scaffold(
      appBar: AppBar(
        title: Text(_showOtpVerification ? 'Verify Email' : 'Create Gamer Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_showOtpVerification) {
              setState(() => _showOtpVerification = false);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: _showOtpVerification
            ? Column(
                children: [
                  Expanded(
                    child: OtpVerificationView(
                      title: 'Verify Your Email',
                      subtitle:
                          'A one-time 6-digit OTP code has been generated for:',
                      email: _emailController.text.trim(),
                      purpose: 'registration',
                      onVerified: _handleVerifyRegistrationOtp,
                      onResend: () {
                        AuthService().generateRegistrationOtp(_emailController.text);
                        setState(() {});
                      },
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Change registration details'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _showOtpVerification = false),
                  ),
                  const SizedBox(height: 12),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryPurple.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryPurpleLight),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Account Security: 6-digit Email OTP verification is required to complete registration.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Avatar Customizer Preview
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: _selectedColor,
                              child: Text(
                                previewInitial,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.trophyGold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      const Text(
                        'Choose Avatar Theme Color:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Color picker row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _avatarColors.map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.dangerRose, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 18, color: AppColors.dangerRose),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.dangerRose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Display Name
                      TextFormField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'e.g. Alex Vance or Jordan Miller',
                          prefixIcon: const Icon(Icons.badge_outlined,
                              color: AppColors.primaryPurpleLight),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 2) {
                            return 'Enter at least 2 characters.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Gamer Tag
                      TextFormField(
                        controller: _tagController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Gamer Tag / Username',
                          hintText: '@alex_play or @striker99',
                          prefixIcon: const Icon(Icons.tag_rounded,
                              color: AppColors.primaryBlueLight),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 3) {
                            return 'Gamer tag must be at least 3 characters.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Phone Number with Country Code Selection
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Country Code Button
                          InkWell(
                            onTap: _pickCountry,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 58,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedCountry.flag,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedCountry.code,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Phone Number Input Field
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '9876543210',
                                prefixIcon: const Icon(
                                  Icons.phone_android_rounded,
                                  color: AppColors.primaryBlueLight,
                                ),
                                filled: true,
                                fillColor: AppColors.cardBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter phone number.';
                                }
                                final digits = val.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 7 || digits.length > 15) {
                                  return 'Enter 7-15 digits.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Email Address (OTP will be sent here)
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email Address (OTP Sent Here)',
                          hintText: 'you@domain.com',
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: AppColors.primaryPurpleLight),
                          suffixIcon: const Tooltip(
                            message: 'A 6-digit OTP will be sent to verify this email.',
                            child: Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.textMuted),
                          ),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (val) {
                          if (val == null || !val.contains('@') || !val.contains('.')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Min 6 characters',
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
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded,
                              color: AppColors.primaryPurpleLight),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() =>
                                  _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (val) {
                          if (val != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Guidelines checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreeGuidelines,
                            activeColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) =>
                                setState(() => _agreeGuidelines = val ?? true),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'I agree to the Fair Play & 100% Non-Gambling Community Terms (no real money betting or paid features).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Submit / Verify Email Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_outlined, size: 20),
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
                                  'Send 6-Digit Email OTP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _isLoading ? null : _handleInitiateRegistration,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
