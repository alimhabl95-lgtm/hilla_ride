const { isWithinBoundary, distanceKm } = require("./geo");

/**
 * Server-authoritative ride lifecycle mutations.
 */
function createRidesModule({ admin, functions, assertAdminPermissionAny }) {
  const db = () => admin.firestore();

  /**
   * Soft area check for booking — selected ناحية (+ buffer), or any active
   * ناحية in the same district. Avoid unique/nearest rejects when Admin
   * circles overlap (common for الشوملي / مركز الهاشمية).
   */
  async function assertWithinServiceArea({
    districtId,
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

    const resolvedDistrictId = String(districtId || sub.districtId || "").trim();
    const selected = {
      center: { lat: Number(sub.latitude) || 0, lng: Number(sub.longitude) || 0 },
      radiusKm: Number(sub.searchRadiusKm) || 22,
      boundary: Array.isArray(sub.boundary) ? sub.boundary : undefined,
    };

    let districtSubs = [selected];
    if (resolvedDistrictId) {
      const peersSnap = await db()
        .collection("serviceSubDistricts")
        .where("districtId", "==", resolvedDistrictId)
        .where("status", "==", "active")
        .get();
      districtSubs = peersSnap.docs.map((doc) => {
        const data = doc.data() || {};
        return {
          center: { lat: Number(data.latitude) || 0, lng: Number(data.longitude) || 0 },
          radiusKm: Number(data.searchRadiusKm) || 22,
          boundary: Array.isArray(data.boundary) ? data.boundary : undefined,
        };
      });
      if (districtSubs.length === 0) {
        districtSubs = [selected];
      }
    }

    function nearArea(point, area) {
      const softRadius = Math.max(Number(area.radiusKm) || 22, 12) + 12;
      if (isWithinBoundary(point, area.center, softRadius, area.boundary)) {
        return true;
      }
      return distanceKm(area.center, point) <= softRadius;
    }

    function pointAllowed(point) {
      if (nearArea(point, selected)) return true;
      return districtSubs.some((area) => nearArea(point, area));
    }

    for (const point of [pickup, destination]) {
      if (!point) continue;
      if (!pointAllowed(point)) {
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

  const DEFAULT_PRICING = {
    maxDistanceKm: 5,
    brackets: [
      { minKm: 0, maxKm: 1.25, priceIqd: 1000 },
      { minKm: 1.26, maxKm: 2.0, priceIqd: 2000 },
      { minKm: 2.01, maxKm: 3.5, priceIqd: 3000 },
      { minKm: 3.51, maxKm: 5.0, priceIqd: 5000 },
    ],
  };

  async function loadPricingConfig(districtId, subDistrictId) {
    const district = String(districtId || "").trim();
    const sub = String(subDistrictId || "").trim();
    const candidates = [];
    if (district && sub) {
      candidates.push(`pricing_${district}_${sub}`);
    }
    if (district) {
      candidates.push(`pricing_${district}`);
    }
    candidates.push("pricing");
    for (const id of candidates) {
      const snap = await db().collection("config").doc(id).get();
      if (!snap.exists) continue;
      const data = snap.data() || {};
      const maxDistanceKm = Number(data.maxDistanceKm) || DEFAULT_PRICING.maxDistanceKm;
      const rawBrackets = Array.isArray(data.brackets) ? data.brackets : DEFAULT_PRICING.brackets;
      const brackets = rawBrackets
        .map((b) => ({
          minKm: Number(b.minKm) || 0,
          maxKm: Number(b.maxKm) || 0,
          priceIqd: Math.trunc(Number(b.priceIqd) || 0),
        }))
        .filter((b) => b.priceIqd > 0 && b.maxKm >= b.minKm);
      if (brackets.length === 0) continue;
      return { maxDistanceKm, brackets };
    }
    return DEFAULT_PRICING;
  }

  function quoteFareFromDistanceKm(distanceKm, config) {
    if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
      return { ok: false, reason: "invalid_distance" };
    }
    if (distanceKm > config.maxDistanceKm + 0.05) {
      return { ok: false, reason: "out_of_range" };
    }
    for (const bracket of config.brackets) {
      if (distanceKm >= bracket.minKm && distanceKm <= bracket.maxKm + 0.05) {
        return { ok: true, fareIqd: bracket.priceIqd };
      }
    }
    return { ok: false, reason: "no_bracket" };
  }

  async function assertFareMatchesQuote({
    districtId,
    subDistrictId,
    pickupLat,
    pickupLng,
    destinationLat,
    destinationLng,
    distanceKm,
    fareAmountIqd,
    originalFareIqd,
    promoDiscountIqd,
    loyaltyFreeRide,
  }) {
    if (loyaltyFreeRide) return;

    const straightKm = haversineKm(pickupLat, pickupLng, destinationLat, destinationLng);
    const estimatedRoadKm = straightKm * 1.3;
    const clientKm = Number(distanceKm) || 0;
    if (clientKm <= 0 || clientKm > estimatedRoadKm * 1.35 + 0.5) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_distance");
    }

    const pricing = await loadPricingConfig(districtId, subDistrictId);
    const quoteKm = Math.max(clientKm, estimatedRoadKm * 0.85);
    const quote = quoteFareFromDistanceKm(quoteKm, pricing);
    if (!quote.ok) {
      throw new functions.https.HttpsError("failed-precondition", "out_of_service");
    }

    const expectedFare = quote.fareIqd;
    const discount = Math.max(0, Math.trunc(Number(promoDiscountIqd) || 0));
    const original = Math.trunc(Number(originalFareIqd) || 0);
    if (discount > 0) {
      const base = original > 0 ? original : expectedFare;
      if (base !== expectedFare) {
        throw new functions.https.HttpsError("invalid-argument", "invalid_fare");
      }
      const expectedNet = Math.max(0, base - discount);
      if (Math.trunc(Number(fareAmountIqd) || 0) !== expectedNet) {
        throw new functions.https.HttpsError("invalid-argument", "invalid_fare");
      }
      return;
    }

    if (Math.trunc(Number(fareAmountIqd) || 0) !== expectedFare) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_fare");
    }
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

  async function driverMatchingPoint(driverData) {
    const d = driverData || {};
    let lat = Number(d.latitude ?? d.lastLat ?? d.lat);
    let lng = Number(d.longitude ?? d.lastLng ?? d.lng);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng };
    }
    const subId = String(d.assignedSubDistrictId || "").trim();
    if (!subId) return null;
    const subSnap = await db().collection("serviceSubDistricts").doc(subId).get();
    if (!subSnap.exists) return null;
    const sub = subSnap.data() || {};
    lat = Number(sub.latitude);
    lng = Number(sub.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    return { lat, lng };
  }

  function baghdadKeys(date = new Date()) {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Baghdad",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(date);
    const part = (type) => parts.find((item) => item.type === type).value;
    const dayKey = `${part("year")}-${part("month")}-${part("day")}`;
    return { dayKey, monthKey: dayKey.slice(0, 7) };
  }

  function rejectionDashboardPatch(driverData) {
    const keys = baghdadKeys();
    const data = driverData || {};
    const dayCount =
      data.rejectedDayKey === keys.dayKey ? Number(data.rejectedDayCount) || 0 : 0;
    const monthCount =
      data.rejectedMonthKey === keys.monthKey
        ? Number(data.rejectedMonthCount) || 0
        : 0;
    return {
      rejectedDayKey: keys.dayKey,
      rejectedDayCount: dayCount + 1,
      rejectedMonthKey: keys.monthKey,
      rejectedMonthCount: monthCount + 1,
    };
  }

  function dashboardCounterPatch(driverData, earningsIqd) {
    const keys = baghdadKeys();
    const data = driverData || {};
    const dayCount =
      data.completedDayKey === keys.dayKey ? Number(data.completedDayCount) || 0 : 0;
    const monthCount =
      data.completedMonthKey === keys.monthKey
        ? Number(data.completedMonthCount) || 0
        : 0;
    const monthEarnings =
      data.earningsMonthKey === keys.monthKey ? Number(data.earningsMonthIqd) || 0 : 0;
    return {
      completedDayKey: keys.dayKey,
      completedDayCount: dayCount + 1,
      completedMonthKey: keys.monthKey,
      completedMonthCount: monthCount + 1,
      monthlyRideCount: monthCount + 1,
      earningsMonthKey: keys.monthKey,
      earningsMonthIqd: monthEarnings + Math.max(0, Math.trunc(earningsIqd) || 0),
    };
  }

  async function resolvePickupSubDistrictId(lat, lng, fallbackId) {
    const snap = await db()
      .collection("serviceSubDistricts")
      .where("status", "==", "active")
      .get();
    let bestId = "";
    let bestKm = Infinity;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const centerLat = Number(data.latitude);
      const centerLng = Number(data.longitude);
      if (!Number.isFinite(centerLat) || !Number.isFinite(centerLng)) continue;
      const km = haversineKm(lat, lng, centerLat, centerLng);
      const radius = Math.max(Number(data.searchRadiusKm) || 22, 8);
      if (km <= radius + 3 && km < bestKm) {
        bestKm = km;
        bestId = doc.id;
      }
    }
    return bestId || String(fallbackId || "").trim();
  }

  async function driverStillBusy(driverId) {
    const snap = await db()
      .collection("rides")
      .where("driverId", "==", driverId)
      .where("status", "in", ["accepted", "inProgress", "awaitingCashPayment"])
      .limit(1)
      .get();
    return !snap.empty;
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
    const pickupLat = Number(ride.pickupLat);
    const pickupLng = Number(ride.pickupLng);
    let subDistrictId = await resolvePickupSubDistrictId(
      pickupLat,
      pickupLng,
      ride.subDistrictId,
    );
    if (subDistrictId && subDistrictId !== String(ride.subDistrictId || "").trim()) {
      await rideRef.set(
        { subDistrictId },
        { merge: true },
      );
    }
    const walletConfig = await getWalletConfig();
    const exclude = new Set(excludeDriverIds.map(String));
    const rideRejected = Array.isArray(ride.rejectedDriverIds)
      ? ride.rejectedDriverIds.map(String)
      : [];
    rideRejected.forEach((id) => exclude.add(id));

    // Only drivers approved for this exact ناحية (service area).
    if (!subDistrictId) {
      await rideRef.set(
        {
          status: "searching",
          offeredDriverIds: [],
          notifyDrivers: false,
        },
        { merge: true },
      );
      throw new functions.https.HttpsError("failed-precondition", "no_service_area");
    }

    const driversSnap = await db()
      .collection("drivers")
      .where("isOnline", "==", true)
      .where("approvalStatus", "==", "approved")
      .where("assignedSubDistrictId", "==", subDistrictId)
      .limit(40)
      .get();

    const candidates = [];
    for (const doc of driversSnap.docs) {
      if (exclude.has(doc.id)) continue;
      const d = doc.data() || {};
      if (d.isBlocked === true) continue;
      if (d.hasActiveRide === true) {
        // Repair stale busy flag so eligible drivers are not skipped forever.
        const stillBusy = await driverStillBusy(doc.id);
        if (stillBusy) continue;
        await doc.ref.set({ hasActiveRide: false }, { merge: true });
      }
      const balance = Number(d.walletBalanceIqd) || 0;
      const walletStatus = String(d.walletStatus || "active");
      if (walletStatus === "blocked" || balance < walletConfig.minBalanceIqd) {
        continue;
      }
      if (String(d.assignedSubDistrictId || "").trim() !== subDistrictId) {
        continue;
      }
      const point = await driverMatchingPoint(d);
      if (!point) continue;
      const km = haversineKm(pickupLat, pickupLng, point.lat, point.lng);
      candidates.push({ id: doc.id, km });
    }
    candidates.sort((a, b) => a.km - b.km);
    if (candidates.length === 0) {
      functions.logger.info("assignNearestDriver no candidates", {
        rideId,
        districtId,
        subDistrictId,
        onlineInQuery: driversSnap.size,
        minBalanceIqd: walletConfig.minBalanceIqd,
      });
    }
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
    await db().runTransaction(async (tx) => {
      const freshSnap = await tx.get(rideRef);
      if (!freshSnap.exists) return;
      const fresh = freshSnap.data() || {};
      if (String(fresh.driverId || "").trim()) return;
      const freshStatus = String(fresh.status || "");
      if (freshStatus !== "searching" && freshStatus !== "matched") return;
      const rejected = new Set(exclude);
      const freshRejected = Array.isArray(fresh.rejectedDriverIds)
        ? fresh.rejectedDriverIds.map(String)
        : [];
      freshRejected.forEach((id) => rejected.add(id));
      const safeOffered = offered.filter((id) => !rejected.has(id));
      if (safeOffered.length === 0) {
        tx.set(
          rideRef,
          {
            status: "searching",
            offeredDriverIds: [],
            rejectedDriverIds: Array.from(rejected),
            notifyDrivers: false,
          },
          { merge: true },
        );
        return;
      }
      tx.set(
        rideRef,
        {
          status: "matched",
          offeredDriverIds: safeOffered,
          rejectedDriverIds: Array.from(rejected),
          notifyDrivers: true,
          matchedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    return { rideId, status: "matched", offeredDriverIds: offered };
  }

  async function getLoyaltyConfig() {
    const doc = await db().collection("config").doc("loyalty").get();
    const data = doc.data() || {};
    return {
      enabled: data.enabled === true,
      ridesRequired: Math.max(1, Math.trunc(Number(data.ridesRequired) || 10)),
      repeats: data.repeats !== false,
    };
  }

  function shouldGrantLoyaltyFreeRide(count, ridesRequired, repeats) {
    if (!Number.isFinite(count) || count <= 0) return false;
    if (repeats) return count % ridesRequired === 0;
    return count === ridesRequired;
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
    let fareAmountIqd = Math.trunc(Number(data.fareAmountIqd) || 0);
    const distanceKm = Number(data.distanceKm) || 0;
    let originalFareIqd = Math.trunc(Number(data.originalFareIqd) || 0);
    let promoDiscountIqd = Math.trunc(Number(data.promoDiscountIqd) || 0);
    let promoCode = String(data.promoCode || "").trim();
    let loyaltyFreeRide =
      data.loyaltyFreeRide === true ||
      promoCode.toUpperCase() === "LOYALTY";

    if (
      !pickupLabel ||
      !destinationLabel ||
      !Number.isFinite(pickupLat) ||
      !Number.isFinite(pickupLng) ||
      !Number.isFinite(destinationLat) ||
      !Number.isFinite(destinationLng)
    ) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid ride payload.");
    }

    if (loyaltyFreeRide) {
      const userSnap = await db().collection("users").doc(customerId).get();
      const userData = userSnap.data() || {};
      const remaining = Math.trunc(Number(userData.loyaltyFreeRidesRemaining) || 0);
      if (remaining <= 0) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "loyalty_free_unavailable",
        );
      }
      const quoted =
        originalFareIqd > 0
          ? originalFareIqd
          : Math.max(fareAmountIqd, promoDiscountIqd, 0);
      if (quoted <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid ride payload.");
      }
      originalFareIqd = quoted;
      promoDiscountIqd = quoted;
      fareAmountIqd = 0;
      promoCode = "LOYALTY";
      loyaltyFreeRide = true;
    } else if (fareAmountIqd <= 0) {
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
      districtId,
      subDistrictId,
      pickup: { lat: pickupLat, lng: pickupLng },
      destination: { lat: destinationLat, lng: destinationLng },
    });

    await assertFareMatchesQuote({
      districtId,
      subDistrictId,
      pickupLat,
      pickupLng,
      destinationLat,
      destinationLng,
      distanceKm,
      fareAmountIqd,
      originalFareIqd,
      promoDiscountIqd,
      loyaltyFreeRide,
    });

    const matchedSubDistrictId = await resolvePickupSubDistrictId(
      pickupLat,
      pickupLng,
      subDistrictId,
    );

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
        subDistrictId: matchedSubDistrictId || subDistrictId,
        distanceKm,
        offeredDriverIds: [],
        notifyDrivers: false,
        notifyCustomer: false,
        ...(originalFareIqd > 0 ? { originalFareIqd } : {}),
        ...(promoDiscountIqd > 0 ? { promoDiscountIqd } : {}),
        ...(promoCode ? { promoCode } : {}),
        ...(loyaltyFreeRide ? { loyaltyFreeRide: true } : {}),
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

      const rideSubDistrictId = String(ride.subDistrictId || "").trim();
      const driverSubDistrictId = String(driver.assignedSubDistrictId || "").trim();
      if (
        !rideSubDistrictId ||
        !driverSubDistrictId ||
        driverSubDistrictId !== rideSubDistrictId
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "ride_unavailable",
        );
      }
      const rejectedIds = Array.isArray(ride.rejectedDriverIds)
        ? ride.rejectedDriverIds.map(String)
        : [];
      if (rejectedIds.includes(driverId)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "ride_unavailable",
        );
      }

      if (status === "searching") {
        const rideDistrictId = String(ride.districtId || "");
        const driverDistrictId = String(driver.assignedDistrictId || "");
        if (!rideDistrictId || driverDistrictId !== rideDistrictId) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "ride_unavailable",
          );
        }
      } else {
        const offered = Array.isArray(ride.offeredDriverIds)
          ? ride.offeredDriverIds.map(String)
          : [];
        if (!assignedDriverId && !offered.includes(driverId)) {
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
      // Allow reject when driver is in the offer list, OR when the offer was a
      // district-wide matched ride (empty offeredDriverIds).
      if (offered.length > 0 && !offered.includes(driverId)) {
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

    // Timestamped record so the driver dashboard can count rejections as
    // "cancelled" rides for today / this month.
    const rejection = {
      rideId,
      driverId,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedAtMillis: Date.now(),
    };
    try {
      await db()
        .collection("driverRideRejections")
        .doc(`${rideId}_${driverId}`)
        .set(rejection, { merge: true });
    } catch (error) {
      functions.logger.warn("rejectRide record failed", {
        rideId,
        driverId,
        message: error && error.message ? error.message : String(error),
      });
    }
    try {
      await db()
        .collection("drivers")
        .doc(driverId)
        .collection("rideRejections")
        .doc(rideId)
        .set(rejection, { merge: true });
    } catch (error) {
      functions.logger.warn("rejectRide driver record failed", {
        rideId,
        driverId,
        message: error && error.message ? error.message : String(error),
      });
    }
    try {
      const driverRef = db().collection("drivers").doc(driverId);
      const driverSnap = await driverRef.get();
      await driverRef.set(
        rejectionDashboardPatch(driverSnap.data() || {}),
        { merge: true },
      );
    } catch (error) {
      functions.logger.warn("rejectRide dashboard counters failed", {
        rideId,
        driverId,
        message: error && error.message ? error.message : String(error),
      });
    }

    if (shouldReassign) {
      try {
        await assignNearestDriverInternal(rideId, Array.from(rejectedIds));
      } catch (error) {
        functions.logger.warn("rejectRide reassign failed", {
          rideId,
          message: error && error.message ? error.message : String(error),
        });
      }
    }
    return { ok: true, reassigned: shouldReassign };
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
    const loyaltyConfig = await getLoyaltyConfig();

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
      let subSnap = null;
      if (subId) {
        subSnap = await tx.get(db().collection("serviceSubDistricts").doc(subId));
      }
      const customerId = String(ride.customerId || "");
      let customerSnap = null;
      if (customerId) {
        customerSnap = await tx.get(db().collection("users").doc(customerId));
      }
      let driverSnapForStats = null;
      if (driverId) {
        driverSnapForStats = await tx.get(db().collection("drivers").doc(driverId));
      }

      if (subSnap && subSnap.exists) {
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
          // Wallet prepaid settlement: do not grow cash "outstanding" here.
          // onRideUpdated debits the wallet; only failed debits keep debt.
          totalDriverEarningsIqd: admin.firestore.FieldValue.increment(
            driverEarningsIqd,
          ),
          completedRidesCount: admin.firestore.FieldValue.increment(1),
          hasActiveRide: false,
          operationalStatus: "available",
          ...dashboardCounterPatch(
            driverSnapForStats ? driverSnapForStats.data() : {},
            driverEarningsIqd,
          ),
        });
      }

      if (customerId && customerSnap) {
        const customer = customerSnap.data() || {};
        const promoCode = String(ride.promoCode || "");
        const promoDiscountIqd = Number(ride.promoDiscountIqd) || 0;
        const isLoyaltyFree =
          ride.loyaltyFreeRide === true ||
          promoCode.toUpperCase() === "LOYALTY";
        const nextCompleted =
          Math.trunc(Number(customer.completedRidesCount) || 0) + 1;
        const customerUpdate = {
          completedRidesCount: nextCompleted,
        };

        if (promoCode && promoDiscountIqd > 0 && !isLoyaltyFree) {
          customerUpdate.promoRidesUsed = admin.firestore.FieldValue.increment(1);
        }

        if (isLoyaltyFree) {
          const remaining = Math.max(
            0,
            Math.trunc(Number(customer.loyaltyFreeRidesRemaining) || 0) - 1,
          );
          customerUpdate.loyaltyFreeRidesRemaining = remaining;
          customerUpdate.loyaltyFreeRidesRedeemed =
            admin.firestore.FieldValue.increment(1);
        } else if (loyaltyConfig.enabled) {
          if (
            shouldGrantLoyaltyFreeRide(
              nextCompleted,
              loyaltyConfig.ridesRequired,
              loyaltyConfig.repeats,
            )
          ) {
            customerUpdate.loyaltyFreeRidesRemaining =
              admin.firestore.FieldValue.increment(1);
            customerUpdate.loyaltyFreeRidesEarned =
              admin.firestore.FieldValue.increment(1);
          }
        }

        tx.set(
          db().collection("users").doc(customerId),
          customerUpdate,
          { merge: true },
        );
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
        let driverSnapForStats = null;
        if (driverId) {
          driverSnapForStats = await tx.get(db().collection("drivers").doc(driverId));
        }
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
            totalDriverEarningsIqd: admin.firestore.FieldValue.increment(
              driverEarningsIqd,
            ),
            completedRidesCount: admin.firestore.FieldValue.increment(1),
            hasActiveRide: false,
            operationalStatus: "available",
            ...dashboardCounterPatch(
              driverSnapForStats ? driverSnapForStats.data() : {},
              driverEarningsIqd,
            ),
          });
        }
        didApply = true;
      });
      if (didApply) applied += 1;
    }

    return { ok: true, applied };
  });

  const onRideDispatchSync = functions.firestore
    .document("rides/{rideId}")
    .onWrite(async (change, context) => {
      if (!change.after.exists) return;
      const before = change.before.exists ? change.before.data() || {} : null;
      const ride = change.after.data() || {};
      const status = String(ride.status || "");
      if (String(ride.driverId || "").trim()) return;
      const offered = Array.isArray(ride.offeredDriverIds)
        ? ride.offeredDriverIds
        : [];
      if (offered.length > 0) return;

      const beforeStatus = before ? String(before.status || "") : "";
      const isNewRide = before == null;
      const needsDispatch =
        status === "searching" &&
        (isNewRide || beforeStatus !== "searching");
      const rematchedAfterReject =
        status === "searching" && beforeStatus === "matched";
      if (!needsDispatch && !rematchedAfterReject) return;

      const rejectedExclude = Array.isArray(ride.rejectedDriverIds)
        ? ride.rejectedDriverIds.map(String)
        : [];

      try {
        await assignNearestDriverInternal(context.params.rideId, rejectedExclude);
      } catch (error) {
        if (error.code !== "failed-precondition") {
          functions.logger.warn("onRideDispatchSync failed", {
            rideId: context.params.rideId,
            message: error.message,
          });
        }
      }
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
    onRideDispatchSync,
    submitDriverRating,
    applyPendingRideEarnings,
  };
}

module.exports = { createRidesModule };
