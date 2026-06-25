import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final driverService = context.read<AppState>().driverService;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.managerTitle)),
      body: StreamBuilder<List<DriverProfile>>(
        stream: driverService.watchPendingDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? const [];
          if (drivers.isEmpty) {
            return Center(child: Text(l10n.noPendingDrivers));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(driver.phone),
                      Text('${l10n.vehicleType}: ${driver.vehicleType}'),
                      Text('${l10n.vehiclePlate}: ${driver.vehiclePlate}'),
                      Text('${l10n.licenseNumber}: ${driver.licenseNumber}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => driverService.setApprovalStatus(
                                driverId: driver.uid,
                                status: DriverApprovalStatus.rejected,
                              ),
                              child: Text(l10n.reject),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => driverService.setApprovalStatus(
                                driverId: driver.uid,
                                status: DriverApprovalStatus.approved,
                              ),
                              child: Text(l10n.approve),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ManagerProfileSetupScreen extends StatefulWidget {
  const ManagerProfileSetupScreen({super.key});

  @override
  State<ManagerProfileSetupScreen> createState() =>
      _ManagerProfileSetupScreenState();
}

class _ManagerProfileSetupScreenState extends State<ManagerProfileSetupScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().authService.saveUserProfile(
            role: UserRole.manager,
            name: _nameController.text.trim(),
            age: 18,
          );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.roleManager)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
