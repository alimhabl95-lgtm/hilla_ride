import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.selectedMode});

  final UserRole selectedMode;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nameRequired)),
      );
      return;
    }
    if (!PhoneAuthCredentials.isValidIraqiPhone(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phoneNumberInvalid)),
      );
      return;
    }
    if (!PhoneAuthCredentials.isValidPassword(_passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordMinLength)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().authService.signUpWithPhonePassword(
            phoneRaw: _phoneController.text,
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            role: widget.selectedMode,
            email: _emailController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      showFunctionsErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
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
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailOptional,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              PasswordTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.passwordMinLength,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.createAccountButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}