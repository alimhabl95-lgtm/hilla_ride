import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminFakeDriverBar extends StatelessWidget {
  const AdminFakeDriverBar({super.key, required this.isManager});

  final bool isManager;

  @override
  Widget build(BuildContext context) {
    if (!isManager) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.fakeDriversTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.fakeDriversHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.smart_toy_outlined),
              label: Text(l10n.createFakeDriver),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final plateController = TextEditingController();
    final vehicleController = TextEditingController(text: 'Tuk-Tuk');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createFakeDriver),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.driverNameLabel),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateController,
                decoration: InputDecoration(labelText: l10n.vehiclePlate),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleController,
                decoration: InputDecoration(labelText: l10n.vehicleType),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.createFakeDriver),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      nameController.dispose();
      plateController.dispose();
      vehicleController.dispose();
      return;
    }

    final auth = context.read<AppState>().authService.currentUser;
    if (auth == null) {
      nameController.dispose();
      plateController.dispose();
      vehicleController.dispose();
      return;
    }

    try {
      await context.read<AppState>().adminService.createFakeDriver(
            name: nameController.text,
            vehiclePlate: plateController.text,
            vehicleType: vehicleController.text,
            createdByUid: auth.uid,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fakeDriverCreated)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      nameController.dispose();
      plateController.dispose();
      vehicleController.dispose();
    }
  }
}

class AdminFakeDriverToggleButton extends StatelessWidget {
  const AdminFakeDriverToggleButton({
    super.key,
    required this.driver,
    required this.isManager,
  });

  final DriverProfile driver;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    if (!isManager || !driver.isFakeDriver) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;

    return FilledButton.tonalIcon(
      onPressed: () async {
        try {
          await adminService.setFakeDriverOnline(
            driverId: driver.uid,
            isOnline: !driver.isOnline,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                driver.isOnline
                    ? l10n.fakeDriverDeactivated
                    : l10n.fakeDriverActivated,
              ),
            ),
          );
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error')),
          );
        }
      },
      icon: Icon(driver.isOnline ? Icons.power_off : Icons.power),
      label: Text(
        driver.isOnline ? l10n.deactivateFakeDriver : l10n.activateFakeDriver,
      ),
    );
  }
}
