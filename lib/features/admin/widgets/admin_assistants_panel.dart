import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/manager_permissions.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/auth/widgets/password_text_field.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminAssistantsPanel extends StatefulWidget {
  const AdminAssistantsPanel({super.key});

  @override
  State<AdminAssistantsPanel> createState() => _AdminAssistantsPanelState();
}

class _AdminAssistantsPanelState extends State<AdminAssistantsPanel> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _selectedPermissions = {...AdminPermissions.defaultAssistant};
  var _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _permissionLabel(AppLocalizations l10n, String permission) {
    return switch (permission) {
      AdminPermissions.pendingDrivers => l10n.permPendingDrivers,
      AdminPermissions.activeRides => l10n.permActiveRides,
      AdminPermissions.liveMap => l10n.permLiveMap,
      AdminPermissions.allDrivers => l10n.permAllDrivers,
      AdminPermissions.customers => l10n.permCustomers,
      AdminPermissions.rideHistory => l10n.permRideHistory,
      AdminPermissions.pricing => l10n.permPricing,
      AdminPermissions.earnings => l10n.permEarnings,
      AdminPermissions.driverReviews => l10n.permDriverReviews,
      AdminPermissions.supportInbox => l10n.permSupportInbox,
      AdminPermissions.promoCodes => l10n.permPromoCodes,
      AdminPermissions.monthlyLeaderboard => l10n.permMonthlyLeaderboard,
      _ => permission,
    };
  }

  Future<void> _createAssistant() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistantFormInvalid)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final assistantService = context.read<AppState>().assistantService;
      await assistantService.createAssistant(
        name: name,
        email: email,
        password: password,
        permissions: assistantService.sanitizePermissions(
          _selectedPermissions.toList(),
        ),
      );
      if (!mounted) return;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistantCreated)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.assistantCreateFailed}\n$error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editPermissions(AppUser assistant) async {
    final l10n = AppLocalizations.of(context)!;
    final assistantService = context.read<AppState>().assistantService;
    final selected = {...assistant.permissions};

    final updated = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.editAssistantPermissions),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: AdminPermissions.all
                        .where((p) => p != AdminPermissions.manageAssistants)
                        .map(
                          (permission) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(permission),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selected.add(permission);
                                } else {
                                  selected.remove(permission);
                                }
                              });
                            },
                            title: Text(_permissionLabel(l10n, permission)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null) return;

    await assistantService.updateAssistantPermissions(
      assistantId: assistant.uid,
      permissions: assistantService.sanitizePermissions(updated.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final assistantService = context.read<AppState>().assistantService;

    return StreamBuilder<List<AppUser>>(
      stream: assistantService.watchAssistants(),
      builder: (context, snapshot) {
        final assistants = snapshot.data ?? const [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.assistantsTab,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.assistantsTabHint),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.createAssistantTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.fullName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.emailLabel),
                    ),
                    const SizedBox(height: 12),
                    PasswordTextField(
                      controller: _passwordController,
                      label: l10n.passwordLabel,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.assistantPermissionsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ...AdminPermissions.all
                        .where((p) => p != AdminPermissions.manageAssistants)
                        .map(
                          (permission) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selectedPermissions.contains(permission),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedPermissions.add(permission);
                                      } else {
                                        _selectedPermissions.remove(permission);
                                      }
                                    });
                                  },
                            title: Text(_permissionLabel(l10n, permission)),
                          ),
                        ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _createAssistant,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_outlined),
                      label: Text(l10n.createAssistantButton),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.existingAssistantsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (assistants.isEmpty)
              Text(l10n.noAssistantsYet)
            else
              ...assistants.map(
                (assistant) => Card(
                  child: ListTile(
                    title: Text(assistant.name),
                    subtitle: Text(
                      '${assistant.email ?? ''}\n'
                      '${assistant.permissions.map((p) => _permissionLabel(l10n, p)).join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editPermissions(assistant);
                        } else if (value == 'block') {
                          await assistantService.deactivateAssistant(assistant.uid);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.editAssistantPermissions),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text(l10n.blockUser),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
