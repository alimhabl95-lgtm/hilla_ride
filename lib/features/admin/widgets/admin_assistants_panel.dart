import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
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
  var _selectedRoleTemplate = '';
  var _isSaving = false;

  static final _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _permissionLabel(AppLocalizations l10n, String permission) {
    return switch (permission) {
      AdminPermissions.overview =>
        l10n.localeName.startsWith('ar') ? 'نظرة عامة' : 'Overview dashboard',
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
      AdminPermissions.wallet =>
        l10n.localeName.startsWith('ar') ? 'محفظة السائقين' : 'Driver wallet',
      AdminPermissions.serviceAreas =>
        l10n.localeName.startsWith('ar') ? 'مناطق الخدمة' : 'Service areas',
      AdminPermissions.rewards =>
        l10n.localeName.startsWith('ar') ? 'المكافآت والحوافز' : 'Rewards & incentives',
      AdminPermissions.businessPartners =>
        l10n.localeName.startsWith('ar') ? 'شركاء الأعمال' : 'Business partners',
      AdminPermissions.complaints =>
        l10n.localeName.startsWith('ar') ? 'الشكاوى' : 'Complaints',
      AdminPermissions.notifications =>
        l10n.localeName.startsWith('ar') ? 'مركز الإشعارات' : 'Notifications center',
      AdminPermissions.driverPerformance =>
        l10n.localeName.startsWith('ar') ? 'أداء السائقين' : 'Driver performance',
      AdminPermissions.reports =>
        l10n.localeName.startsWith('ar') ? 'التقارير' : 'Reports',
      AdminPermissions.auditLog =>
        l10n.localeName.startsWith('ar') ? 'سجل التدقيق' : 'Audit log',
      AdminPermissions.appSettings =>
        l10n.localeName.startsWith('ar') ? 'إعدادات التطبيق' : 'App settings',
      _ => permission,
    };
  }

  void _applyRoleTemplate(String key) {
    final permissions = AdminRoleTemplates.templateKeys[key];
    if (permissions == null) return;
    setState(() {
      _selectedRoleTemplate = key;
      _selectedPermissions
        ..clear()
        ..addAll(
          permissions.where((p) => p != AdminPermissions.manageAssistants),
        );
    });
  }

  Widget _roleTemplateChips(AppLocalizations l10n) {
    final isAr = l10n.localeName.startsWith('ar');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AdminRoleTemplates.templateKeys.keys.map((key) {
        return ActionChip(
          label: Text(AdminRoleTemplates.labelForKey(key, isAr: isAr)),
          onPressed: _isSaving ? null : () => _applyRoleTemplate(key),
        );
      }).toList(),
    );
  }

  Widget _permissionCheckboxes(
    AppLocalizations l10n,
    Set<String> selected,
    void Function(void Function()) setDialogState,
  ) {
    return Column(
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
    );
  }

  Future<void> _createAssistant() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty ||
        !_emailRegExp.hasMatch(email) ||
        password.length < 6) {
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
        roleTemplate: _selectedRoleTemplate,
      );
      if (!mounted) return;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _selectedRoleTemplate = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistantCreated)),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.assistantCreateFailed}\n${assistantCreateErrorMessage(error, l10n)}',
          ),
        ),
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

  Future<void> _approveAssistant(AppUser assistant) async {
    final l10n = AppLocalizations.of(context)!;
    final assistantService = context.read<AppState>().assistantService;
    final selected = {...AdminPermissions.defaultAssistant};
    var roleTemplate = '';

    final approved = await showDialog<({Set<String> permissions, String template})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAr = l10n.localeName.startsWith('ar');
            return AlertDialog(
              title: Text(l10n.approveAssistantTitle),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AdminRoleTemplates.templateKeys.keys.map((key) {
                          return ActionChip(
                            label: Text(
                              AdminRoleTemplates.labelForKey(key, isAr: isAr),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                roleTemplate = key;
                                selected
                                  ..clear()
                                  ..addAll(
                                    AdminRoleTemplates.templateKeys[key]!
                                        .where(
                                          (p) =>
                                              p != AdminPermissions.manageAssistants,
                                        ),
                                  );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _permissionCheckboxes(l10n, selected, setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    (permissions: selected, template: roleTemplate),
                  ),
                  child: Text(l10n.approveAssistantButton),
                ),
              ],
            );
          },
        );
      },
    );

    if (approved == null) return;

    try {
      await assistantService.approveAssistant(
        assistantId: assistant.uid,
        permissions: approved.permissions.toList(),
        roleTemplate: approved.template,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistantApprovedMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _editPermissions(AppUser assistant) async {
    final l10n = AppLocalizations.of(context)!;
    final assistantService = context.read<AppState>().assistantService;
    final selected = {...assistant.permissions};
    var roleTemplate = assistant.roleTemplate;

    final updated = await showDialog<({Set<String> permissions, String template})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAr = l10n.localeName.startsWith('ar');
            return AlertDialog(
              title: Text(l10n.editAssistantPermissions),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AdminRoleTemplates.templateKeys.keys.map((key) {
                          return ActionChip(
                            label: Text(
                              AdminRoleTemplates.labelForKey(key, isAr: isAr),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                roleTemplate = key;
                                selected
                                  ..clear()
                                  ..addAll(
                                    AdminRoleTemplates.templateKeys[key]!
                                        .where(
                                          (p) =>
                                              p != AdminPermissions.manageAssistants,
                                        ),
                                  );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _permissionCheckboxes(l10n, selected, setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    (permissions: selected, template: roleTemplate),
                  ),
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
      permissions: assistantService.sanitizePermissions(updated.permissions.toList()),
      roleTemplate: updated.template,
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
        final pendingAssistants = assistants
            .where((a) => a.approvalStatus == 'pending')
            .toList();
        final activeAssistants = assistants
            .where((a) => a.approvalStatus != 'pending')
            .toList();

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
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        hintText: l10n.assistantEmailHint,
                      ),
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
                    const SizedBox(height: 8),
                    _roleTemplateChips(l10n),
                    const SizedBox(height: 8),
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
            if (pendingAssistants.isNotEmpty) ...[
              Text(
                l10n.pendingAssistantsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...pendingAssistants.map(
                (assistant) => Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text(assistant.name),
                    subtitle: Text(
                      '${assistant.email}\n${l10n.assistantPendingLabel}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton.icon(
                      onPressed: () => _approveAssistant(assistant),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.approveAssistantButton),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              l10n.existingAssistantsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (activeAssistants.isEmpty)
              Text(l10n.noAssistantsYet)
            else
              ...activeAssistants.map(
                (assistant) => Card(
                  child: ListTile(
                    title: Text(assistant.name),
                    subtitle: Text(
                      '${assistant.email}\n'
                      '${assistant.isBlocked ? l10n.assistantDisabled : l10n.assistantActive} • '
                      '${assistant.permissions.map((p) => _permissionLabel(l10n, p)).join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editPermissions(assistant);
                        } else if (value == 'toggle') {
                          await assistantService.setAssistantEnabled(
                            assistantId: assistant.uid,
                            enabled: assistant.isBlocked,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.editAssistantPermissions),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            assistant.isBlocked
                                ? l10n.enableAssistant
                                : l10n.disableAssistant,
                          ),
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
