import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _loginAsAssistant = false;
  var _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AppState>().authService;

    setState(() => _isLoading = true);
    try {
      if (_loginAsAssistant) {
        final email = _emailController.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.assistantFormInvalid)),
          );
          return;
        }
        await auth.signInWithEmailPassword(
          email: email,
          password: _passwordController.text,
        );
      } else {
        if (!PhoneAuthCredentials.isValidIraqiPhone(_phoneController.text)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.phoneNumberInvalid)),
          );
          return;
        }
        await auth.signInWithPhonePassword(
          phoneRaw: _phoneController.text,
          password: _passwordController.text,
        );
      }
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
                l10n.adminPanelTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.roleManager)),
                  ButtonSegment(value: true, label: Text(l10n.roleAssistant)),
                ],
                selected: {_loginAsAssistant},
                onSelectionChanged: (selection) {
                  setState(() => _loginAsAssistant = selection.first);
                },
              ),
              const SizedBox(height: 24),
              if (_loginAsAssistant)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                )
              else
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
              const SizedBox(height: 24),
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
              if (_loginAsAssistant) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.assistantLoginHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
