import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminProfileButton extends StatelessWidget {
  const AdminProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.managerProfileTitle,
      icon: const Icon(Icons.account_circle_outlined),
      onPressed: () => _showProfile(context),
    );
  }

  void _showProfile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AppState>().authService;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StreamBuilder<AppUser?>(
          stream: authService.watchCurrentProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (profile == null) {
              return const AlertDialog(
                content: SizedBox(
                  width: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return AlertDialog(
              title: Text(l10n.managerProfileTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.manage_accounts),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(profile.phone),
                  ),
                  const Divider(),
                  Text('${l10n.fullName}: ${profile.name}'),
                  const SizedBox(height: 8),
                  Text('${l10n.phoneHint}: ${profile.phone}'),
                  const SizedBox(height: 8),
                  Text('${l10n.roleManager}: ${profile.role.name}'),
                  if (profile.email != null && profile.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Email: ${profile.email}'),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
