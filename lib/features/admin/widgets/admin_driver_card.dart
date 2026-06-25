import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/widgets/admin_fake_driver_controls.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/features/admin/widgets/admin_customers_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_district_panel.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDriverCard extends StatelessWidget {
  const AdminDriverCard({
    super.key,
    required this.driver,
    this.isManager = false,
  });

  final DriverProfile driver;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final driverService = context.read<AppState>().driverService;
    final adminService = context.read<AppState>().adminService;
    const fareService = FareService();

    return StreamBuilder<DriverProfile?>(
      stream: adminService.watchDriver(driver.uid),
      builder: (context, driverSnapshot) {
        final liveDriver = driverSnapshot.data ?? driver;
        final isPendingLive =
            liveDriver.approvalStatus == DriverApprovalStatus.pending;

        return FutureBuilder<AppUser?>(
          future: adminService.getUser(liveDriver.uid),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final displayName = liveDriver.name.trim().isNotEmpty
                ? liveDriver.name.trim()
                : (user?.name.trim().isNotEmpty == true
                    ? user!.name.trim()
                    : l10n.unnamedDriver);
            final displayPhone = liveDriver.phone.trim().isNotEmpty
                ? liveDriver.phone.trim()
                : (user?.phone.trim() ?? '');

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Icon(
                            liveDriver.isBlocked
                                ? Icons.block
                                : Icons.local_taxi,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      displayPhone.isNotEmpty
                                          ? '${l10n.phoneHint}: $displayPhone'
                                          : '${l10n.phoneHint}: —',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${l10n.registeredAt}: ${_registeredLabelFor(liveDriver, l10n)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(liveDriver.approvalStatus.name),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (liveDriver.isBlocked)
                                    Chip(
                                      label: Text(l10n.blockedLabel),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  Chip(
                                    label: Text(
                                      liveDriver.isOnline
                                          ? l10n.goOnline
                                          : l10n.goOffline,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (liveDriver.isFakeDriver)
                                    Chip(
                                      avatar:
                                          const Icon(Icons.smart_toy, size: 16),
                                      label: Text(l10n.fakeDriverBadge),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.viewDriverHistory,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AdminDriverDetailScreen(
                                  driver: liveDriver,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.vehicleType}: ${liveDriver.vehicleType.isEmpty ? '—' : liveDriver.vehicleType}',
                    ),
                    Text(
                      '${l10n.vehiclePlate}: ${liveDriver.vehiclePlate.isEmpty ? '—' : liveDriver.vehiclePlate}',
                    ),
                    Text(
                      '${l10n.licenseNumber}: ${liveDriver.licenseNumber.isEmpty ? '—' : liveDriver.licenseNumber}',
                    ),
                    Text(
                      '${l10n.outstandingProfitLabel}: ${fareService.formatIqd(liveDriver.owedPlatformCommissionIqd, locale: l10n.localeName)}',
                    ),
                    Text(
                      '${l10n.cancelledRidesCount}: ${liveDriver.cancelledRidesCount}',
                    ),
                    if (liveDriver.hasAssignedWorkArea) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.driverWorkDistrictLabel}: '
                        '${_districtLabel(context, liveDriver)}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    AdminDriverDistrictPanel(driver: liveDriver),
                    const SizedBox(height: 12),
                    DriverDocumentPhotos(driver: liveDriver),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (liveDriver.owedPlatformCommissionIqd > 0)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final auth = context
                                  .read<AppState>()
                                  .authService
                                  .currentUser;
                              if (auth == null) return;
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.receivedProfitsTitle),
                                  content: Text(
                                    l10n.receivedProfitsConfirm(
                                      fareService.formatIqd(
                                        liveDriver.owedPlatformCommissionIqd,
                                        locale: l10n.localeName,
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l10n.receivedProfitsAction),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) return;
                              try {
                                await adminService.markProfitsReceived(
                                  driverId: liveDriver.uid,
                                  receivedByUid: auth.uid,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.receivedProfitsSuccess),
                                  ),
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$error')),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(l10n.receivedProfitsAction),
                          ),
                        if (isPendingLive) ...[
                          FilledButton.icon(
                            onPressed: () => driverService.setApprovalStatus(
                              driverId: liveDriver.uid,
                              status: DriverApprovalStatus.approved,
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(l10n.approve),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => driverService.setApprovalStatus(
                              driverId: liveDriver.uid,
                              status: DriverApprovalStatus.rejected,
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(l10n.reject),
                          ),
                        ],
                        AdminFakeDriverToggleButton(
                          driver: liveDriver,
                          isManager: isManager,
                        ),
                        if (liveDriver.isBlocked)
                          OutlinedButton.icon(
                            onPressed: () => driverService.setDriverBlocked(
                              driverId: liveDriver.uid,
                              blocked: false,
                            ),
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(l10n.unblockUser),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => driverService.setDriverBlocked(
                              driverId: liveDriver.uid,
                              blocked: true,
                            ),
                            icon: const Icon(Icons.block_outlined),
                            label: Text(l10n.blockUser),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          onPressed: () => _confirmRemoveDriver(
                            context,
                            adminService: adminService,
                            driver: liveDriver,
                          ),
                          icon: const Icon(Icons.person_remove_outlined),
                          label: Text(l10n.removeDriver),
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
    );
  }

  String _registeredLabelFor(DriverProfile driver, AppLocalizations l10n) {
    final when = driver.createdAt;
    if (when == null) return '—';
    return DateFormat.yMMMd(l10n.localeName).add_jm().format(when);
  }

  String _districtLabel(BuildContext context, DriverProfile driver) {
    final l10n = AppLocalizations.of(context)!;
    if (!driver.hasAssignedWorkArea) return l10n.driverWorkDistrictRequired;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final district = BabilRegions.districtById(driver.assignedDistrictId);
    final sub = driver.assignedSubDistrictId.isNotEmpty
        ? BabilRegions.subDistrictById(
            driver.assignedDistrictId,
            driver.assignedSubDistrictId,
          )
        : district.subDistricts.first;
    return '${isArabic ? district.nameAr : district.nameEn} • '
        '${isArabic ? sub.nameAr : sub.nameEn}';
  }

  Future<void> _confirmRemoveDriver(
    BuildContext context, {
    required AdminService adminService,
    required DriverProfile driver,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDriverConfirmTitle),
        content: Text(l10n.removeDriverConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeDriver),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await adminService.removeDriver(driver.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.driverRemoved)),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : l10n.removeDriverFailed,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : l10n.removeDriverFailed,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.removeDriverFailed)),
      );
    }
  }
}
