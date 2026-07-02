import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

Future<void> approveDriver(
  BuildContext context, {
  required String driverId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final driverService = context.read<AppState>().driverService;

  try {
    await driverService.setApprovalStatus(
      driverId: driverId,
      status: DriverApprovalStatus.approved,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.driverApprovedSuccess)),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.driverApprovalFailed)),
    );
  }
}

Future<void> rejectDriver(
  BuildContext context, {
  required String driverId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.rejectDriverConfirmTitle),
      content: Text(l10n.rejectDriverConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.reject),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final driverService = context.read<AppState>().driverService;
  try {
    await driverService.setApprovalStatus(
      driverId: driverId,
      status: DriverApprovalStatus.rejected,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.driverRejectedSuccess)),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.driverApprovalFailed)),
    );
  }
}
