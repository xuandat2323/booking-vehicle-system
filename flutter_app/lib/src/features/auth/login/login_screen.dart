import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/network/connection_checker.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../core/widgets/app_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authControllerProvider).login(
            _phoneController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        ToastUtils.showSuccess(context, 'Đăng nhập thành công!');
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageAtmosphere),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  top + AppSpacing.xl,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: Column(
                  children: [
                    connectionStatus.when(
                      data: (online) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: online ? const Color(0xFF7DDBA3) : cs.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                online
                                    ? 'Máy chủ trực tuyến'
                                    : 'Máy chủ ngoại tuyến · $baseUrl',
                                style: tt.labelSmall?.copyWith(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!online) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => ref.invalidate(connectionStatusProvider),
                                child: const Icon(Icons.refresh, color: Colors.white, size: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                      loading: () => const SizedBox(height: 40),
                      error: (_, _) => const SizedBox(height: 24),
                    ),
                    FadeSlideIn(
                      child: Text(
                        'GoRento',
                        style: tt.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Text(
                        'Thuê xe tự lái — đơn giản & nhanh',
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: AppSurface(
                        color: cs.surfaceContainerLowest,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Đăng nhập',
                                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Tiếp tục hành trình thuê xe của bạn',
                                style: tt.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Số điện thoại',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: (value) {
                                  final phone = value?.trim() ?? '';
                                  if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
                                  if (!RegExp(r'^[0-9+]{9,15}$').hasMatch(phone)) {
                                    return 'Số điện thoại không hợp lệ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu';
                                  if (value!.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                                  return null;
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.go('/forgot-password'),
                                  child: const Text('Quên mật khẩu?'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GradientButton(
                                onPressed: auth.isLoading ? null : _submit,
                                isLoading: auth.isLoading,
                                child: const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Chưa có tài khoản?', style: tt.bodyMedium),
                                  TextButton(
                                    onPressed: () => context.go('/register'),
                                    child: Text(
                                      'Đăng ký ngay',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
