const { isWithinBoundaryUnique } = require("./geo");

/**
 * Server-authoritative ride lifecycle mutations.
 */
function createRidesModule({ admin, functions, assertAdminPermissionAny }) {
  const db = () => admin.firestore();

  /**
   * Defense-in-depth: re-validates pickup/destination against the
   * resolved sub-district's effective boundary (Admin-drawn polygon, or
   * one synthesized from center + radius) — mirrors the client-side
   * checks so a compromised/modified client can't bypass area scoping.
   * Also mirrors the client's nearest-center tie-break for overlapping
   * temporary circle boundaries, so the backend can't be tricked into
   * accepting a point that the client would have rejected (e.g. a point
   * inside Qasim's circle that also happens to fall inside Al-Shumali's
   * larger overlapping circle). Throws `outside_area` / `area_inactive`
   * HttpsErrors when invalid. No-ops when `subDistrictId` is empty
   * (unscoped ride creation).
   */
  async function assertWithinServiceArea({
    subDistrictId,
    pickup,
    destination,
  }) {
    if (!subDistrictId) return;
    const subSnap = await db().collection("serviceSubDistricts").doc(subDistrictId).get();
    if (!subSnap.exists) {
      throw new functions.https.HttpsError("failed-precondition", "area_inactive");
    }
    const sub = subSnap.data() || {};
    if (String(sub.status || "inactive") !== "active") {
      throw new functions.https.HttpsError("failed-precondition", "area_inactive");
    }
    const center = { lat: Number(sub.latitude) || 0, lng: Number(sub.longitude) || 0 };
    const radiusKm = Number(sub.searchRadiusKm) || 22;
    const storedBoundary = Array.isArray(sub.boundary) ? sub.boundary : undefined;

    const othersSnap = await db()
      .collection("serviceSubDistricts")
      .where("status", "==", "active")
      .get();
    const others = othersSnap.docs
      .filter((doc) => doc.id !== subDistrictId)
      .map((doc) => {
        const data = doc.data() || {};
        return {
          center: { lat: Number(data.latitude) || 0, lng: Number(data.longitude) || 0 },
          radiusKm: Number(data.searchRadiusKm) || 22,
          boundary: Array.isArray(data.boundary) ? data.boundary : undefined,
        };
      });

    for (const point of [pickup, destination]) {
      if (!point) continue;
      if (!isWithinBoundaryUnique(point, center, radiusKm, storedBoundary, others)) {
        throw new functions.https.HttpsError("failed-precondition", "outside_area");
      }
    }
  }

  function haversineKm(lat1, lng1, lat2, lng2) {
    const toRad = (d) => (d * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  async function getWalletConfig() {
    const doc = await db().collection("config").doc("wallet").get();
    const data = doc.data() || {};
    return {
      minBalanceIqd: Math.max(1, Number(data.minBalanceIqd) || 1),
    };
  }

  async function allocateRideNumber(tx) {
    const counterRef = db().collection("config").doc("rideCounter");
    const snap = await tx.get(counterRef);
    const next = (Number(snap.data()?.nextNumber) || 1000) + 1;
    tx.set(counterRef, { nextNumber: next }, { merge: true });
    return next;
  }

  async function assignNearestDriverInternal(rideId, excludeDriverIds = []) {
    const rideRef = db().collection("rides").doc(rideId);
    const rideSnap = await rideRef.get();
    if (!rideSnap.exists) {
      throw new functions.https.HttpsError("not-found", "ride_not_found");
    }
    const ride = rideSnap.data() || {};
    const status = String(ride.status || "");
    if (status !== "searching" && status !== "matched") {
      throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
    }
    if (ride.driverId) {
      return { rideId, status: ride.status, driverId: ride.driverId };
    }

    const districtId = String(ride.districtId || "");
    const subDistrictId = String(ride.subDistrictId || "");
    const pickupLat = Number(ride.pickupLat);
    const pickupLng = Number(ride.pickupLng);
    const walletConfig = await getWalletConfig();
    const exclude = new Set(excludeDriverIds.map(String));

    let driversSnap;
    if (districtId && subDistrictId) {
      driversSnap = await db()
        .collection("drivers")
        .where("isOnline", "==", true)
        .where("approvalStatus", "==", "approved")
        .where("assignedDistrictId", "==", districtId)
        .where("assignedSubDistrictId", "==", subDistrictId)
        .limit(40)
        .get();
    } else {
      driversSnap = await db()
        .collection("drivers")
        .where("isOnline", "==", true)
        .where("approvalStatus", "==", "approved")
        .limit(40)
        .get();
    }

    const candidates = [];
    for (const doc of driversSnap.docs) {
      if (exclude.has(doc.id)) continue;
      const d = doc.data() || {};
      if (d.hasActiveRide === true) continue;
      if (d.isBlocked === true) continue;
      const balance = Number(d.walletBalanceIqd) || 0;
      const walletStatus = String(d.walletStatus || "active");
      if (walletStatus === "blocked" || balance < walletConfig.minBalanceIqd) {
        continue;
      }
      const lat = Number(d.lastLat ?? d.lat);
      const lng = Number(d.lastLng ?? d.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      const km = haversineKm(pickupLat, pickupLng, lat, lng);
      candidates.push({ id: doc.id, km });
    }
    candidates.sort((a, b) => a.km - b.km);
    if (candidates.length === 0) {
      await rideRef.set(
        {
          status: "searching",
          offeredDriverIds: [],
          notifyDrivers: false,
        },
        { merge: true },
      );
      throw new functions.https.HttpsError("failed-precondition", "no_drivers");
    }

    const offered = candidates.slice(0, 5).map((c) => c.id);
    await rideRef.set(
      {
        status: "matched",
        offeredDriverIds: offered,
        rejectedDriverIds: Array.from(exclude),
        notifyDrivers: true,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { rideId, status: "matched", offeredDriverIds: offered };
  }

  const createRide = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const customerId = context.auth.uid;
    const pickupLabel = String(data.pickupLabel || "").trim();
    const destinationLabel = String(data.destinationLabel || "").trim();
    const pickupLat = Number(data.pickupLat);
    const pickupLng = Number(data.pickupLng);
    const destinationLat = Number(data.destinationLat);
    const destinationLng = Number(data.destinationLng);
    const districtId = String(data.districtId || "").trim();
    const subDistrictId = String(data.subDistrictId || "").trim();
    const fareAmountIqd = Math.trunc(Number(data.fareAmountIqd) || 0);
    const distanceKm = Number(data.distanceKm) || 0;
    const originalFareIqd = Math.trunc(Number(data.originalFareIqd) || 0);
    const promoDiscountIqd = Math.trunc(Number(data.promoDiscountIqd) || 0);
    const promoCode = String(data.promoCode || "").trim();

    if (
      !pickupLabel ||
      !destinationLabel ||
      !Number.isFinite(pickupLat) ||
      !Number.isFinite(pickupLng) ||
      !Number.isFinite(destinationLat) ||
      !Number.isFinite(destinationLng) ||
      fareAmountIqd <= 0
    ) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid ride payload.");
    }
    if (
      Math.abs(pickupLat - destinationLat) < 1e-5 &&
      Math.abs(pickupLng - destinationLng) < 1e-5
    ) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "pickup_destination_same",
      );
    }

    await assertWithinServiceArea({
      subDistrictId,
      pickup: { lat: pickupLat, lng: pickupLng },
      destination: { lat: destinationLat, lng: destinationLng },
    });

    const active = await db()
      .collection("rides")
      .where("customerId", "==", customerId)
      .where("status", "in", [
        "searching",
        "matched",
        "accepted",
        "inProgress",
        "awaitingCashPayment",
      ])
      .limit(1)
      .get();
    if (!active.empty) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "active_ride_exists",
      );
    }

    const rideRef = db().collection("rides").doc();
    await db().runTransaction(async (tx) => {
      const rideNumber = await allocateRideNumber(tx);
      tx.set(rideRef, {
        customerId,
        pickupLabel,
        destinationLabel,
        pickupLat,
        pickupLng,
        destinationLat,
        destinationLng,
        status: "searching",
        fareAmountIqd,
        paymentMethod: "cash",
        rideNumber,
        districtId,
        subDistrictId,
        distanceKm,
        offeredDriverIds: [],
        notifyDrivers: false,
        notifyCustomer: false,
        ...(originalFareIqd > 0 ? { originalFareIqd } : {}),
        ...(promoDiscountIqd > 0 ? { promoDiscountIqd } : {}),
        ...(promoCode ? { promoCode } : {}),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    try {
      await assignNearestDriverInternal(rideRef.id);
    } catch (error) {
      if (error.code !== "failed-precondition") {
        functions.logger.warn("createRide assign failed", {
          rideId: rideRef.id,
          message: error.message,
        });
      }
    }

    const latest = await rideRef.get();
    return { ok: true, rideId: rideRef.id, ride: latest.data() || {} };
  });

  const acceptRide = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const driverId = context.auth.uid;
    if (!rideId) {
      throw new functions.https.HttpsError("invalid-argument", "rideId required.");
    }

    const walletConfig = await getWalletConfig();
    const rideRef = db().collection("rides").doc(rideId);
    const driverRef = db().collection("drivers").doc(driverId);

    await db().runTransaction(async (tx) => {
      const driverSnap = await tx.get(driverRef);
      if (!driverSnap.exists) {
        throw new functions.https.HttpsError("failed-precondition", "driver_missing");
      }
      const driver = driverSnap.data() || {};
      if (driver.hasActiveRide === true) {
        throw new functions.https.HttpsError("failed-precondition", "driver_busy");
      }
      const walletStatus = String(driver.walletStatus || "active");
      const walletBalance = Number(driver.walletBalanceIqd) || 0;
      if (
        walletStatus === "blocked" ||
        walletBalance <= 0 ||
        walletBalance < walletConfig.minBalanceIqd
      ) {
        throw new functions.https.HttpsError("failed-precondition", "wallet_blocked");
      }

      const rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = rideSnap.data() || {};
      const status = String(ride.status || "");
      if (status !== "matched" && status !== "searching") {
        throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
      }
      const assignedDriverId = String(ride.driverId || "");
      if (assignedDriverId && assignedDriverId !== driverId) {
        throw new functions.https.HttpsError("failed-precondition", "ride_taken");
      }
      const estimatedCommission = Number(ride.platformCommissionIqd) || 0;
      if (estimatedCommission > 0 && walletBalance < estimatedCommission) {
        throw new functions.https.HttpsError("failed-precondition", "wallet_blocked");
      }

      if (status === "searching") {
        const rideDistrictId = String(ride.districtId || "");
        const rideSubDistrictId = String(ride.subDistrictId || "");
        const driverDistrictId = String(driver.assignedDistrictId || "");
        const driverSubDistrictId = String(driver.assignedSubDistrictId || "");
        if (
          !rideDistrictId ||
          !rideSubDistrictId ||
          driverDistrictId !== rideDistrictId ||
          driverSubDistrictId !== rideSubDistrictId
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "ride_unavailable",
          );
        }
      } else {
        const offered = Array.isArray(ride.offeredDriverIds)
          ? ride.offeredDriverIds.map(String)
          : [];
        if (
          !assignedDriverId &&
          offered.length > 0 &&
          !offered.includes(driverId)
        ) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "ride_unavailable",
          );
        }
      }

      tx.update(rideRef, {
        driverId,
        status: "accepted",
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        offeredDriverIds: [],
        notifyDrivers: false,
        notifyCustomer: true,
      });
      tx.update(driverRef, {
        hasActiveRide: true,
        operationalStatus: "arrivingPickup",
      });
    });

    return { ok: true };
  });

  const rejectRide = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const driverId = context.auth.uid;
    if (!rideId) {
      throw new functions.https.HttpsError("invalid-argument", "rideId required.");
    }

    const rideRef = db().collection("rides").doc(rideId);
    let shouldReassign = false;
    const rejectedIds = new Set([driverId]);

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = snap.data() || {};
      if (String(ride.status || "") !== "matched") {
        throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
      }
      if (ride.driverId) {
        throw new functions.https.HttpsError("failed-precondition", "ride_taken");
      }
      const offered = Array.isArray(ride.offeredDriverIds)
        ? ride.offeredDriverIds.map(String)
        : [];
      if (!offered.includes(driverId)) {
        throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
      }
      const previousRejected = Array.isArray(ride.rejectedDriverIds)
        ? ride.rejectedDriverIds.map(String)
        : [];
      previousRejected.forEach((id) => rejectedIds.add(id));
      const remaining = offered.filter((id) => id !== driverId);
      if (remaining.length === 0) {
        shouldReassign = true;
        tx.update(rideRef, {
          offeredDriverIds: [],
          rejectedDriverIds: Array.from(rejectedIds),
          status: "searching",
          notifyDrivers: false,
        });
      } else {
        tx.update(rideRef, {
          offeredDriverIds: remaining,
          rejectedDriverIds: Array.from(rejectedIds),
        });
      }
    });

    if (shouldReassign) {
      try {
        await assignNearestDriverInternal(rideId, Array.from(rejectedIds));
      } catch (_) {}
    }
    return { ok: true };
  });

  const startRide = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const rideRef = db().collection("rides").doc(rideId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = snap.data() || {};
      if (String(ride.driverId || "") !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Not your ride.");
      }
      if (String(ride.status || "") !== "accepted") {
        throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
      }
      tx.update(rideRef, {
        status: "inProgress",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(db().collection("drivers").doc(context.auth.uid), {
        operationalStatus: "onTrip",
      });
    });
    return { ok: true };
  });

  const endRideAwaitingCash = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const rideRef = db().collection("rides").doc(rideId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = snap.data() || {};
      if (String(ride.driverId || "") !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Not your ride.");
      }
      if (String(ride.status || "") !== "inProgress") {
        throw new functions.https.HttpsError("failed-precondition", "ride_unavailable");
      }
      tx.update(rideRef, {
        status: "awaitingCashPayment",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  });

  const confirmCashCollected = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const rideRef = db().collection("rides").doc(rideId);
    const commissionDoc = await db().collection("config").doc("commission").get();
    const defaultCommissionPercent = Number(commissionDoc.data()?.platformPercent) || 15;

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = snap.data() || {};
      if (String(ride.driverId || "") !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Not your ride.");
      }
      if (ride.earningsApplied === true) {
        return;
      }
      const status = String(ride.status || "");
      if (status === "cancelled") return;
      if (status !== "awaitingCashPayment" && status !== "completed") {
        throw new functions.https.HttpsError("failed-precondition", "ride_not_ready");
      }

      const fare = Math.trunc(Number(ride.fareAmountIqd) || 0);
      const driverId = String(ride.driverId || "");
      let commissionPercent = defaultCommissionPercent;
      const subId = String(ride.subDistrictId || "");
      if (subId) {
        const subSnap = await tx.get(db().collection("serviceSubDistricts").doc(subId));
        const sub = subSnap.data() || {};
        if (
          sub.useGlobalCommission === false &&
          Number.isFinite(Number(sub.commissionPercent))
        ) {
          commissionPercent = Number(sub.commissionPercent);
        }
      }
      const platformCommissionIqd = Math.round((fare * commissionPercent) / 100);
      const driverEarningsIqd = Math.max(0, fare - platformCommissionIqd);

      tx.update(rideRef, {
        cashCollectedByDriver: true,
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        commissionPercent,
        platformCommissionIqd,
        driverEarningsIqd,
        earningsApplied: true,
      });

      if (driverId) {
        tx.update(db().collection("drivers").doc(driverId), {
          totalFareCollectedIqd: admin.firestore.FieldValue.increment(fare),
          totalPlatformCommissionIqd: admin.firestore.FieldValue.increment(
            platformCommissionIqd,
          ),
          outstandingPlatformCommissionIqd: admin.firestore.FieldValue.increment(
            platformCommissionIqd,
          ),
          totalDriverEarningsIqd: admin.firestore.FieldValue.increment(
            driverEarningsIqd,
          ),
          outstandingDriverEarningsIqd: admin.firestore.FieldValue.increment(
            driverEarningsIqd,
          ),
          completedRidesCount: admin.firestore.FieldValue.increment(1),
          hasActiveRide: false,
          operationalStatus: "available",
        });
      }

      const customerId = String(ride.customerId || "");
      const promoCode = String(ride.promoCode || "");
      const promoDiscountIqd = Number(ride.promoDiscountIqd) || 0;
      if (customerId && promoCode && promoDiscountIqd > 0) {
        tx.update(db().collection("users").doc(customerId), {
          promoRidesUsed: admin.firestore.FieldValue.increment(1),
        });
      }
    });

    return { ok: true };
  });

  const cancelRide = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const cancelledByRole = String(data.cancelledBy || "customer").trim();
    const rideRef = db().collection("rides").doc(rideId);

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) return;
      const ride = snap.data() || {};
      const status = String(ride.status || "");
      if (status === "completed" || status === "cancelled") return;

      const uid = context.auth.uid;
      const isCustomer = String(ride.customerId || "") === uid;
      const isDriver = String(ride.driverId || "") === uid;
      if (!isCustomer && !isDriver) {
        throw new functions.https.HttpsError("permission-denied", "Not your ride.");
      }
      if (
        isCustomer &&
        (status === "inProgress" || status === "awaitingCashPayment")
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Ride can no longer be cancelled after it has started.",
        );
      }

      const role = isDriver ? "driver" : cancelledByRole || "customer";
      tx.update(rideRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: role,
        offeredDriverIds: [],
        notifyDrivers: false,
        notifyCustomer: false,
      });

      const assignedDriverId = String(ride.driverId || "");
      if (assignedDriverId) {
        tx.update(db().collection("drivers").doc(assignedDriverId), {
          hasActiveRide: false,
          operationalStatus: "available",
        });
      }
      if (role === "customer" && ride.customerId) {
        tx.update(db().collection("users").doc(String(ride.customerId)), {
          cancelledRidesCount: admin.firestore.FieldValue.increment(1),
        });
      } else if (role === "driver" && assignedDriverId) {
        tx.update(db().collection("drivers").doc(assignedDriverId), {
          cancelledRidesCount: admin.firestore.FieldValue.increment(1),
        });
      }
    });

    return { ok: true };
  });

  const assignNearestDriver = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const exclude = Array.isArray(data.excludeDriverIds)
      ? data.excludeDriverIds.map(String)
      : [];
    const result = await assignNearestDriverInternal(rideId, exclude);
    return { ok: true, ...result };
  });

  const submitDriverRating = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const rideId = String(data.rideId || "").trim();
    const rating = Math.trunc(Number(data.rating) || 0);
    const feedback = String(data.feedback || "").trim().slice(0, 500);
    if (rating < 1 || rating > 5) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Rating must be between 1 and 5.",
      );
    }

    const rideRef = db().collection("rides").doc(rideId);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(rideRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "ride_not_found");
      }
      const ride = snap.data() || {};
      if (String(ride.customerId || "") !== context.auth.uid) {
        throw new functions.https.HttpsError("permission-denied", "Not your ride.");
      }
      if (String(ride.status || "") !== "completed") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "ride_not_completed",
        );
      }
      if (ride.driverRating != null) {
        return;
      }

      tx.update(rideRef, {
        driverRating: rating,
        driverFeedback: feedback,
        ratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const driverId = String(ride.driverId || "");
      if (driverId) {
        const driverRef = db().collection("drivers").doc(driverId);
        const driverSnap = await tx.get(driverRef);
        const driverData = driverSnap.data() || {};
        const oldCount = Number(driverData.ratingCount) || 0;
        const oldRating = Number(driverData.rating);
        const base = Number.isFinite(oldRating) ? oldRating : 5;
        const newCount = oldCount + 1;
        const newRating = (base * oldCount + rating) / newCount;
        tx.update(driverRef, {
          rating: newRating,
          ratingCount: newCount,
        });
      }
    });

    return { ok: true };
  });

  const applyPendingRideEarnings = functions.https.onCall(async (data, context) => {
    if (!assertAdminPermissionAny) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Admin permission helper missing.",
      );
    }
    await assertAdminPermissionAny(context, ["earnings", "wallet", "overview"]);
    const rideIdFilter = String(data.rideId || "").trim();
    const limit = Math.min(Math.max(Math.trunc(Number(data.limit) || 100), 1), 200);
    let snapshot;
    if (rideIdFilter) {
      const one = await db().collection("rides").doc(rideIdFilter).get();
      snapshot = { docs: one.exists ? [one] : [] };
    } else {
      snapshot = await db()
        .collection("rides")
        .where("cashCollectedByDriver", "==", true)
        .limit(limit)
        .get();
    }

    const commissionDoc = await db().collection("config").doc("commission").get();
    const defaultCommissionPercent = Number(commissionDoc.data()?.platformPercent) || 15;
    let applied = 0;

    for (const doc of snapshot.docs) {
      const rideRef = doc.ref;
      let didApply = false;
      // eslint-disable-next-line no-await-in-loop
      await db().runTransaction(async (tx) => {
        didApply = false;
        const snap = await tx.get(rideRef);
        if (!snap.exists) return;
        const ride = snap.data() || {};
        if (ride.earningsApplied === true) {
          if (String(ride.status || "") !== "completed") {
            tx.update(rideRef, {
              status: "completed",
              completedAt:
                ride.completedAt || admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          return;
        }
        const status = String(ride.status || "");
        if (status === "cancelled") return;
        if (status !== "awaitingCashPayment" && status !== "completed") return;

        const fare = Math.trunc(Number(ride.fareAmountIqd) || 0);
        const driverId = String(ride.driverId || "");
        let commissionPercent = defaultCommissionPercent;
        const subId = String(ride.subDistrictId || "");
        if (subId) {
          const subSnap = await tx.get(db().collection("serviceSubDistricts").doc(subId));
          const sub = subSnap.data() || {};
          if (
            sub.useGlobalCommission === false &&
            Number.isFinite(Number(sub.commissionPercent))
          ) {
            commissionPercent = Number(sub.commissionPercent);
          }
        }
        const platformCommissionIqd = Math.round((fare * commissionPercent) / 100);
        const driverEarningsIqd = Math.max(0, fare - platformCommissionIqd);

        tx.update(rideRef, {
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          commissionPercent,
          platformCommissionIqd,
          driverEarningsIqd,
          earningsApplied: true,
        });

        if (driverId) {
          tx.update(db().collection("drivers").doc(driverId), {
            totalFareCollectedIqd: admin.firestore.FieldValue.increment(fare),
            totalPlatformCommissionIqd: admin.firestore.FieldValue.increment(
              platformCommissionIqd,
            ),
            outstandingPlatformCommissionIqd: admin.firestore.FieldValue.increment(
              platformCommissionIqd,
            ),
            totalDriverEarningsIqd: admin.firestore.FieldValue.increment(
              driverEarningsIqd,
            ),
            outstandingDriverEarningsIqd: admin.firestore.FieldValue.increment(
              driverEarningsIqd,
            ),
            completedRidesCount: admin.firestore.FieldValue.increment(1),
            hasActiveRide: false,
            operationalStatus: "available",
          });
        }
        didApply = true;
      });
      if (didApply) applied += 1;
    }

    return { ok: true, applied };
  });

  return {
    createRide,
    acceptRide,
    rejectRide,
    startRide,
    endRideAwaitingCash,
    confirmCashCollected,
    cancelRide,
    assignNearestDriver,
    submitDriverRating,
    applyPendingRideEarnings,
  };
}

module.exports = { createRidesModule };
