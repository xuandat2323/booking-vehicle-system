import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscure = true;

  int _otpCountdown = 0;
  bool _sendingOtp = false;
  Timer? _timer;

  void _startCountdown() {
    setState(() => _otpCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown == 0) {
        timer.cancel();
      } else {
        setState(() => _otpCountdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !RegExp(r'^[0-9+]{9,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại hợp lệ để nhận OTP')),
      );
      return;
    }
    setState(() => _sendingOtp = true);

    // Normalize phone number format (E.164) for Firebase verifyPhone
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '+84${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      formattedPhone = '+$phone';
    }

    try {
      await ref.read(authControllerProvider).sendOtp(
        formattedPhone,
        onCodeSent: (verificationId) {
          if (mounted) {
            String msg = verificationId == "MOCK" 
                ? 'Đã gửi mã xác thực OTP (Mock: 123456)' 
                : 'Đã gửi mã xác thực OTP qua Firebase';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
            _startCountdown();
            setState(() => _sendingOtp = false);
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gửi OTP thất bại: $error')),
            );
            setState(() => _sendingOtp = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi OTP lỗi: $e')),
        );
        setState(() => _sendingOtp = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final phone = _phoneController.text.trim();
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '+84${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      formattedPhone = '+$phone';
    }

    try {
      await ref.read(authControllerProvider).register(
            formattedPhone,
            _passwordController.text,
            _otpController.text.trim(),
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đăng ký thất bại: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Hero Gradient Header ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 40,
                bottom: 48,
              ),
              decoration: const BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tạo tài khoản',
                    style: tt.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đăng ký để bắt đầu thuê xe',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Form Card ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      boxShadow: [AppTheme.ambientShadow],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Thông tin đăng ký',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nhập số điện thoại và tạo mật khẩu',
                            style: tt.bodyMedium,
                          ),
                          const SizedBox(height: 24),

                          // Phone + OTP button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Số điện thoại',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  validator: (value) {
                                    final phone = value?.trim() ?? '';
                                    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
                                    if (!RegExp(r'^[0-9+]{9,15}$').hasMatch(phone)) return 'Số điện thoại không hợp lệ';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 56, // Khớp với chiều cao mặc định của TextField
                                child: FilledButton(
                                  onPressed: _otpCountdown > 0 || _sendingOtp ? null : _sendOtp,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.secondaryContainer,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: _sendingOtp
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          _otpCountdown > 0 ? '${_otpCountdown}s' : 'Gửi OTP',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (value!.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // OTP
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Mã OTP',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) return 'Vui lòng nhập OTP';
                              if (value!.length < 4) return 'OTP không hợp lệ';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // CTA
                          GradientButton(
                            onPressed: auth.isLoading ? null : _submit,
                            isLoading: auth.isLoading,
                            child: const Text('Đăng ký',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )),
                          ),
                          const SizedBox(height: 16),

                          // Login link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Đã có tài khoản?', style: tt.bodyMedium),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.secondaryContainer,
                                ),
                                child: const Text(
                                  'Đăng nhập',
                                  style: TextStyle(fontWeight: FontWeight.w700),
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
            ),
          ],
        ),
      ),
    );
  }
}
