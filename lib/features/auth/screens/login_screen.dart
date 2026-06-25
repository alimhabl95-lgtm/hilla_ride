import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/screens/forgot_password_screen.dart';
import 'package:hilla_ride/features/auth/screens/signup_screen.dart';
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                l10n.loginTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.selectedMode == UserRole.driver
                    ? l10n.roleDriver
                    : l10n.roleCustomer,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneHint,
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '7701234567',
                ),
              ),
              const SizedBox(height: 12),
              PasswordTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                  Expanded(child: Text(l10n.rememberMe)),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.loginButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SignupScreen(selectedMode: widget.selectedMode),
                    ),
                  );
                },
                child: Text(l10n.createAccountButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
