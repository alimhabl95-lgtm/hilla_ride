import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Live delivery offers — appears instantly when a business marks Ready.
class DriverDeliveryOrdersPanel extends StatelessWidget {
  const DriverDeliveryOrdersPanel({super.key, required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();

    return StreamBuilder<List<BusinessOrder>>(
      stream: biz.watchDriverDeliveryOffers(driverId),
      builder: (context, snap) {
        final items = (snap.data ?? const [])
            .where(
              (o) =>
                  o.status == BusinessOrderStatus.ready ||
                  (o.status == BusinessOrderStatus.outForDelivery &&
                      o.driverId == driverId),
            )
            .toList();
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'طلبات توصيل جاهزة' : 'Ready Delivery Orders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                for (final o in items.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      o.businessName.isEmpty ? o.businessId : o.businessName,
                    ),
                    subtitle: Text(
                      [
                        o.dropoffLabel,
                        fare.formatIqd(o.deliveryFeeIqd),
                        o.status.value,
                      ].join(' • '),
                    ),
                    trailing: o.status == BusinessOrderStatus.ready
                        ? FilledButton(
                            onPressed: () async {
                              try {
                                await biz.updateOrderStatus(
                                  orderId: o.id,
                                  status: BusinessOrderStatus.outForDelivery,
                                  driverId: driverId,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                            child: Text(
                              isAr ? 'استلام التوصيل' : 'Take Delivery',
                            ),
                          )
                        : Text(
                            isAr ? 'قيد التوصيل' : 'Out for delivery',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
