import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class MissingProfileRecoveryScreen extends StatefulWidget {
  const MissingProfileRecoveryScreen({super.key});

  @override
  State<MissingProfileRecoveryScreen> createState() =>
      _MissingProfileRecoveryScreenState();
}

class _MissingProfileRecoveryScreenState
    extends State<MissingProfileRecoveryScreen> {
  final _nameController = TextEditingController();
  var _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  UserRole _defaultRole(BuildContext context) {
    if (AppConfig.variant.isWebAdmin) {
      return UserRole.manager;
    }
    final mode = context.read<AppModeProvider>().selectedMode;
    return mode ?? UserRole.customer;
  }

  bool get _isAssistantAccount {
    final email = context.read<AppState>().authService.currentUser?.email ?? '';
    return email.isNotEmpty && !email.endsWith('@hello-tiktok.app');
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = l10n.nameRequired);
      return;
    }

    if (_isAssistantAccount) {
      setState(() => _errorMessage = l10n.assistantProfileMissingHint);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<AppState>().authService.restoreMissingProfile(
            role: _defaultRole(context),
            name: name,
          );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message ?? error.code);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AppState>().authService.signOut();
    if (mounted) {
      context.read<AppModeProvider>().clearMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = _defaultRole(context);
    final roleLabel = switch (role) {
      UserRole.driver => l10n.roleDriver,
      UserRole.manager => l10n.roleManager,
      _ => l10n.roleCustomer,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.restoreProfileTitle),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text(l10n.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.restore_page_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                l10n.restoreProfileMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.restoreProfileRoleHint(roleLabel),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_isAssistantAccount) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.assistantProfileMissingHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving || _isAssistantAccount ? null : _restore,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.restoreProfileAction),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _signOut,
                child: Text(l10n.useDifferentAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
