import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class BusinessLoginScreen extends StatefulWidget {
  const BusinessLoginScreen({super.key});

  @override
  State<BusinessLoginScreen> createState() => _BusinessLoginScreenState();
}

class _BusinessLoginScreenState extends State<BusinessLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');
    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().authService.signInWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showAuthErrorSnackBar(context, error);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'فشل تسجيل الدخول' : 'Sign-in failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isAr ? 'بوابة الأعمال' : 'Business Portal',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'سجّل الدخول بالبريد الذي أنشأته الإدارة'
                        : 'Sign in with the email created by Admin',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isAr ? 'البريد' : 'Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordTextField(
                    controller: _passwordController,
                    label: isAr ? 'كلمة المرور' : 'Password',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isAr ? 'دخول' : 'Sign in'),
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
