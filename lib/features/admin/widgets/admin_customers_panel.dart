import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_service.dart';
import 'package:hilla_ride/features/shared/widgets/firebase_driver_photo_image.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminCustomersPanel extends StatelessWidget {
  const AdminCustomersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;

    return StreamBuilder<List<AppUser>>(
      stream: adminService.watchCustomers(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const [];
        if (customers.isEmpty) {
          return Center(child: Text(l10n.noCustomers));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: customers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final customer = customers[index];
            return Card(
              child: ListTile(
                title: Text(customer.name),
                subtitle: Text(
                  '${customer.phone}\n${l10n.cancelledRidesCount}: ${customer.cancelledRidesCount}${customer.isBlocked ? '\n${l10n.blockedLabel}' : ''}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (customer.isBlocked)
                      OutlinedButton(
                        onPressed: () => adminService.setCustomerBlocked(
                          userId: customer.uid,
                          blocked: false,
                        ),
                        child: Text(l10n.unblockUser),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => adminService.setCustomerBlocked(
                          userId: customer.uid,
                          blocked: true,
                        ),
                        child: Text(l10n.blockUser),
                      ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: () => _confirmDeleteCustomer(
                        context,
                        adminService: adminService,
                        customer: customer,
                      ),
                      child: Text(l10n.deleteCustomer),
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

  Future<void> _confirmDeleteCustomer(
    BuildContext context, {
    required AdminService adminService,
    required AppUser customer,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeCustomerConfirmTitle),
        content: Text(l10n.removeCustomerConfirmMessage),
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
            child: Text(l10n.deleteCustomer),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await adminService.removeCustomer(customer.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customerRemoved)),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : l10n.removeCustomerFailed,
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
                : l10n.removeCustomerFailed,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.removeCustomerFailed)),
      );
    }
  }
}

class DriverDocumentPhotos extends StatelessWidget {
  const DriverDocumentPhotos({super.key, required this.driver});

  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _PhotoPreviewCard(
            label: l10n.idPhotoLabel,
            driverId: driver.uid,
            fileName: 'id_photo.jpg',
            imageUrl: driver.idPhotoUrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PhotoPreviewCard(
            label: l10n.profilePhotoLabel,
            driverId: driver.uid,
            fileName: 'profile_photo.jpg',
            imageUrl: driver.profilePhotoUrl,
          ),
        ),
      ],
    );
  }
}

class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({
    required this.label,
    required this.driverId,
    required this.fileName,
    required this.imageUrl,
  });

  final String label;
  final String driverId;
  final String fileName;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDriverPhotoPreview(
        context,
        driverId: driverId,
        fileName: fileName,
        imageUrl: imageUrl,
        title: label,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FirebaseDriverPhotoImage(
                    driverId: driverId,
                    fileName: fileName,
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
