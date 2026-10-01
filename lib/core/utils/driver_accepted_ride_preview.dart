import 'package:hilla_ride/core/models/app_models.dart';

/// UI-only ride snapshot right after Accept, before Firestore updates.
Ride driverAcceptedRidePreview(Ride ride, String driverId) {
  return Ride(
    id: ride.id,
    customerId: ride.customerId,
    driverId: driverId,
    pickupLabel: ride.pickupLabel,
    destinationLabel: ride.destinationLabel,
    pickupLat: ride.pickupLat,
    pickupLng: ride.pickupLng,
    destinationLat: ride.destinationLat,
    destinationLng: ride.destinationLng,
    status: RideStatus.accepted,
    createdAt: ride.createdAt,
    fareAmountIqd: ride.fareAmountIqd,
    paymentMethod: ride.paymentMethod,
    cashCollectedByDriver: ride.cashCollectedByDriver,
    cashConfirmedByCustomer: ride.cashConfirmedByCustomer,
    commissionPercent: ride.commissionPercent,
    platformCommissionIqd: ride.platformCommissionIqd,
    driverEarningsIqd: ride.driverEarningsIqd,
    completedAt: ride.completedAt,
    driverRating: ride.driverRating,
    driverFeedback: ride.driverFeedback,
    ratedAt: ride.ratedAt,
    districtId: ride.districtId,
    subDistrictId: ride.subDistrictId,
    originalFareIqd: ride.originalFareIqd,
    promoDiscountIqd: ride.promoDiscountIqd,
    promoCode: ride.promoCode,
    offeredDriverIds: ride.offeredDriverIds,
    rideNumber: ride.rideNumber,
  );
}
