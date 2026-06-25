import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
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
      appBar: AppBar(title: Text(l10n.tripCompletedTitle)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final alreadyRated = ride.driverRating != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
                const SizedBox(height: 16),
                Text(
                  l10n.rideCompleted,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${l10n.rideFrom}: ${ride.pickupLabel}'),
                        Text('${l10n.rideTo}: ${ride.destinationLabel}'),
                        const Divider(),
                        Text(
                          fareService.formatIqd(
                            ride.fareAmountIqd,
                            locale: l10n.localeName,
                          ),
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(l10n.paymentMethodCash),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (alreadyRated) ...[
                  Text(
                    l10n.ratingSubmitted,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < ride.driverRating!
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                    ),
                  ),
                  if (ride.driverFeedback != null &&
                      ride.driverFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      ride.driverFeedback!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ] else ...[
                  Text(
                    l10n.rateDriverTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.rateDriverHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _selectedRating = starValue),
                        icon: Icon(
                          starValue <= _selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber.shade700,
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _feedbackController,
                    enabled: !_submitting,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.driverFeedbackLabel,
                      hintText: l10n.driverFeedbackHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting || _selectedRating < 1
                        ? null
                        : () => _submitRating(ride),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.submitRating),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(l10n.doneButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
