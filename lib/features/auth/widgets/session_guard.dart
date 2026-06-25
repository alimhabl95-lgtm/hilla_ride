import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key, required this.child});

  final Widget child;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  StreamSubscription<String?>? _subscription;
  var _checking = true;
  var _signedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final authService = context.read<AppState>().authService;
    final sessionService = context.read<AppState>().sessionService;
    final user = authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    final valid = await sessionService.validateLocalSession(user.uid);
    if (!valid) {
      await _forceSignOut(showMessage: true);
      return;
    }

    _subscription = sessionService.watchRemoteSession(user.uid).listen(
      (_) async {
        if (!mounted || _signedOut) return;
        final valid = await sessionService.isSessionValid(user.uid);
        if (!valid) {
          await _forceSignOut(showMessage: true);
        }
      },
    );

    if (mounted) setState(() => _checking = false);
  }

  Future<void> _forceSignOut({required bool showMessage}) async {
    if (_signedOut) return;
    _signedOut = true;

    if (showMessage && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountLoggedInElsewhere)),
      );
    }

    await context.read<AppState>().authService.signOut();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.child;
  }
}
