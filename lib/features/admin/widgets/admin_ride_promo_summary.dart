import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class AdminRidePromoSummary extends StatelessWidget {
  const AdminRidePromoSummary({
    super.key,
    required this.ride,
    this.compact = false,
  });

  final Ride ride;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!ride.usedPromo) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final locale = l10n.localeName;
    final original = fareService.formatIqd(
      ride.fullFareBeforePromoIqd,
      locale: locale,
    );
    final collected = fareService.formatIqd(ride.fareAmountIqd, locale: locale);
    final discount = fareService.formatIqd(
      ride.promoDiscountIqd,
      locale: locale,
    );
    final compensation = fareService.formatIqd(
      ride.driverPromoCompensationIqd,
      locale: locale,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.local_offer, size: 16),
              label: Text(l10n.ridePromoUsedCompact(ride.promoCode, discount)),
              backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.payments_outlined, size: 16),
              label: Text(l10n.rideDriverCompensationCompact(compensation)),
              backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
            ),
          ],
        ),
      );
    }

    return Card(
      color: const Color(0xFFD97706).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  l10n.ridePromoSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.ridePromoCodeUsed(ride.promoCode)),
            Text(l10n.ridePromoOriginalFare(original)),
            Text(l10n.ridePromoCustomerPaid(collected)),
            Text(l10n.ridePromoDiscountAmount(discount)),
            const Divider(height: 20),
            Text(
              l10n.rideDriverCompensationOwed(compensation),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.rideDriverCompensationHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
