import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class TripCompletedScreen extends StatefulWidget {
  const TripCompletedScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  int _selectedRating = 0;
  final _feedbackController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating(Ride ride) async {
    if (_selectedRating < 1) return;

    final appState = context.read<AppState>();
    final customerId = appState.authService.currentUser?.uid;
    if (customerId == null) return;

    setState(() => _submitting = true);
    try {
      await appState.rideService.submitDriverRating(
        rideId: ride.id,
        customerId: customerId,
        rating: _selectedRating,
        feedback: _feedbackController.text,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final rideService = context.read<AppState>().rideService;

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(title: Text(l10n.tripCompletedTitle)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride == null) {
            return const AppLoadingState();
          }

          final alreadyRated = ride.driverRating != null;

          return Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppFloatingPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppBrandAssets.brandSuccess
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 44,
                        color: AppBrandAssets.brandSuccess,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.rideCompleted,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TripLine(
                            icon: Icons.trip_origin,
                            iconColor: AppBrandAssets.brandGold,
                            label: l10n.rideFrom,
                            value: ride.pickupLabel,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _TripLine(
                            icon: Icons.location_on,
                            iconColor: AppBrandAssets.brandTeal,
                            label: l10n.rideTo,
                            value: ride.destinationLabel,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                          Text(
                            fareService.formatIqd(
                              ride.fareAmountIqd,
                              locale: l10n.localeName,
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandAssets.brandTealDark,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.paymentMethodCash,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppBrandAssets.brandMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (alreadyRated) ...[
                      Text(
                        l10n.ratingSubmitted,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppBrandAssets.brandNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < ride.driverRating!
                                ? Icons.star
                                : Icons.star_border,
                            color: AppBrandAssets.brandGold,
                            size: 36,
                          ),
                        ),
                      ),
                      if (ride.driverFeedback != null &&
                          ride.driverFeedback!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          ride.driverFeedback!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ] else ...[
                      Text(
                        l10n.rateDriverTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppBrandAssets.brandNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.rateDriverHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppBrandAssets.brandMuted,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return IconButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(
                                      () => _selectedRating = starValue,
                                    ),
                            icon: Icon(
                              starValue <= _selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: AppBrandAssets.brandGold,
                              size: 44,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _feedbackController,
                        enabled: !_submitting,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.driverFeedbackLabel,
                          hintText: l10n.driverFeedbackHint,
                          filled: true,
                          fillColor: AppBrandAssets.brandSurface,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: l10n.submitRating,
                        isLoading: _submitting,
                        onPressed: _submitting || _selectedRating < 1
                            ? null
                            : () => _submitRating(ride),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppSecondaryButton(
                      label: l10n.doneButton,
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppBrandAssets.brandMuted,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppBrandAssets.brandNavy,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
