import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/screens/forgot_password_screen.dart';
import 'package:hilla_ride/features/auth/screens/signup_screen.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.selectedMode});

  final UserRole selectedMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  var _rememberMe = true;
  var _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    if (!PhoneAuthCredentials.isValidIraqiPhone(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phoneNumberInvalid)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().authService.signInWithPhonePassword(
            phoneRaw: _phoneController.text,
            password: _passwordController.text,
          );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.loginTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppBrandAssets.brandNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.selectedMode == UserRole.driver
                    ? l10n.roleDriver
                    : l10n.roleCustomer,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppBrandAssets.brandMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.phoneHint,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppBrandAssets.brandTealDark,
                  ),
                  hintText: '7701234567',
                ),
              ),
              const SizedBox(height: 14),
              PasswordTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: AppBrandAssets.brandTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                  Expanded(
                    child: Text(
                      l10n.rememberMe,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppBrandAssets.brandNavy,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      l10n.forgotPassword,
                      style: const TextStyle(
                        color: AppBrandAssets.brandTealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: l10n.loginButton,
                onPressed: _login,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 12),
              AppSecondaryButton(
                label: l10n.createAccountButton,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SignupScreen(selectedMode: widget.selectedMode),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
