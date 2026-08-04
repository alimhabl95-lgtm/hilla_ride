import 'package:flutter/material.dart';

import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/pricing_config.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
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
      final isAr = l10n.localeName.startsWith('ar');
      final message = error is StateError
          ? switch (error.message) {
              'pickup_destination_same' => l10n.pickupDestinationMustDiffer,
              'active_ride_exists' => l10n.activeRideExists,
              'area_inactive' => isAr
                  ? 'هذه المنطقة غير متاحة حالياً للطلبات الجديدة'
                  : 'This service area is not accepting new requests',
              'area_closed' => isAr
                  ? 'المنطقة خارج ساعات العمل الآن'
                  : 'This area is outside operating hours',
              'outside_area' => l10n.searchOutsideRegion,
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
    final displayFare =
        promo?.hasDiscount == true ? promo!.finalFareIqd : quote?.fareIqd;

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(title: Text(l10n.bookRideTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          _RouteRow(
                            icon: Icons.trip_origin,
                            iconColor: AppBrandAssets.brandGold,
                            label: l10n.pickup,
                            value: widget.pickup.label,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 11),
                            child: Container(
                              width: 2,
                              height: 20,
                              color: AppBrandAssets.brandBorder,
                            ),
                          ),
                          _RouteRow(
                            icon: Icons.location_on,
                            iconColor: AppBrandAssets.brandTeal,
                            label: l10n.destination,
                            value: widget.destination.label,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_isLoadingQuote)
                      AppLoadingState(label: l10n.calculatingFare)
                    else if (_quoteError != null)
                      AppCard(
                        child: Column(
                          children: [
                            Text(
                              l10n.fareCalculationFailed,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppBrandAssets.brandDanger),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppSecondaryButton(
                              label: l10n.retry,
                              onPressed: _loadQuote,
                            ),
                          ],
                        ),
                      )
                    else if (quote != null &&
                        quote.outOfService &&
                        !RideLocationRules.areDistinct(
                          LatLng(
                            widget.pickup.latitude,
                            widget.pickup.longitude,
                          ),
                          LatLng(
                            widget.destination.latitude,
                            widget.destination.longitude,
                          ),
                        ))
                      _ErrorState(
                        icon: Icons.swap_horiz,
                        message: l10n.pickupDestinationMustDiffer,
                      )
                    else if (quote != null && quote.outOfService)
                      _ErrorState(
                        icon: Icons.block,
                        message: l10n.outOfServiceZone,
                        details: [
                          l10n.maxDistanceLimit(
                            _maxDistanceKm.toStringAsFixed(2),
                          ),
                          '${l10n.drivingDistance}: ${quote.distanceKm.toStringAsFixed(2)} km',
                        ],
                      )
                    else if (quote != null && quote.fareIqd != null) ...[
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xxl,
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.bookRideTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppBrandAssets.brandMuted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (promo?.hasDiscount == true) ...[
                              Text(
                                pricing.formatIqd(
                                  quote.fareIqd!,
                                  locale: l10n.localeName,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppBrandAssets.brandMuted,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.promoDiscountApplied(
                                  promo!.promoCode,
                                  pricing.formatIqd(
                                    promo.discountIqd,
                                    locale: l10n.localeName,
                                  ),
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppBrandAssets.brandGold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            Text(
                              pricing.formatIqd(
                                displayFare!,
                                locale: l10n.localeName,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppBrandAssets.brandTealDark,
                                    letterSpacing: -0.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppStatCard(
                              label: l10n.minutes,
                              value: '~${quote.durationMinutes}',
                              icon: Icons.access_time,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppStatCard(
                              label: 'km',
                              value: quote.distanceKm.toStringAsFixed(2),
                              icon: Icons.route,
                              accent: AppBrandAssets.brandGold,
                            ),
                          ),
                        ],
                      ),
                      if (quote.isEstimatedDistance)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            l10n.estimatedDistanceNote,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppBanner(
                      message: l10n.paymentMethodCash,
                      icon: Icons.payments_outlined,
                      tone: AppBannerTone.info,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppPrimaryButton(
                label: l10n.bookNowButton,
                icon: Icons.local_taxi,
                isLoading: _isBooking,
                onPressed: _isBooking || !canBook ? null : _book,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
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
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: AppSpacing.md),
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.icon,
    required this.message,
    this.details = const [],
  });

  final IconData icon;
  final String message;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppBrandAssets.brandDanger),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppBrandAssets.brandDanger,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          for (final detail in details) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(detail, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
