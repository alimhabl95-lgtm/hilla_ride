import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/shared/screens/edit_profile_screen.dart';
import 'package:hilla_ride/features/shared/widgets/firebase_driver_photo_image.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AppState>().authService;
    final driverService = context.read<AppState>().driverService;
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myProfileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfileTitle),
        actions: [
          IconButton(
            tooltip: l10n.editProfileButton,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final user = await authService.getCurrentProfile();
              if (user == null || !context.mounted) return;
              DriverProfile? driver;
              if (role == UserRole.driver) {
                driver = await driverService.watchDriver(uid).first;
              }
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    role: role,
                    user: user,
                    driver: driver,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: authService.watchCurrentProfile(),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (role == UserRole.driver) {
            return StreamBuilder<DriverProfile?>(
              stream: driverService.watchDriver(uid),
              builder: (context, driverSnapshot) {
                final driver = driverSnapshot.data;
                return _ProfileBody(
                  user: user,
                  driver: driver,
                  role: role,
                );
              },
            );
          }

          return _ProfileBody(user: user, role: role);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.role,
    this.driver,
  });

  final AppUser user;
  final UserRole role;
  final DriverProfile? driver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final registeredAt = user.createdAt;
    final registeredLabel = registeredAt == null
        ? '—'
        : DateFormat.yMMMd(l10n.localeName).add_jm().format(registeredAt);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: _ProfileAvatar(user: user, driver: driver, role: role),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountInformation,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoRow(label: l10n.fullName, value: user.name),
                _InfoRow(label: l10n.phoneHint, value: user.phone),
                if (user.email != null && user.email!.isNotEmpty)
                  _InfoRow(label: l10n.recoveryEmailLabel, value: user.email!),
                _InfoRow(
                  label: l10n.accountTypeLabel,
                  value: role == UserRole.driver
                      ? l10n.roleDriver
                      : l10n.roleCustomer,
                ),
                if (role == UserRole.customer) ...[
                  _InfoRow(label: l10n.age, value: '${user.age}'),
                  if (user.gender != null && user.gender!.isNotEmpty)
                    _InfoRow(label: l10n.gender, value: user.gender!),
                ],
                _InfoRow(label: l10n.registeredAt, value: registeredLabel),
              ],
            ),
          ),
        ),
        if (role == UserRole.driver && driver != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.driverRegistration,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.vehicleType,
                    value: driver!.vehicleType,
                  ),
                  _InfoRow(
                    label: l10n.vehiclePlate,
                    value: driver!.vehiclePlate,
                  ),
                  _InfoRow(
                    label: l10n.licenseNumber,
                    value: driver!.licenseNumber,
                  ),
                  _InfoRow(
                    label: l10n.statusLabel,
                    value: driver!.approvalStatus.name,
                  ),
                  _InfoRow(
                    label: l10n.completedRidesCount,
                    value: '${driver!.completedRidesCount}',
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final driverService = context.read<AppState>().driverService;
            var driverProfile = driver;
            if (role == UserRole.driver && driverProfile == null) {
              driverProfile =
                  await driverService.watchDriver(user.uid).first;
            }
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(
                  role: role,
                  user: user,
                  driver: driverProfile,
                ),
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.editProfileButton),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.role,
    this.driver,
  });

  final AppUser user;
  final UserRole role;
  final DriverProfile? driver;

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.driver && driver != null) {
      return SizedBox(
        width: 84,
        height: 84,
        child: ClipOval(
          child: FirebaseDriverPhotoImage(
            driverId: driver!.uid,
            fileName: 'profile_photo.jpg',
            imageUrl: driver!.profilePhotoUrl,
          ),
        ),
      );
    }

    if (user.profilePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(user.profilePhotoUrl),
      );
    }

    return CircleAvatar(
      radius: 42,
      child: Icon(
        role == UserRole.driver ? Icons.local_taxi : Icons.person,
        size: 42,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
