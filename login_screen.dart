// Ported from ui/screens/LoginScreen.kt
//
// Two-step login: enter mobile number -> receive OTP -> verify OTP.
//
// Demo mode (DemoConfig.useMockData = true):
//   - "Send OTP" simulates a network call and always succeeds for any 10-digit number.
//   - The generated OTP is shown on screen in a small hint (so it's demoable without SMS).
//   - Entering that OTP (or "0000") on the verify step logs the user in.
//
// When your backend is ready:
//   1. Set DemoConfig.useMockData = false
//   2. Replace MockAuthRepository calls below with real HTTP calls
//      (send-otp endpoint, verify-otp endpoint)
//   3. Everything else — screens, state, navigation — stays the same.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/auth_repository.dart';
import '../data/models.dart';

const int _otpLength = 4;

enum _LoginStep { phone, otp }

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginStep _step = _LoginStep.phone;
  String _mobileNumber = '';
  String _otp = '';
  bool _isLoading = false;
  String? _errorText;
  String _generatedOtp = '';
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_mobileNumber.length != 10) {
      setState(() => _errorText = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    final otpFromServer = await MockAuthRepository.sendOtp(_mobileNumber);

    if (!mounted) return;
    setState(() {
      _generatedOtp = otpFromServer;
      _isLoading = false;
      _step = _LoginStep.otp;
    });
    _startResendCountdown();
  }

  Future<void> _resendOtp() async {
    setState(() {
      _errorText = null;
      _otp = '';
      _otpController.clear();
      _isLoading = true;
    });

    final otpFromServer = await MockAuthRepository.sendOtp(_mobileNumber);

    if (!mounted) return;
    setState(() {
      _generatedOtp = otpFromServer;
      _isLoading = false;
    });
    _startResendCountdown();
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != _otpLength) {
      setState(() => _errorText = 'Enter the $_otpLength-digit OTP');
      return;
    }
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    final success = await MockAuthRepository.verifyOtp(
      mobileNumber: _mobileNumber,
      otp: _otp,
      expectedOtp: _generatedOtp,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        _errorText = 'Incorrect OTP. Please try again.';
        _otp = '';
        _otpController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: _step == _LoginStep.otp ? 8 : 56),
              if (_step == _LoginStep.otp)
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _step = _LoginStep.phone;
                          _otp = '';
                          _otpController.clear();
                          _errorText = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'e-krushi',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Smart Plant Disease Detection',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == _LoginStep.phone
                    ? _PhoneStep(
                        key: const ValueKey('phone'),
                        controller: _phoneController,
                        isLoading: _isLoading,
                        errorText: _errorText,
                        onChanged: (value) {
                          setState(() {
                            _mobileNumber = value;
                            _errorText = null;
                          });
                        },
                        onSendOtp: _sendOtp,
                      )
                    : _OtpStep(
                        key: const ValueKey('otp'),
                        controller: _otpController,
                        mobileNumber: _mobileNumber,
                        isLoading: _isLoading,
                        errorText: _errorText,
                        resendSecondsLeft: _resendSecondsLeft,
                        onChanged: (value) {
                          setState(() {
                            _otp = value;
                            _errorText = null;
                          });
                        },
                        onVerify: _verifyOtp,
                        onResend: _resendOtp,
                      ),
              ),
              if (DemoConfig.useMockData &&
                  _step == _LoginStep.otp &&
                  _generatedOtp.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Demo mode — OTP is $_generatedOtp',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSendOtp;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.errorText,
    required this.onChanged,
    required this.onSendOtp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Login with your mobile number',
          style: textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Mobile number',
            hintText: '10-digit mobile number',
            counterText: '',
            prefixText: '+91  ',
            errorText: errorText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSendOtp,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Send OTP', style: textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "By continuing, you agree to eKrushi's Terms & Privacy Policy",
          style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  final TextEditingController controller;
  final String mobileNumber;
  final bool isLoading;
  final String? errorText;
  final int resendSecondsLeft;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _OtpStep({
    super.key,
    required this.controller,
    required this.mobileNumber,
    required this.isLoading,
    required this.errorText,
    required this.resendSecondsLeft,
    required this.onChanged,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final otp = controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Enter the OTP sent to', style: textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(
          '+91 $mobileNumber',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        // A row of visual boxes backed by a single hidden text field.
        SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_otpLength, (index) {
                  final char = index < otp.length ? otp[index] : '';
                  final isFocusedBox = index == otp.length;
                  return Container(
                    margin: EdgeInsets.only(left: index == 0 ? 0 : 12),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isFocusedBox
                          ? colorScheme.primary.withOpacity(0.08)
                          : colorScheme.surfaceVariant.withOpacity(0.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      char,
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ),
              Opacity(
                opacity: 0,
                child: SizedBox(
                  width: _otpLength * 52.0 + (_otpLength - 1) * 12,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: _otpLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: onChanged,
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            errorText!,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onVerify,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Verify & Continue', style: textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: 18),
        if (resendSecondsLeft > 0)
          Text(
            'Resend OTP in ${resendSecondsLeft}s',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
          )
        else
          GestureDetector(
            onTap: isLoading ? null : onResend,
            child: Text(
              'Resend OTP',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
