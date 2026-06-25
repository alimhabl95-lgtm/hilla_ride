import 'package:flutter/material.dart';

import 'package:hilla_ride/core/models/app_models.dart';

import 'package:hilla_ride/core/models/pricing_config.dart';

import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';

import 'package:hilla_ride/core/utils/ride_location_utils.dart';

import 'package:hilla_ride/l10n/app_localizations.dart';

import 'package:latlong2/latlong.dart';

import 'package:provider/provider.dart';



class BookRideScreen extends StatefulWidget {

  const BookRideScreen({

    super.key,

    required this.user,

    required this.pickup,

    required this.destination,

    required this.districtId,

    required this.subDistrictId,

  });



  final AppUser user;

  final PlaceResult pickup;

  final PlaceResult destination;

  final String districtId;

  final String subDistrictId;



  @override

  State<BookRideScreen> createState() => _BookRideScreenState();

}



class _BookRideScreenState extends State<BookRideScreen> {

  var _isBooking = false;

  var _isLoadingQuote = true;

  RideQuote? _quote;

  PromoApplication? _promoApplication;

  String? _quoteError;

  double _maxDistanceKm = PricingConfig.defaultMaxDistanceKm;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());

  }



  Future<void> _loadQuote() async {
    final pricing = context.read<AppState>().pricingService;
    final pickup = LatLng(widget.pickup.latitude, widget.pickup.longitude);
    final destination = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    setState(() {
      _quoteError = null;
      _quote = pricing.quickQuote(
        pickup: pickup,
        destination: destination,
        districtId: widget.districtId,
        subDistrictId: widget.subDistrictId,
      );
      _promoApplication = null;
      _isLoadingQuote = false;
    });

    try {
      final pricingConfig = await pricing
          .getConfig(
            districtId: widget.districtId,
            subDistrictId: widget.subDistrictId,
          )
          .timeout(const Duration(seconds: 10));
      final quote = await pricing
          .quoteRide(
            pickup: pickup,
            destination: destination,
            districtId: widget.districtId,
            subDistrictId: widget.subDistrictId,
            config: pricingConfig,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      PromoApplication? promo;
      if (widget.user.hasActivePromo && quote.fareIqd != null && quote.fareIqd! > 0) {
        try {
          final promoService = context.read<AppState>().promoService;
          final promoConfig = await promoService
              .getPromoCode(widget.user.promoCode)
              .timeout(const Duration(seconds: 5));
          promo = promoService.applyPromo(
            user: widget.user,
            config: promoConfig,
            baseFareIqd: quote.fareIqd!,
          );
        } catch (_) {
          promo = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _quote = quote;
        _promoApplication = promo;
        _maxDistanceKm = pricingConfig.maxDistanceKm;
      });
    } catch (error) {
      if (!mounted) return;
      if (_quote?.fareIqd == null) {
        setState(() {
          _quoteError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }



  Future<void> _book() async {
    final l10n = AppLocalizations.of(context)!;
    final quote = _quote;

    if (quote == null || !quote.canBook || quote.fareIqd == null) return;

    final promo = _promoApplication;
    final baseFare = quote.fareIqd!;
    final finalFare = promo?.hasDiscount == true ? promo!.finalFareIqd : baseFare;



    setState(() => _isBooking = true);

    try {

      await context.read<AppState>().rideService.bookRide(

            customerId: widget.user.uid,

            pickupLabel: widget.pickup.label,

            destinationLabel: widget.destination.label,

            pickup: LatLng(widget.pickup.latitude, widget.pickup.longitude),

            destination: LatLng(

              widget.destination.latitude,

              widget.destination.longitude,

            ),

            districtId: widget.districtId,

            subDistrictId: widget.subDistrictId,

            fareAmountIqd: finalFare,

            distanceKm: quote.distanceKm,

            originalFareIqd: promo?.hasDiscount == true ? baseFare : 0,

            promoDiscountIqd: promo?.discountIqd ?? 0,

            promoCode: promo?.promoCode ?? '',

          );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? switch (error.message) {
              'pickup_destination_same' => l10n.pickupDestinationMustDiffer,
              'active_ride_exists' => l10n.activeRideExists,
              _ => l10n.bookRideFailed,
            }
          : l10n.bookRideFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

    } finally {

      if (mounted) setState(() => _isBooking = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final l10n = AppLocalizations.of(context)!;

    final pricing = context.read<AppState>().pricingService;

    final quote = _quote;

    final canBook = quote?.canBook ?? false;

    final promo = _promoApplication;

    final displayFare = promo?.hasDiscount == true ? promo!.finalFareIqd : quote?.fareIqd;



    return Scaffold(

      appBar: AppBar(title: Text(l10n.bookRideTitle)),

      body: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            ListTile(

              leading: const Icon(Icons.trip_origin, color: Color(0xFF0F766E)),

              title: Text(l10n.pickup),

              subtitle: Text(widget.pickup.label),

            ),

            ListTile(

              leading: const Icon(Icons.location_on, color: Colors.red),

              title: Text(l10n.destination),

              subtitle: Text(widget.destination.label),

            ),

            const Divider(),

            if (_isLoadingQuote)

              Padding(

                padding: const EdgeInsets.symmetric(vertical: 24),

                child: Column(

                  children: [

                    const CircularProgressIndicator(),

                    const SizedBox(height: 12),

                    Text(l10n.calculatingFare),

                  ],

                ),

              )

            else if (_quoteError != null)

              Padding(

                padding: const EdgeInsets.symmetric(vertical: 16),

                child: Column(

                  children: [

                    Text(

                      l10n.fareCalculationFailed,

                      style: Theme.of(context).textTheme.titleMedium?.copyWith(

                            color: Theme.of(context).colorScheme.error,

                          ),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 12),

                    OutlinedButton(

                      onPressed: _loadQuote,

                      child: Text(l10n.retry),

                    ),

                  ],

                ),

              )

            else if (quote != null &&
                quote.outOfService &&
                !RideLocationRules.areDistinct(
                  LatLng(widget.pickup.latitude, widget.pickup.longitude),
                  LatLng(widget.destination.latitude, widget.destination.longitude),
                ))

              Padding(

                padding: const EdgeInsets.symmetric(vertical: 16),

                child: Column(

                  children: [

                    Icon(

                      Icons.swap_horiz,

                      size: 48,

                      color: Theme.of(context).colorScheme.error,

                    ),

                    const SizedBox(height: 12),

                    Text(

                      l10n.pickupDestinationMustDiffer,

                      style: Theme.of(context).textTheme.titleMedium?.copyWith(

                            color: Theme.of(context).colorScheme.error,

                          ),

                      textAlign: TextAlign.center,

                    ),

                  ],

                ),

              )

            else if (quote != null && quote.outOfService)

              Padding(

                padding: const EdgeInsets.symmetric(vertical: 16),

                child: Column(

                  children: [

                    Icon(

                      Icons.block,

                      size: 48,

                      color: Theme.of(context).colorScheme.error,

                    ),

                    const SizedBox(height: 12),

                    Text(

                      l10n.outOfServiceZone,

                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(

                            color: Theme.of(context).colorScheme.error,

                            fontWeight: FontWeight.bold,

                          ),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 8),

                    Text(

                      l10n.maxDistanceLimit(

                        _maxDistanceKm.toStringAsFixed(2),

                      ),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 8),

                    Text(

                      '${l10n.drivingDistance}: ${quote.distanceKm.toStringAsFixed(2)} km',

                      textAlign: TextAlign.center,

                    ),

                  ],

                ),

              )

            else if (quote != null && quote.fareIqd != null) ...[

              if (promo?.hasDiscount == true) ...[

                Text(

                  pricing.formatIqd(quote.fareIqd!, locale: l10n.localeName),

                  style: Theme.of(context).textTheme.titleLarge?.copyWith(

                        decoration: TextDecoration.lineThrough,

                        color: Theme.of(context).colorScheme.outline,

                      ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 4),

                Text(

                  l10n.promoDiscountApplied(

                    promo!.promoCode,

                    pricing.formatIqd(promo.discountIqd, locale: l10n.localeName),

                  ),

                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                        color: const Color(0xFFD97706),

                      ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 8),

              ],

              Text(

                pricing.formatIqd(displayFare!, locale: l10n.localeName),

                style: Theme.of(context).textTheme.displaySmall?.copyWith(

                      fontWeight: FontWeight.bold,

                      color: const Color(0xFF0F766E),

                    ),

                textAlign: TextAlign.center,

              ),

              const SizedBox(height: 8),

              Row(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  const Icon(Icons.access_time, size: 18),

                  const SizedBox(width: 4),

                  Text('~${quote.durationMinutes} ${l10n.minutes}'),

                  const SizedBox(width: 16),

                  const Icon(Icons.route, size: 18),

                  const SizedBox(width: 4),

                  Text('${quote.distanceKm.toStringAsFixed(2)} km'),

                ],

              ),

              if (quote.isEstimatedDistance)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.estimatedDistanceNote,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),

            ],

            const SizedBox(height: 16),

            Chip(

              avatar: const Icon(Icons.payments_outlined, size: 18),

              label: Text(l10n.paymentMethodCash),

            ),

            const Spacer(),

            FilledButton(

              onPressed: _isBooking || !canBook ? null : _book,

              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),

              child: _isBooking

                  ? const CircularProgressIndicator(strokeWidth: 2)

                  : Text(l10n.bookNowButton),

            ),

          ],

        ),

      ),

    );

  }

}


