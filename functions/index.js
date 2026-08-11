const functions = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

require("dotenv").config();

if (!admin.apps.length) {
  admin.initializeApp();
}

/** Late-bound rewards module (created after applyWalletDelta). */
const rewardsRuntime = { mod: null };

const AUTH_ADMIN_SERVICE_ACCOUNT =
  "firebase-adminsdk-fbsvc@hello-tiktok-57dc5.iam.gserviceaccount.com";

function authAdminCallable(handler) {
  return functions
    .runWith({ serviceAccount: AUTH_ADMIN_SERVICE_ACCOUNT })
    .https.onCall(handler);
}

(function hydrateTwilioEnvironment() {
  try {
    const cfg = functions.config().twilio || {};
    if (!process.env.TWILIO_ACCOUNT_SID && cfg.account_sid) {
      process.env.TWILIO_ACCOUNT_SID = cfg.account_sid;
    }
    if (!process.env.TWILIO_AUTH_TOKEN && cfg.auth_token) {
      process.env.TWILIO_AUTH_TOKEN = cfg.auth_token;
    }
    if (!process.env.TWILIO_VERIFY_SERVICE_SID && cfg.verify_service_sid) {
      process.env.TWILIO_VERIFY_SERVICE_SID = cfg.verify_service_sid;
    }
  } catch (_) {
    // Runtime config may be unavailable locally.
  }
})();

const {
  createSendWhatsAppOtp,
  createVerifyWhatsAppOtp,
  createSignUpWithVerifiedPhone,
  runSignUpWithVerifiedPhone,
  createResetPasswordByPhoneVerified,
  createSendWhatsAppOtpDebug,
  getSignupPromoFields,
  authEmailFromPhoneKey,
  runResetPasswordByPhone,
} = require("./whatsapp_otp");

const sendWhatsAppOtpV1 = createSendWhatsAppOtp(normalizePhone);
const verifyWhatsAppOtpV1 = createVerifyWhatsAppOtp(normalizePhone);
const signUpWithVerifiedPhoneV1 = createSignUpWithVerifiedPhone(normalizePhone);
const resetPasswordByPhoneVerifiedV1 = createResetPasswordByPhoneVerified(normalizePhone);

async function sendToToken(token, title, body, data = {}, soundName, options = {}) {
  if (!token) return false;
  try {
    const isBroadcast = data.type === "admin_broadcast";
    const dataOnly = options.dataOnly === true;
    const channelId = isBroadcast
      ? "admin_announcements"
      : soundName === "driver_ride_request"
        ? "driver_ride_requests_v3"
        : "customer_ride_updates_v3";
    const payloadData = Object.fromEntries(
      Object.entries({ ...data, title, body }).map(([key, value]) => [
        key,
        String(value),
      ]),
    );

    const message = {
      token,
      data: payloadData,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: isBroadcast ? "default" : `${soundName}.wav`,
            badge: 1,
            ...(dataOnly ? { "content-available": 1 } : {}),
          },
        },
      },
    };

    if (!dataOnly) {
      message.notification = { title, body };
      message.android.notification = {
        channelId,
        sound: isBroadcast ? "default" : soundName,
        defaultSound: isBroadcast,
        priority: "max",
      };
    }

    await admin.messaging().send(message);
    return true;
  } catch (error) {
    functions.logger.error("FCM send failed", { token, soundName, error: error.message });
    return false;
  }
}

function encodeGeohash(latitude, longitude, precision = 6) {
  const base32 = "0123456789bcdefghjkmnpqrstuvwxyz";
  let latMin = -90;
  let latMax = 90;
  let lngMin = -180;
  let lngMax = 180;
  let hash = "";
  let bit = 0;
  let ch = 0;
  let isLng = true;
  while (hash.length < precision) {
    if (isLng) {
      const mid = (lngMin + lngMax) / 2;
      if (longitude >= mid) {
        ch = (ch << 1) + 1;
        lngMin = mid;
      } else {
        ch <<= 1;
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        ch = (ch << 1) + 1;
        latMin = mid;
      } else {
        ch <<= 1;
        latMax = mid;
      }
    }
    isLng = !isLng;
    bit += 1;
    if (bit === 5) {
      hash += base32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

function deriveOperationalStatus(driverData, rideStatus) {
  const isOnline = driverData.isOnline === true;
  const hasActiveRide = driverData.hasActiveRide === true;
  if (!isOnline) return "offline";
  if (!hasActiveRide) return "available";
  switch (String(rideStatus || "")) {
    case "matched":
      return "rideOffered";
    case "accepted":
      return "arrivingPickup";
    case "inProgress":
    case "awaitingCashPayment":
      return "onTrip";
    case "completed":
      return "completed";
    default:
      return "rideAccepted";
  }
}

async function syncMapPresenceFromDriver(driverId, driverData, rideStatus) {
  const db = admin.firestore();
  const presenceRef = db.collection("mapPresence").doc(driverId);
  if (!driverData) {
    await presenceRef.delete().catch(() => null);
    return;
  }

  const lat = Number(driverData.latitude);
  const lng = Number(driverData.longitude);
  const isOnline = driverData.isOnline === true;
  const approved = String(driverData.approvalStatus || "") === "approved";
  const blocked = driverData.isBlocked === true || driverData.isRemoved === true;
  const explicitStatus = String(driverData.operationalStatus || "").trim();
  const status =
    explicitStatus ||
    deriveOperationalStatus(driverData, rideStatus);

  const shouldPublish =
    isOnline &&
    approved &&
    !blocked &&
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    status === "available";

  if (!shouldPublish) {
    // Keep a tombstone offline/busy doc out of available queries by deleting.
    await presenceRef.delete().catch(() => null);
    if (explicitStatus !== status && driverData) {
      await db
        .collection("drivers")
        .doc(driverId)
        .set({ operationalStatus: status }, { merge: true })
        .catch(() => null);
    }
    return;
  }

  const geohash =
    String(driverData.geohash || "").trim() || encodeGeohash(lat, lng);

  await presenceRef.set(
    {
      providerId: driverId,
      role: "driver",
      serviceType: "ride",
      status: "available",
      latitude: lat,
      longitude: lng,
      heading: Number(driverData.heading) || 0,
      geohash,
      vehicleType: String(driverData.vehicleType || "tukTuk"),
      displayName: String(driverData.name || ""),
      photoUrl: String(driverData.profilePhotoUrl || ""),
      rating: Number(driverData.rating) || 5,
      phone: String(driverData.phone || ""),
      locationUpdatedAt:
        driverData.locationUpdatedAt ||
        admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

exports.onDriverWritten = functions.firestore
  .document("drivers/{driverId}")
  .onWrite(async (change, context) => {
    const driverId = context.params.driverId;
    if (!change.after.exists) {
      await admin
        .firestore()
        .collection("mapPresence")
        .doc(driverId)
        .delete()
        .catch(() => null);
      return null;
    }
    await syncMapPresenceFromDriver(driverId, change.after.data() || {});
    return null;
  });

exports.cleanupStaleMapPresence = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 1000),
    );
    const snapshot = await db
      .collection("mapPresence")
      .where("locationUpdatedAt", "<", cutoff)
      .limit(200)
      .get();
    if (snapshot.empty) return null;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    functions.logger.info("cleanupStaleMapPresence", {
      deleted: snapshot.size,
    });
    return null;
  });

exports.onRideUpdated = functions.firestore
  .document("rides/{rideId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const rideId = context.params.rideId;

    const becameMatched =
      before.status !== "matched" && after.status === "matched";
    const notifyDriversFlag =
      after.notifyDrivers === true && before.notifyDrivers !== true;
    const shouldNotifyDrivers =
      (becameMatched || notifyDriversFlag) &&
      Array.isArray(after.offeredDriverIds) &&
      after.offeredDriverIds.length > 0 &&
      !after.driverId;

    if (shouldNotifyDrivers) {
      const newlyOffered = (after.offeredDriverIds || []).filter((id) => {
        const beforeIds = Array.isArray(before.offeredDriverIds)
          ? before.offeredDriverIds.map(String)
          : [];
        return !beforeIds.includes(String(id));
      });
      if (rewardsRuntime.mod && newlyOffered.length > 0) {
        try {
          await rewardsRuntime.mod.bumpOfferStats(
            newlyOffered,
            "statsOffersReceived",
          );
        } catch (_) {}
      }
      for (const offeredDriverId of after.offeredDriverIds) {
        const driverRef = admin
          .firestore()
          .collection("drivers")
          .doc(String(offeredDriverId));
        const driverDoc = await driverRef.get();
        const driverData = driverDoc.data() || {};
        if (driverData.isFakeDriver && driverData.autoAcceptRides) {
          continue;
        }
        if (driverData.isOnline === true && driverData.hasActiveRide !== true) {
          await driverRef.set(
            { operationalStatus: "rideOffered" },
            { merge: true },
          );
        }
        await sendToToken(
          driverData.fcmToken,
          "New ride request",
          `${after.pickupLabel} → ${after.destinationLabel}`,
          { rideId, type: "ride_matched" },
          "driver_ride_request",
        );
      }
    }

    // Assigned / started / completed status → update driver operationalStatus.
    if (after.driverId && before.status !== after.status) {
      const driverRef = admin
        .firestore()
        .collection("drivers")
        .doc(String(after.driverId));
      const driverDoc = await driverRef.get();
      const driverData = driverDoc.data() || {};
      let nextStatus = null;
      if (after.status === "accepted") nextStatus = "arrivingPickup";
      if (after.status === "inProgress" || after.status === "awaitingCashPayment") {
        nextStatus = "onTrip";
      }
      if (after.status === "completed" || after.status === "cancelled") {
        nextStatus = driverData.isOnline ? "available" : "offline";
      }
      if (nextStatus) {
        await driverRef.set({ operationalStatus: nextStatus }, { merge: true });
      }
    }

    // Offered drivers who were not selected return to available when ride leaves matched.
    if (
      before.status === "matched" &&
      after.status !== "matched" &&
      Array.isArray(before.offeredDriverIds)
    ) {
      const assigned = String(after.driverId || "");
      for (const offeredId of before.offeredDriverIds) {
        if (String(offeredId) === assigned) continue;
        const driverRef = admin
          .firestore()
          .collection("drivers")
          .doc(String(offeredId));
        const driverDoc = await driverRef.get();
        const driverData = driverDoc.data() || {};
        if (
          driverData.isOnline === true &&
          driverData.hasActiveRide !== true &&
          String(driverData.operationalStatus || "") === "rideOffered"
        ) {
          await driverRef.set(
            { operationalStatus: "available" },
            { merge: true },
          );
        }
      }
    }

    if (becameMatched && after.driverId) {
      const driverDoc = await admin.firestore().collection("drivers").doc(after.driverId).get();
      const driverData = driverDoc.data() || {};
      if (driverData.isFakeDriver && driverData.autoAcceptRides) {
        await change.after.ref.update({
          status: "accepted",
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          notifyCustomer: true,
        });
      } else {
        await sendToToken(
          driverData.fcmToken,
          "New ride request",
          `${after.pickupLabel} → ${after.destinationLabel}`,
          { rideId, type: "ride_matched" },
          "driver_ride_request",
        );
      }
    }

    const becameAccepted =
      before.status !== "accepted" && after.status === "accepted";
    const notifyCustomerFlag =
      after.notifyCustomer === true && before.notifyCustomer !== true;

    if ((becameAccepted || notifyCustomerFlag) && after.customerId) {
      const customerDoc = await admin.firestore().collection("users").doc(after.customerId).get();
      const token = customerDoc.data()?.fcmToken;
      await sendToToken(
        token,
        "Driver accepted",
        "Your driver is on the way",
        { rideId, type: "ride_accepted" },
        "customer_ride_accepted",
      );
    }

    if (before.status !== after.status) {
      const statusChanged = after.status;
      const customerId = String(after.customerId || "");
      const driverId = String(after.driverId || "");
      const cancelledBy = String(after.cancelledBy || "").trim().toLowerCase();

      if (statusChanged === "inProgress" && customerId) {
        const customerDoc = await admin
          .firestore()
          .collection("users")
          .doc(customerId)
          .get();
        await sendToToken(
          customerDoc.data()?.fcmToken,
          "Trip started",
          "Your trip has started",
          { rideId, type: "ride_in_progress" },
          "customer_ride_accepted",
        );
      }

      if (statusChanged === "completed") {
        if (customerId) {
          const customerDoc = await admin
            .firestore()
            .collection("users")
            .doc(customerId)
            .get();
          await sendToToken(
            customerDoc.data()?.fcmToken,
            "Trip completed",
            "Your trip has been completed. Thank you for riding with us!",
            { rideId, type: "ride_completed" },
            "customer_ride_accepted",
          );
        }
        if (driverId) {
          const driverDoc = await admin
            .firestore()
            .collection("drivers")
            .doc(driverId)
            .get();
          const driverUser = await admin
            .firestore()
            .collection("users")
            .doc(driverId)
            .get();
          const driverToken =
            driverDoc.data()?.fcmToken || driverUser.data()?.fcmToken;
          await sendToToken(
            driverToken,
            "Trip completed",
            "Trip completed successfully",
            { rideId, type: "ride_completed_driver" },
            "default",
          );
        }
      }

      if (statusChanged === "cancelled") {
        if (customerId) {
          const customerDoc = await admin
            .firestore()
            .collection("users")
            .doc(customerId)
            .get();
          await sendToToken(
            customerDoc.data()?.fcmToken,
            "Trip cancelled",
            "Your trip was cancelled",
            { rideId, type: "ride_cancelled" },
            "customer_ride_accepted",
          );
        }
        if (driverId) {
          const driverDoc = await admin
            .firestore()
            .collection("drivers")
            .doc(driverId)
            .get();
          const driverUser = await admin
            .firestore()
            .collection("users")
            .doc(driverId)
            .get();
          const driverToken =
            driverDoc.data()?.fcmToken || driverUser.data()?.fcmToken;
          const driverBody =
            cancelledBy === "customer"
              ? "The customer cancelled this trip"
              : "This trip was cancelled";
          await sendToToken(
            driverToken,
            "Trip cancelled",
            driverBody,
            { rideId, type: "ride_cancelled_driver", cancelledBy },
            "default",
          );
        }
      }
    }

    if (becameAccepted && after.driverId && rewardsRuntime.mod) {
      try {
        await rewardsRuntime.mod.bumpOfferStats(
          [String(after.driverId)],
          "statsOffersAccepted",
        );
      } catch (_) {}
    }

    // Track offer rejections for acceptance-rate rewards.
    const beforeRejected = new Set(
      (Array.isArray(before.rejectedDriverIds)
        ? before.rejectedDriverIds
        : []
      ).map(String),
    );
    const afterRejected = (
      Array.isArray(after.rejectedDriverIds) ? after.rejectedDriverIds : []
    ).map(String);
    const newlyRejected = afterRejected.filter((id) => !beforeRejected.has(id));
    if (newlyRejected.length > 0 && rewardsRuntime.mod) {
      try {
        await rewardsRuntime.mod.bumpOfferStats(
          newlyRejected,
          "statsOffersRejected",
        );
      } catch (_) {}
    }

    // Debit prepaid wallet commission when earnings are first applied.
    const earningsJustApplied =
      before.earningsApplied !== true &&
      after.earningsApplied === true &&
      after.walletCommissionApplied !== true;
    if (earningsJustApplied && after.driverId) {
      const baseCommission = Math.trunc(Number(after.platformCommissionIqd) || 0);
      let commission = baseCommission;
      let rewardMeta = {
        freeTripUsed: false,
        discountPercent: 0,
        activeRewardId: null,
      };
      if (rewardsRuntime.mod && baseCommission > 0) {
        try {
          rewardMeta = await rewardsRuntime.mod.resolveEffectiveCommission(
            String(after.driverId),
            baseCommission,
          );
          commission = Math.trunc(Number(rewardMeta.commissionIqd) || 0);
        } catch (error) {
          functions.logger.warn("reward commission resolve failed", {
            rideId,
            message: error.message,
          });
        }
      }
      if (commission > 0) {
        try {
          await applyWalletDelta({
            driverId: String(after.driverId),
            amountIqd: -commission,
            type: "commission",
            createdBy: "system",
            note: rewardMeta.discountPercent > 0
              ? `Trip commission for ride ${rideId} (${rewardMeta.discountPercent}% reward discount)`
              : `Trip commission for ride ${rideId}`,
            rideId,
          });
          await change.after.ref.set(
            {
              walletCommissionApplied: true,
              walletCommissionChargedIqd: commission,
              rewardCommissionDiscountPercent: rewardMeta.discountPercent || 0,
              rewardFreeTripUsed: rewardMeta.freeTripUsed === true,
              rewardActiveId: rewardMeta.activeRewardId || null,
            },
            { merge: true },
          );
        } catch (error) {
          functions.logger.error("wallet commission debit failed", {
            rideId,
            driverId: after.driverId,
            commission,
            message: error.message,
          });
          // Fall back: keep outstanding debt and block wallet.
          const config = await getWalletConfig();
          await admin
            .firestore()
            .collection("drivers")
            .doc(String(after.driverId))
            .set(
              {
                walletStatus: "blocked",
                walletUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          functions.logger.warn("driver wallet blocked after failed commission", {
            minBalanceIqd: config.minBalanceIqd,
          });
        }
      } else {
        await change.after.ref.set(
          {
            walletCommissionApplied: true,
            walletCommissionChargedIqd: 0,
            rewardCommissionDiscountPercent: rewardMeta.discountPercent || 0,
            rewardFreeTripUsed: rewardMeta.freeTripUsed === true,
            rewardActiveId: rewardMeta.activeRewardId || null,
          },
          { merge: true },
        );
      }

      // Evaluate reward campaigns after a completed (earnings-applied) trip.
      if (rewardsRuntime.mod) {
        const tripEarnings = Math.trunc(
          Number(after.driverEarningsIqd) ||
            Number(after.driverEarningIqd) ||
            0,
        );
        try {
          await rewardsRuntime.mod.evaluateDriverCampaigns(
            String(after.driverId),
            {
              tripIncrement: true,
              tripEarningsIqd: tripEarnings,
              trigger: "trip_completed",
            },
          );
        } catch (error) {
          functions.logger.warn("reward evaluate after trip failed", {
            rideId,
            driverId: after.driverId,
            message: error.message,
          });
        }
      }
    }
  });

const allowedAssistantPermissions = new Set([
  "overview",
  "pendingDrivers",
  "activeRides",
  "liveMap",
  "allDrivers",
  "customers",
  "rideHistory",
  "pricing",
  "earnings",
  "driverReviews",
  "supportInbox",
  "promoCodes",
  "monthlyLeaderboard",
  "wallet",
  "serviceAreas",
  "rewards",
  "businessPartners",
]);

function normalizePhone(raw) {
  const arabicIndic = "٠١٢٣٤٥٦٧٨٩";
  const easternArabic = "۰۱۲۳۴۵۶۷۸۹";
  let text = String(raw || "");
  for (let i = 0; i < 10; i += 1) {
    text = text.split(arabicIndic[i]).join(String(i));
    text = text.split(easternArabic[i]).join(String(i));
  }
  let digits = text.replace(/\D/g, "");
  if (digits.startsWith("964")) {
    digits = digits.substring(3);
  }
  if (digits.startsWith("0")) {
    digits = digits.substring(1);
  }
  return `+964${digits}`;
}

async function writeAdminAuditLog({
  adminId,
  action,
  entityType = "",
  entityId = "",
  details = {},
  ipAddress = "",
}) {
  try {
    let adminName = adminId || "";
    if (adminId) {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(adminId)
        .get();
      if (userDoc.exists) {
        const d = userDoc.data() || {};
        adminName = d.fullName || d.name || d.email || adminId;
      }
    }
    await admin.firestore().collection("adminAuditLogs").add({
      adminId: adminId || "",
      adminName,
      action,
      entityType,
      entityId,
      details: details && typeof details === "object" ? details : {},
      ipAddress: ipAddress || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    functions.logger.warn("writeAdminAuditLog failed", {
      action,
      error: String(error),
    });
  }
}

async function assertAdminPermission(context, permission) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "User profile not found.");
  }

  const role = userDoc.data()?.role;
  const permissions = Array.isArray(userDoc.data()?.permissions)
    ? userDoc.data().permissions
    : [];
  const allowed =
    role === "manager" ||
    (role === "assistant" && permissions.includes(permission));

  if (!allowed) {
    throw new functions.https.HttpsError(
      "permission-denied",
      `${permission} permission required.`,
    );
  }

  return userDoc;
}

async function assertAdminPermissionAny(context, permissions) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "User profile not found.");
  }

  const role = userDoc.data()?.role;
  const granted = Array.isArray(userDoc.data()?.permissions)
    ? userDoc.data().permissions
    : [];

  const allowed =
    role === "manager" ||
    (role === "assistant" &&
      permissions.some((permission) => granted.includes(permission)));

  if (!allowed) {
    throw new functions.https.HttpsError(
      "permission-denied",
      `${permissions.join(" or ")} permission required.`,
    );
  }

  return userDoc;
}

exports.createAssistant = functions.https.onCall(async (data, context) => {
  functions.logger.info("createAssistant started", {
    callerUid: context.auth?.uid || null,
  });

  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }

    const managerDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();
    if (!managerDoc.exists || managerDoc.data()?.role !== "manager") {
      throw new functions.https.HttpsError("permission-denied", "Managers only.");
    }

    const payload = parseCallableData(data);
    const name = String(payload.name || "").trim();
    const email = String(payload.email || "").trim().toLowerCase();
    const password = String(payload.password || "");
    const permissions = Array.isArray(payload.permissions) ? payload.permissions : [];
    const roleTemplate = String(payload.roleTemplate || "").trim();

    const emailIsValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    if (!name || !emailIsValid || password.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Enter a valid name, email, and password (6+ characters).",
      );
    }

    const sanitizedPermissions = permissions.filter((permission) =>
      allowedAssistantPermissions.has(permission),
    );

    try {
      const existing = await admin.auth().getUserByEmail(email);
      functions.logger.warn("createAssistant blocked duplicate auth user", {
        email,
        uid: existing.uid,
      });
      throw new functions.https.HttpsError(
        "already-exists",
        "This email is already registered.",
      );
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      if (error.code !== "auth/user-not-found") {
        functions.logger.error("createAssistant auth lookup failed", {
          email,
          code: error.code,
          message: error.message,
        });
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Could not verify email. Try again.",
        );
      }
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
      });
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        throw new functions.https.HttpsError(
          "already-exists",
          "This email is already registered.",
        );
      }
      functions.logger.error("createAssistant createUser failed", {
        email,
        code: error.code,
        message: error.message,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Could not create assistant login. Try again.",
      );
    }

    try {
      await admin.firestore().collection("users").doc(userRecord.uid).set({
        name,
        phone: "",
        email,
        role: "assistant",
        age: 18,
        permissions: sanitizedPermissions,
        createdBy: context.auth.uid,
        isBlocked: false,
        cancelledRidesCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(roleTemplate ? { roleTemplate } : {}),
      });
    } catch (error) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (cleanupError) {
        functions.logger.warn("createAssistant rollback auth delete failed", {
          uid: userRecord.uid,
          code: cleanupError.code,
          message: cleanupError.message,
        });
      }
      functions.logger.error("createAssistant firestore write failed", {
        uid: userRecord.uid,
        code: error.code,
        message: error.message,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Could not save assistant profile. Try again.",
      );
    }

    functions.logger.info("createAssistant completed", {
      assistantUid: userRecord.uid,
      email,
      createdBy: context.auth.uid,
    });
    return { uid: userRecord.uid, email };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error("createAssistant unhandled", {
      message: error.message,
      code: error.code,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Could not create assistant. Try again.",
    );
  }
});

exports.savePricingConfig = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "User profile not found.");
  }

  const role = userDoc.data()?.role;
  const permissions = Array.isArray(userDoc.data()?.permissions)
    ? userDoc.data().permissions
    : [];
  const canSave =
    role === "manager" ||
    (role === "assistant" && permissions.includes("pricing"));

  if (!canSave) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Pricing permission required.",
    );
  }

  const districtId = String(data.districtId || "").trim();
  const subDistrictId = String(data.subDistrictId || "").trim();
  const maxDistanceKm = Number(data.maxDistanceKm);
  const brackets = Array.isArray(data.brackets) ? data.brackets : [];

  if (!districtId || !Number.isFinite(maxDistanceKm) || maxDistanceKm <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid pricing data.");
  }
  if (brackets.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "Add at least one bracket.");
  }

  const sanitizedBrackets = brackets.map((bracket) => ({
    minKm: Number(bracket.minKm),
    maxKm: Number(bracket.maxKm),
    priceIqd: Math.trunc(Number(bracket.priceIqd)),
  }));

  for (const bracket of sanitizedBrackets) {
    if (
      !Number.isFinite(bracket.minKm) ||
      !Number.isFinite(bracket.maxKm) ||
      !Number.isFinite(bracket.priceIqd) ||
      bracket.priceIqd < 0
    ) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid bracket values.");
    }
  }

  const docId = subDistrictId
    ? `pricing_${districtId}_${subDistrictId}`
    : `pricing_${districtId}`;

  await admin.firestore().collection("config").doc(docId).set({
    maxDistanceKm,
    brackets: sanitizedBrackets,
    districtId,
    ...(subDistrictId ? { subDistrictId } : {}),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "pricing.changed",
    entityType: "pricing",
    entityId: docId,
    details: { districtId, subDistrictId, maxDistanceKm },
  });

  return { ok: true, docId };
});

exports.saveAppConfig = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["appSettings"]);

  const readBool = (value, fallback = false) => {
    if (typeof value === "boolean") return value;
    if (value === 1 || value === "1" || value === "true") return true;
    if (value === 0 || value === "0" || value === "false") return false;
    return fallback;
  };
  const readInt = (value, fallback = 0) => {
    const n = Number(value);
    return Number.isFinite(n) ? Math.trunc(n) : fallback;
  };
  const readString = (value) => String(value ?? "").trim();

  const payload = {
    maintenanceMode: readBool(data.maintenanceMode, false),
    maintenanceMessageEn: readString(data.maintenanceMessageEn),
    maintenanceMessageAr: readString(data.maintenanceMessageAr),
    minAndroidBuild: readInt(data.minAndroidBuild, 0),
    minIosBuild: readInt(data.minIosBuild, 0),
    forceUpdateMessageEn: readString(data.forceUpdateMessageEn),
    forceUpdateMessageAr: readString(data.forceUpdateMessageAr),
    androidStoreUrl: readString(data.androidStoreUrl),
    iosStoreUrl: readString(data.iosStoreUrl),
    aboutEn: readString(data.aboutEn),
    aboutAr: readString(data.aboutAr),
    contactEn: readString(data.contactEn),
    contactAr: readString(data.contactAr),
    privacyEn: readString(data.privacyEn),
    privacyAr: readString(data.privacyAr),
    termsEn: readString(data.termsEn),
    termsAr: readString(data.termsAr),
    referralEnabled: readBool(data.referralEnabled, false),
    referralRewardReferrerIqd: readInt(data.referralRewardReferrerIqd, 0),
    referralRewardNewUserIqd: readInt(data.referralRewardNewUserIqd, 0),
    complaintFlagThreshold: readInt(data.complaintFlagThreshold, 3),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: context.auth.uid,
  };

  await admin.firestore().collection("config").doc("app").set(payload, { merge: true });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "app.config.updated",
    entityType: "appConfig",
    entityId: "app",
    details: {
      maintenanceMode: payload.maintenanceMode,
      minAndroidBuild: payload.minAndroidBuild,
      minIosBuild: payload.minIosBuild,
      referralEnabled: payload.referralEnabled,
      complaintFlagThreshold: payload.complaintFlagThreshold,
    },
  });

  return { ok: true };
});

exports.savePromoConfig = functions.https.onCall(async (data, context) => {
  await assertAdminPermission(context, "promoCodes");

  const code = String(data.code || "FREE3")
    .trim()
    .toUpperCase();
  if (!code) {
    throw new functions.https.HttpsError("invalid-argument", "Promo code required.");
  }

  const discountPercent = Math.trunc(Number(data.discountPercent));
  const maxDiscountIqd = Math.trunc(Number(data.maxDiscountIqd));
  const maxRides = Math.trunc(Number(data.maxRides));

  if (
    !Number.isFinite(discountPercent) ||
    discountPercent <= 0 ||
    !Number.isFinite(maxDiscountIqd) ||
    maxDiscountIqd <= 0 ||
    !Number.isFinite(maxRides) ||
    maxRides <= 0
  ) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid promo values.");
  }

  await admin
    .firestore()
    .collection("config")
    .doc(`promo_${code}`)
    .set({
      code,
      enabled: data.enabled !== false,
      autoAssignOnSignup: data.autoAssignOnSignup !== false,
      discountPercent,
      maxDiscountIqd,
      maxRides,
      description: String(data.description || "").trim(),
      kind: String(data.kind || "both"),
      districtIds: Array.isArray(data.districtIds) ? data.districtIds.map(String) : [],
      minCompletedRidesForEligibility: Math.max(
        0,
        Math.trunc(Number(data.minCompletedRidesForEligibility) || 0),
      ),
      currentRedemptions: Math.max(
        0,
        Math.trunc(Number(data.currentRedemptions) || 0),
      ),
      maxTotalRedemptions:
        data.maxTotalRedemptions == null || data.maxTotalRedemptions === ""
          ? null
          : Math.max(0, Math.trunc(Number(data.maxTotalRedemptions))),
      expiresAt: data.expiresAt
        ? admin.firestore.Timestamp.fromDate(new Date(data.expiresAt))
        : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

  return { ok: true, code };
});

exports.adminMonthlyPrize = functions.https.onCall(async (data, context) => {
  await assertAdminPermission(context, "monthlyLeaderboard");

  const action = String(data.action || "").trim();
  const configRef = admin.firestore().collection("config").doc("monthly_prize");

  if (action === "markWinner") {
    const driverId = String(data.driverId || "").trim();
    if (!driverId) {
      throw new functions.https.HttpsError("invalid-argument", "Driver id required.");
    }
    await configRef.set(
      {
        winnerDriverId: driverId,
        winnerPaid: false,
        winnerMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { ok: true };
  }

  if (action === "markPaid") {
    await configRef.set(
      {
        winnerPaid: true,
        winnerPaidAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { ok: true };
  }

  if (action === "reset") {
    const now = new Date();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const monthKey = `${now.getFullYear()}-${month}`;

    const driversSnapshot = await admin.firestore().collection("drivers").get();
    let batch = admin.firestore().batch();
    let ops = 0;

    for (const doc of driversSnapshot.docs) {
      batch.update(doc.ref, {
        monthlyRideCount: 0,
        monthlyMonthKey: monthKey,
      });
      ops += 1;
      if (ops >= 450) {
        await batch.commit();
        batch = admin.firestore().batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    await configRef.set(
      {
        monthKey,
        winnerDriverId: "",
        winnerPaid: false,
        resetAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { ok: true, monthKey };
  }

  throw new functions.https.HttpsError("invalid-argument", "Unknown monthly prize action.");
});

const GOOGLE_DIRECTIONS_KEY =
  process.env.GOOGLE_PLACES_WEB_API_KEY ||
  "AIzaSyAsgktwgQMXi9i5majam_z3Yion1_0qqLY";

function parseCoord(value, name) {
  const num = Number(value);
  if (!Number.isFinite(num) || Math.abs(num) > 180) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${name} must be a valid coordinate.`,
    );
  }
  return num;
}

exports.getDrivingRoute = functions.https.onCall(async (data) => {
  const originLat = parseCoord(data?.originLat, "originLat");
  const originLng = parseCoord(data?.originLng, "originLng");
  const destLat = parseCoord(data?.destLat, "destLat");
  const destLng = parseCoord(data?.destLng, "destLng");

  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode: "driving",
    region: "iq",
    key: GOOGLE_DIRECTIONS_KEY,
  });

  const response = await fetch(
    `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`,
  );
  const body = await response.json();

  if (body.status !== "OK" || !Array.isArray(body.routes) || !body.routes.length) {
    throw new functions.https.HttpsError(
      "not-found",
      body.error_message || body.status || "no_route",
    );
  }

  const leg = body.routes[0].legs?.[0];
  if (!leg?.distance?.value || !leg?.duration?.value) {
    throw new functions.https.HttpsError("not-found", "Route leg missing distance.");
  }

  const encodedPolyline = body.routes[0].overview_polyline?.points || "";

  return {
    distanceKm: Math.round((leg.distance.value / 1000) * 100) / 100,
    durationMinutes: Math.max(1, Math.ceil(leg.duration.value / 60)),
    encodedPolyline,
  };
});

exports.sendBroadcast = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["notifications", "overview"]);

  const payload = parseCallableData(data);
  const audience = String(payload.audience || "").trim();
  const title = String(payload.title || "").trim();
  const body = String(payload.message || payload.body || "").trim();
  const provinceId = String(payload.provinceId || "").trim();
  const districtId = String(payload.districtId || "").trim();
  const subDistrictId = String(payload.subDistrictId || "").trim();
  const targetUserId = String(payload.targetUserId || "").trim();

  if (!title || !body) {
    throw new functions.https.HttpsError("invalid-argument", "Title and message required.");
  }

  const allowedAudiences = new Set([
    "drivers",
    "allDrivers",
    "customers",
    "allCustomers",
    "businesses",
    "province",
    "district",
    "subDistrict",
    "individual",
  ]);
  if (!allowedAudiences.has(audience)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Unsupported audience.",
    );
  }

  const tokens = new Set();
  const normalizedAudience =
    audience === "allDrivers"
      ? "drivers"
      : audience === "allCustomers"
        ? "customers"
        : audience;

  const matchesGeo = (docData) => {
    if (provinceId && String(docData.provinceId || "") !== provinceId) return false;
    if (districtId && String(docData.assignedDistrictId || docData.districtId || "") !== districtId) {
      return false;
    }
    if (
      subDistrictId &&
      String(docData.assignedSubDistrictId || docData.subDistrictId || "") !==
        subDistrictId
    ) {
      return false;
    }
    return true;
  };

  if (normalizedAudience === "individual" && targetUserId) {
    const driverDoc = await admin.firestore().collection("drivers").doc(targetUserId).get();
    if (driverDoc.exists && driverDoc.data()?.fcmToken) {
      tokens.add(driverDoc.data().fcmToken);
    }
    const userDoc = await admin.firestore().collection("users").doc(targetUserId).get();
    if (userDoc.exists && userDoc.data()?.fcmToken) {
      tokens.add(userDoc.data().fcmToken);
    }
  } else if (normalizedAudience === "businesses") {
    const snapshot = await admin.firestore().collection("businesses").get();
    for (const doc of snapshot.docs) {
      const biz = doc.data() || {};
      if (!matchesGeo(biz)) continue;
      const ownerId = String(biz.ownerUserId || biz.ownerId || "").trim();
      if (!ownerId) continue;
      const userDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (userDoc.exists && userDoc.data()?.fcmToken) {
        tokens.add(userDoc.data().fcmToken);
      }
    }
  } else if (
    normalizedAudience === "drivers" ||
    normalizedAudience === "province" ||
    normalizedAudience === "district" ||
    normalizedAudience === "subDistrict"
  ) {
    const snapshot = await admin.firestore().collection("drivers").get();
    for (const doc of snapshot.docs) {
      const driver = doc.data() || {};
      if (driver.isBlocked || driver.isRemoved || driver.isFakeDriver) continue;
      if (driver.approvalStatus !== "approved") continue;
      if (!matchesGeo(driver)) continue;
      if (driver.fcmToken) tokens.add(driver.fcmToken);
    }
    if (normalizedAudience === "province" || normalizedAudience === "district" || normalizedAudience === "subDistrict") {
      const customers = await admin
        .firestore()
        .collection("users")
        .where("role", "==", "customer")
        .get();
      for (const doc of customers.docs) {
        const user = doc.data() || {};
        if (user.isBlocked) continue;
        if (!matchesGeo(user)) continue;
        if (user.fcmToken) tokens.add(user.fcmToken);
      }
    }
  } else if (normalizedAudience === "customers") {
    const snapshot = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "customer")
      .get();
    for (const doc of snapshot.docs) {
      const user = doc.data() || {};
      if (user.isBlocked) continue;
      if (!matchesGeo(user)) continue;
      if (user.fcmToken) tokens.add(user.fcmToken);
    }
  }

  let sent = 0;
  for (const token of tokens) {
    const ok = await sendToToken(
      token,
      title,
      body,
      { type: "admin_broadcast", audience },
      "default",
    );
    if (ok) sent += 1;
  }

  await admin.firestore().collection("announcements").add({
    audience,
    title,
    body,
    sentCount: sent,
    totalTokens: tokens.size,
    createdBy: context.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(provinceId ? { provinceId } : {}),
    ...(districtId ? { districtId } : {}),
    ...(subDistrictId ? { subDistrictId } : {}),
    ...(targetUserId ? { targetUserId } : {}),
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "notification.broadcast",
    entityType: "announcement",
    details: { audience, title, sent, total: tokens.size },
  });

  return { sent, total: tokens.size, audience };
});

async function getComplaintFlagThreshold() {
  try {
    const snap = await admin.firestore().collection("config").doc("app").get();
    const val = Number(snap.data()?.complaintFlagThreshold);
    return Number.isFinite(val) && val > 0 ? Math.trunc(val) : 3;
  } catch (_) {
    return 3;
  }
}

async function evaluateComplaintTargetFlag(complaintData, actorUid = "system") {
  const data = complaintData || {};
  const targetUserId = String(data.targetUserId || "").trim();
  if (!targetUserId) return;

  const threshold = await getComplaintFlagThreshold();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 90);

  const snap = await admin
    .firestore()
    .collection("complaints")
    .where("targetUserId", "==", targetUserId)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .get();

  const count = snap.docs.filter((doc) => {
    const status = String(doc.data().status || "");
    return status === "open" || status === "inProgress" || status === "resolved";
  }).length;

  if (count < threshold) return;

  const targetRole = String(data.targetRole || "").trim().toLowerCase();
  let collection = targetRole === "driver" ? "drivers" : "users";
  let targetRef = admin.firestore().collection(collection).doc(targetUserId);
  let targetSnap = await targetRef.get();
  if (!targetSnap.exists) {
    collection = collection === "drivers" ? "users" : "drivers";
    targetRef = admin.firestore().collection(collection).doc(targetUserId);
    targetSnap = await targetRef.get();
    if (!targetSnap.exists) return;
  }
  if (targetSnap.data()?.reviewFlagged === true) return;

  await targetRef.set(
    {
      reviewFlagged: true,
      reviewFlagReason: "multiple_complaints",
      reviewFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAdminAuditLog({
    adminId: actorUid,
    action: "complaint.auto_flag",
    entityType: targetRole === "driver" ? "driver" : "user",
    entityId: targetUserId,
    details: {
      complaintCount: count,
      threshold,
      targetName: String(data.targetName || ""),
      targetRole,
    },
  });
}

exports.createComplaint = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const payload = parseCallableData(data);
  const subject = String(payload.subject || "").trim();
  const body = String(payload.body || "").trim();
  if (!subject || !body) {
    throw new functions.https.HttpsError("invalid-argument", "Subject and body required.");
  }
  const ref = admin.firestore().collection("complaints").doc();
  const doc = {
    userId: String(payload.userId || context.auth.uid).trim(),
    userRole: String(payload.userRole || "customer").trim(),
    userName: String(payload.userName || "").trim(),
    subject,
    body,
    status: "open",
    adminReply: "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: context.auth.uid,
  };
  for (const key of [
    "provinceId",
    "districtId",
    "subDistrictId",
    "relatedRideId",
    "targetUserId",
    "targetRole",
    "targetName",
    "category",
  ]) {
    const value = String(payload[key] || "").trim();
    if (value) doc[key] = value;
  }
  await ref.set(doc);
  try {
    const saved = await ref.get();
    await evaluateComplaintTargetFlag(saved.data(), context.auth.uid);
  } catch (error) {
    functions.logger.warn("complaint auto-flag failed", {
      complaintId: ref.id,
      message: error.message,
    });
  }
  return { ok: true, complaintId: ref.id };
});

exports.onComplaintCreated = functions.firestore
  .document("complaints/{complaintId}")
  .onCreate(async (snap) => {
    try {
      await evaluateComplaintTargetFlag(snap.data(), "system");
    } catch (error) {
      functions.logger.warn("complaint auto-flag trigger failed", {
        complaintId: snap.id,
        message: error.message,
      });
    }
    return null;
  });

exports.logAdminLogin = onCall({ region: "us-central1" }, async (request) => {
  const context = { auth: request.auth };
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "User profile not found.");
  }
  const role = userDoc.data()?.role;
  if (role !== "manager" && role !== "assistant") {
    throw new functions.https.HttpsError("permission-denied", "Admin access required.");
  }
  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "admin.login",
    entityType: "admin",
    entityId: context.auth.uid,
    details: { role },
  });
  return { ok: true };
});

exports.sendWhatsAppOtp = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => sendWhatsAppOtpV1.run(request.data),
);
exports.verifyWhatsAppOtp = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => verifyWhatsAppOtpV1.run(request.data),
);
exports.signUpWithVerifiedPhone = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => runSignUpWithVerifiedPhone(normalizePhone, request.data, request.auth),
);
exports.resetPasswordByPhoneVerified = authAdminCallable(async (data) =>
  runResetPasswordByPhone(normalizePhone, data),
);

exports.registerWithPhonePassword = functions.https.onCall(async (data) => {
  try {
    return await runRegisterWithPhonePassword(data);
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error("registerWithPhonePassword unhandled", {
      message: error.message,
      code: error.code,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Registration failed. Try again.",
    );
  }
});

const DEFAULT_DRIVER_DISTRICT = {
  id: "hashimiya",
  subDistrictId: "hashimiya_center",
  latitude: 32.374,
  longitude: 44.665,
};

exports.setDriverApprovalStatus = functions.https.onCall(async (data, context) => {
  await assertAdminPermission(context, "allDrivers");

  const payload = parseCallableData(data);
  const driverId = String(payload.driverId || "").trim();
  const status = String(payload.status || "").trim();

  if (!driverId) {
    throw new functions.https.HttpsError("invalid-argument", "Driver id required.");
  }
  if (!["approved", "rejected", "pending"].includes(status)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid approval status.");
  }

  const db = admin.firestore();
  const driverRef = db.collection("drivers").doc(driverId);
  const existing = await driverRef.get();
  if (!existing.exists) {
    throw new functions.https.HttpsError("not-found", "Driver not found.");
  }

  const existingData = existing.data() || {};
  const update = {
    approvalStatus: status,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (status === "approved") {
    update.isBlocked = false;

    let districtId = String(existingData.assignedDistrictId || "").trim();
    let subDistrictId = String(existingData.assignedSubDistrictId || "").trim();
    if (!districtId || !subDistrictId) {
      districtId = DEFAULT_DRIVER_DISTRICT.id;
      subDistrictId = DEFAULT_DRIVER_DISTRICT.subDistrictId;
      update.assignedDistrictId = districtId;
      update.assignedSubDistrictId = subDistrictId;
    }

    if (existingData.latitude == null) {
      update.latitude = DEFAULT_DRIVER_DISTRICT.latitude;
    }
    if (existingData.longitude == null) {
      update.longitude = DEFAULT_DRIVER_DISTRICT.longitude;
    }
    if (!existingData.locationUpdatedAt) {
      update.locationUpdatedAt = admin.firestore.FieldValue.serverTimestamp();
    }
  }

  // Ensure every approved/pending driver has wallet fields for the driver apps.
  if (existingData.walletBalanceIqd == null) {
    update.walletBalanceIqd = 0;
  }
  if (!existingData.walletStatus) {
    const balance =
      existingData.walletBalanceIqd == null
        ? 0
        : Number(existingData.walletBalanceIqd) || 0;
    update.walletStatus = balance > 0 ? "active" : "blocked";
  }
  if (!existingData.walletUpdatedAt && update.walletBalanceIqd != null) {
    update.walletUpdatedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await driverRef.set(update, { merge: true });

  functions.logger.info("setDriverApprovalStatus", {
    driverId,
    status,
    reviewedBy: context.auth.uid,
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: status === "approved" ? "driver.approved" : `driver.${status}`,
    entityType: "driver",
    entityId: driverId,
    details: { status },
  });

  return { ok: true, approvalStatus: status };
});

exports.resetPasswordByPhone = authAdminCallable(async (data) =>
  runResetPasswordByPhone(normalizePhone, data),
);

exports.testPing = functions.https.onCall(async () => {
  return { ok: true, ts: Date.now() };
});

exports.sendWhatsAppOtpDryRun = functions.https.onCall(async (data) => {
  const payload = data && typeof data === "object" && data.data ? data.data : data;
  return {
    ok: true,
    phone: String(payload?.phone || ""),
    purpose: String(payload?.purpose || ""),
  };
});

exports.sendWhatsAppOtpDebug = createSendWhatsAppOtpDebug(normalizePhone);

exports.requestPasswordReset = authAdminCallable(async (data) => {
  const phone = normalizePhone(String(data.phone || "").trim());
  if (!phone) {
    throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
  }

  const snapshot = await admin
    .firestore()
    .collection("users")
    .where("phone", "==", phone)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new functions.https.HttpsError("not-found", "No account found for this phone number.");
  }

  const uid = snapshot.docs[0].id;
  let userRecord;
  try {
    userRecord = await admin.auth().getUser(uid);
  } catch (error) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }

  if (!userRecord.email) {
    throw new functions.https.HttpsError("failed-precondition", "Account has no email identity.");
  }

  const resetLink = await admin.auth().generatePasswordResetLink(userRecord.email, {
    url: "https://hello-tiktok-57dc5.web.app",
  });
  return { resetLink };
});

exports.updateAccountPhone = authAdminCallable(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const newPhone = normalizePhone(String(data.newPhone || "").trim());
  if (!newPhone) {
    throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
  }

  const uid = context.auth.uid;
  const digits = newPhone.replace(/\D/g, "");
  const newEmail = `${digits}@hello-tiktok.app`;

  await admin.auth().updateUser(uid, { email: newEmail });
  await admin.firestore().collection("users").doc(uid).set(
    { phone: newPhone },
    { merge: true },
  );

  const driverDoc = await admin.firestore().collection("drivers").doc(uid).get();
  if (driverDoc.exists) {
    await admin.firestore().collection("drivers").doc(uid).set(
      { phone: newPhone },
      { merge: true },
    );
  }

  return { ok: true, phone: newPhone };
});

async function deleteQueryBatch(query, batchSize = 100) {
  const snapshot = await query.limit(batchSize).get();
  if (snapshot.empty) {
    return;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  if (snapshot.size >= batchSize) {
    await deleteQueryBatch(query, batchSize);
  }
}

async function deleteCollection(ref) {
  await deleteQueryBatch(ref);
}

async function deleteDriverFirestoreData(driverId) {
  const db = admin.firestore();
  const driverRef = db.collection("drivers").doc(driverId);
  await deleteCollection(driverRef.collection("bonuses"));
  await deleteCollection(driverRef.collection("profit_settlements"));
  await driverRef.delete();
}

// Deletes every ride that references this user (as customer or driver) plus each
// ride's chat messages subcollection, so no account data is left behind.
async function deleteRidesForUser(userId) {
  const db = admin.firestore();
  for (const field of ["customerId", "driverId"]) {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const snapshot = await db
        .collection("rides")
        .where(field, "==", userId)
        .limit(50)
        .get();
      if (snapshot.empty) {
        break;
      }
      for (const doc of snapshot.docs) {
        try {
          await deleteCollection(doc.ref.collection("messages"));
        } catch (error) {
          functions.logger.warn("deleteRidesForUser messages skipped", {
            rideId: doc.id,
            message: error.message,
          });
        }
        await doc.ref.delete();
      }
    }
  }
}

async function deleteSupportMessagesForUser(userId) {
  const db = admin.firestore();
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await db
      .collection("support_messages")
      .where("userId", "==", userId)
      .limit(100)
      .get();
    if (snapshot.empty) {
      break;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function deleteUserFirestoreData(userId, role) {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(userId);

  try {
    await deleteCollection(userRef.collection("saved_places"));
  } catch (error) {
    functions.logger.warn("deleteUserFirestoreData saved_places skipped", {
      userId,
      message: error.message,
    });
  }

  if (role === "driver") {
    const driverDoc = await db.collection("drivers").doc(userId).get();
    if (driverDoc.exists) {
      await deleteDriverFirestoreData(userId);
    }
  }

  try {
    await deleteRidesForUser(userId);
  } catch (error) {
    functions.logger.warn("deleteUserFirestoreData rides skipped", {
      userId,
      message: error.message,
    });
  }

  try {
    await deleteSupportMessagesForUser(userId);
  } catch (error) {
    functions.logger.warn("deleteUserFirestoreData support skipped", {
      userId,
      message: error.message,
    });
  }

  try {
    await userRef.delete();
  } catch (error) {
    if (error.code !== 5 && error.code !== "not-found") {
      throw error;
    }
  }
}

async function markReleasedPhone(phone, userId) {
  const phoneKey = phoneKeyFromPhone(phone);
  if (!phoneKey) {
    return;
  }

  await admin.firestore().collection("released_phones").doc(phoneKey).set({
    phone,
    previousUid: userId,
    releasedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function driverPhotoDownloadUrl(bucketName, objectPath, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
}

exports.uploadDriverApplicationPhoto = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const payload = parseCallableData(data);
  const uid = context.auth.uid;
  const fileName = String(payload.fileName || "").trim();
  const base64 = String(payload.base64 || "").trim();

  if (!["id_photo.jpg", "profile_photo.jpg"].includes(fileName)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid photo file name.");
  }
  if (!base64) {
    throw new functions.https.HttpsError("invalid-argument", "Photo data required.");
  }

  let buffer;
  try {
    buffer = Buffer.from(base64, "base64");
  } catch (error) {
    throw new functions.https.HttpsError("invalid-argument", "Photo data is invalid.");
  }

  if (!buffer.length) {
    throw new functions.https.HttpsError("invalid-argument", "Photo file is empty.");
  }
  if (buffer.length > 15 * 1024 * 1024) {
    throw new functions.https.HttpsError("invalid-argument", "Photo is too large.");
  }

  const bucket = admin.storage().bucket();
  const objectPath = `driver_applications/${uid}/${fileName}`;
  const file = bucket.file(objectPath);
  const token = require("crypto").randomUUID();

  try {
    await file.save(buffer, {
      metadata: {
        contentType: "image/jpeg",
        metadata: {
          firebaseStorageDownloadTokens: token,
        },
      },
    });
  } catch (error) {
    functions.logger.error("uploadDriverApplicationPhoto save failed", {
      uid,
      fileName,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "unavailable",
      "Could not upload photo. Try again.",
    );
  }

  return {
    ok: true,
    url: driverPhotoDownloadUrl(bucket.name, objectPath, token),
  };
});

exports.submitDriverRegistration = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const payload = parseCallableData(data);
  const uid = context.auth.uid;
  const phone = normalizePhone(String(payload.phone || "").trim());
  const name = String(payload.name || "").trim();
  const vehicleType = String(payload.vehicleType || "Tuk-Tuk").trim() || "Tuk-Tuk";
  const vehiclePlate = String(payload.vehiclePlate || "").trim();
  const vehicleColor = String(payload.vehicleColor || "").trim();
  const licenseNumber = String(payload.licenseNumber || "").trim();
  const idPhotoUrl = String(payload.idPhotoUrl || "").trim();
  const profilePhotoUrl = String(payload.profilePhotoUrl || "").trim();

  if (!phone || phone === "+964") {
    throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
  }
  if (!name) {
    throw new functions.https.HttpsError("invalid-argument", "Name is required.");
  }
  if (!vehiclePlate) {
    throw new functions.https.HttpsError("invalid-argument", "Plate number is required.");
  }
  if (!vehicleColor) {
    throw new functions.https.HttpsError("invalid-argument", "Vehicle color is required.");
  }
  if (!idPhotoUrl || !profilePhotoUrl) {
    throw new functions.https.HttpsError("invalid-argument", "Both photos are required.");
  }

  const driverRef = admin.firestore().collection("drivers").doc(uid);
  const existing = await driverRef.get();
  const existingData = existing.exists ? existing.data() || {} : {};

  const walletPatch = {};
  if (existingData.walletBalanceIqd == null) {
    walletPatch.walletBalanceIqd = 0;
  }
  if (!existingData.walletStatus) {
    walletPatch.walletStatus = "blocked";
  }
  if (!existingData.walletUpdatedAt) {
    walletPatch.walletUpdatedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await driverRef.set(
    {
      phone,
      name,
      vehicleType,
      vehiclePlate,
      vehicleColor,
      licenseNumber,
      idPhotoUrl,
      profilePhotoUrl,
      termsAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvalStatus: "pending",
      isOnline: false,
      isBlocked: false,
      hasActiveRide: false,
      cancelledRidesCount: existingData.cancelledRidesCount || 0,
      createdAt: existingData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      ...walletPatch,
    },
    { merge: true },
  );

  await admin.firestore().collection("users").doc(uid).set(
    {
      phone,
      name,
      role: "driver",
      profilePhotoUrl,
    },
    { merge: true },
  );

  return { ok: true };
});

async function resolveStoragePhotoUrl(bucket, objectPath) {
  const file = bucket.file(objectPath);
  const [exists] = await file.exists();
  if (!exists) {
    return "";
  }

  const [metadata] = await file.getMetadata();
  let token = String(metadata.metadata?.firebaseStorageDownloadTokens || "").split(",")[0].trim();
  if (!token) {
    token = require("crypto").randomUUID();
    await file.setMetadata({
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    });
  }

  return driverPhotoDownloadUrl(bucket.name, objectPath, token);
}

exports.syncDriverDocumentsFromStorage = authAdminCallable(async (data, context) => {
  await assertAdminPermissionAny(context, ["allDrivers", "pendingDrivers"]);

  const payload = parseCallableData(data);
  const driverId = String(payload.driverId || "").trim();
  if (!driverId) {
    throw new functions.https.HttpsError("invalid-argument", "Driver id required.");
  }

  const bucket = admin.storage().bucket();
  const idPhotoUrl = await resolveStoragePhotoUrl(
    bucket,
    `driver_applications/${driverId}/id_photo.jpg`,
  );
  const profilePhotoUrl = await resolveStoragePhotoUrl(
    bucket,
    `driver_applications/${driverId}/profile_photo.jpg`,
  );

  const updates = {};
  if (idPhotoUrl) {
    updates.idPhotoUrl = idPhotoUrl;
  }
  if (profilePhotoUrl) {
    updates.profilePhotoUrl = profilePhotoUrl;
  }

  if (Object.keys(updates).length > 0) {
    await admin.firestore().collection("drivers").doc(driverId).set(updates, { merge: true });
    if (updates.profilePhotoUrl) {
      await admin.firestore().collection("users").doc(driverId).set(
        { profilePhotoUrl: updates.profilePhotoUrl },
        { merge: true },
      );
    }
  }

  return { ok: true, idPhotoUrl, profilePhotoUrl };
});

exports.getDriverPhotoForAdmin = authAdminCallable(async (data, context) => {
  await assertAdminPermissionAny(context, ["allDrivers", "pendingDrivers"]);

  const payload = parseCallableData(data);
  const driverId = String(payload.driverId || "").trim();
  const fileName = String(payload.fileName || "").trim();

  if (!driverId) {
    throw new functions.https.HttpsError("invalid-argument", "Driver id required.");
  }
  if (!["id_photo.jpg", "profile_photo.jpg"].includes(fileName)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid photo file name.");
  }

  const bucket = admin.storage().bucket();
  const objectPath = `driver_applications/${driverId}/${fileName}`;
  const file = bucket.file(objectPath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new functions.https.HttpsError("not-found", "Photo not found.");
  }

  const [buffer] = await file.download();
  const [metadata] = await file.getMetadata();
  return {
    ok: true,
    base64: buffer.toString("base64"),
    contentType: metadata.contentType || "image/jpeg",
  };
});

exports.getWalletReceiptForAdmin = authAdminCallable(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);

  const payload = parseCallableData(data);
  const driverId = String(payload.driverId || "").trim();
  const screenshotUrl = String(payload.screenshotUrl || payload.url || "").trim();

  if (!driverId || !screenshotUrl) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "driverId and screenshotUrl required.",
    );
  }

  const bucket = admin.storage().bucket();
  let objectPath = "";

  try {
    const parsed = new URL(screenshotUrl);
    const segments = parsed.pathname.split("/");
    const oIndex = segments.indexOf("o");
    if (oIndex >= 0 && segments[oIndex + 1]) {
      objectPath = decodeURIComponent(segments[oIndex + 1]);
    }
  } catch (_) {
    objectPath = "";
  }

  if (!objectPath || !objectPath.startsWith(`wallet_recharges/${driverId}/`)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid wallet receipt path.",
    );
  }

  const file = bucket.file(objectPath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new functions.https.HttpsError("not-found", "Receipt image not found.");
  }

  const [buffer] = await file.download();
  const [metadata] = await file.getMetadata();
  return {
    ok: true,
    base64: buffer.toString("base64"),
    contentType: metadata.contentType || "image/jpeg",
  };
});

function phoneKeyFromPhone(phone) {
  return String(phone || "").replace(/\D/g, "");
}

async function deleteAuthUserForPhone(phone) {
  const phoneKey = phoneKeyFromPhone(phone);
  if (!phoneKey) {
    return false;
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(authEmailFromPhoneKey(phoneKey));
    await admin.auth().deleteUser(userRecord.uid);
    return true;
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return false;
    }
    functions.logger.warn("deleteAuthUserForPhone skipped", {
      phoneKey,
      code: error.code,
      message: error.message,
    });
    return false;
  }
}

async function deleteAccountStorageFiles(userId) {
  if (!userId || userId.startsWith("fake_")) {
    return;
  }

  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `driver_applications/${userId}/` });
  } catch (error) {
    functions.logger.warn("deleteAccountStorageFiles driver docs skipped", {
      userId,
      message: error.message,
    });
  }

  try {
    const bucket = admin.storage().bucket();
    await bucket.file(`user_profiles/${userId}/profile_photo.jpg`).delete();
  } catch (error) {
    if (error.code !== 404) {
      functions.logger.warn("deleteAccountStorageFiles profile photo skipped", {
        userId,
        message: error.message,
      });
    }
  }
}

async function deleteAuthCredentialsForAccount(userId, phone) {
  let deletedPrimary = false;

  if (userId) {
    try {
      await admin.auth().deleteUser(userId);
      deletedPrimary = true;
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error;
      }
    }
  }

  const phoneKey = phoneKeyFromPhone(phone);
  if (!phoneKey) {
    return deletedPrimary;
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(authEmailFromPhoneKey(phoneKey));
    if (!userId || userRecord.uid !== userId) {
      await admin.auth().deleteUser(userRecord.uid);
      deletedPrimary = true;
    }
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return deletedPrimary;
    }
    if (deletedPrimary) {
      functions.logger.warn("deleteAuthCredentialsForAccount phone lookup skipped", {
        phoneKey,
        code: error.code,
        message: error.message,
      });
      return deletedPrimary;
    }
    throw error;
  }

  return deletedPrimary;
}

async function clearReleasedPhone(phone) {
  const phoneKey = phoneKeyFromPhone(phone);
  if (!phoneKey) {
    return;
  }
  await admin.firestore().collection("released_phones").doc(phoneKey).delete().catch(() => {});
}

async function cleanupDeletedAccountArtifacts(phone, knownUid) {
  const db = admin.firestore();
  const phoneKey = phoneKeyFromPhone(phone);
  if (!phoneKey) {
    return;
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(authEmailFromPhoneKey(phoneKey));
    if (!knownUid || userRecord.uid !== knownUid) {
      const staleUserRef = db.collection("users").doc(userRecord.uid);
      if ((await staleUserRef.get()).exists) {
        await staleUserRef.delete();
      }
      const staleDriverRef = db.collection("drivers").doc(userRecord.uid);
      if ((await staleDriverRef.get()).exists) {
        await deleteDriverFirestoreData(userRecord.uid);
      }
      await admin.auth().deleteUser(userRecord.uid);
    }
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      functions.logger.warn("Auth cleanup skipped", {
        phoneKey,
        code: error.code,
        message: error.message,
      });
    }
  }

  await clearReleasedPhone(phone);
}

function parseCallableData(data) {
  if (data && typeof data === "object" && data.data && typeof data.data === "object") {
    return data.data;
  }
  return data && typeof data === "object" ? data : {};
}

async function runRegisterWithPhonePassword(data) {
  const payload = parseCallableData(data);
  const phone = normalizePhone(String(payload.phone || "").trim());
  const password = String(payload.password || "");
  const fullName = String(payload.fullName || "").trim();
  const role = String(payload.role || "customer").trim();

  if (!phone || phone === "+964") {
    throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters.",
    );
  }
  if (!fullName) {
    throw new functions.https.HttpsError("invalid-argument", "Full name required.");
  }
  if (!["customer", "driver"].includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid account type.");
  }

  const phoneKey = phoneKeyFromPhone(phone);
  const authEmail = authEmailFromPhoneKey(phoneKey);

  try {
    const existing = await admin.auth().getUserByEmail(authEmail);
    functions.logger.warn("registerWithPhonePassword blocked duplicate auth user", {
      phoneKey,
      uid: existing.uid,
    });
    throw new functions.https.HttpsError(
      "already-exists",
      "An account with this phone number already exists.",
    );
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    if (error.code !== "auth/user-not-found") {
      functions.logger.error("registerWithPhonePassword auth lookup failed", {
        phoneKey,
        code: error.code,
        message: error.message,
      });
      throw new functions.https.HttpsError(
        "internal",
        "Could not verify phone number. Try again.",
      );
    }
  }

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: authEmail,
      password,
      displayName: fullName,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
        "already-exists",
        "An account with this phone number already exists.",
      );
    }
    functions.logger.error("registerWithPhonePassword createUser failed", {
      phoneKey,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Could not create login account. Try again.",
    );
  }

  return { ok: true, uid: userRecord.uid, phone, role };
}

exports.deleteUserAccount = authAdminCallable(async (data, context) => {
  const payload = parseCallableData(data);
  const targetUserId = String(payload.userId || "").trim();
  if (!targetUserId) {
    throw new functions.https.HttpsError("invalid-argument", "User id required.");
  }

  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  if (context.auth.uid === targetUserId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You cannot delete your own account from the admin panel.",
    );
  }

  if (targetUserId.startsWith("fake_")) {
    await assertAdminPermission(context, "allDrivers");
    return { ok: true, deletedAuth: false };
  }

  let role = String(payload.role || "").trim();
  let phone = normalizePhone(String(payload.phone || "").trim());

  const userDoc = await admin.firestore().collection("users").doc(targetUserId).get();
  const driverDoc = await admin.firestore().collection("drivers").doc(targetUserId).get();

  if (userDoc.exists && userDoc.data()) {
    if (!role) {
      role = String(userDoc.data().role || "");
    }
    if (!phone || phone === "+964") {
      phone = normalizePhone(String(userDoc.data().phone || ""));
    }
  }

  if (driverDoc.exists && driverDoc.data()) {
    if (!role) {
      role = "driver";
    }
    if (!phone || phone === "+964") {
      phone = normalizePhone(String(driverDoc.data().phone || ""));
    }
  }

  if (!userDoc.exists && !driverDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }

  if (!role) {
    throw new functions.https.HttpsError("invalid-argument", "Account role required.");
  }

  if (role === "manager" || role === "assistant") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Manager and assistant accounts cannot be deleted here.",
    );
  }

  if (role === "customer") {
    await assertAdminPermissionAny(context, ["customers"]);
  } else if (role === "driver") {
    await assertAdminPermissionAny(context, ["allDrivers", "pendingDrivers"]);
  } else {
    throw new functions.https.HttpsError("failed-precondition", "Unsupported account type.");
  }

  let deletedAuth = false;
  let deletedFirestore = false;

  try {
    await deleteAccountStorageFiles(targetUserId);
  } catch (error) {
    functions.logger.warn("deleteUserAccount storage cleanup skipped", {
      targetUserId,
      message: error.message,
    });
  }

  try {
    await deleteUserFirestoreData(targetUserId, role);
    deletedFirestore = true;
  } catch (error) {
    functions.logger.error("deleteUserAccount firestore delete failed", {
      targetUserId,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Could not delete profile data: ${error.message || error.code || "unknown error"}`,
    );
  }

  try {
    deletedAuth = await deleteAuthCredentialsForAccount(targetUserId, phone);
    if (!deletedAuth) {
      functions.logger.warn("deleteUserAccount auth user already absent", {
        targetUserId,
        phone,
      });
      deletedAuth = true;
    }
  } catch (error) {
    functions.logger.error("deleteUserAccount auth delete failed", {
      targetUserId,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Could not delete login credentials: ${error.message || error.code || "unknown error"}`,
    );
  }

  try {
    await markReleasedPhone(phone, targetUserId);
  } catch (error) {
    functions.logger.warn("deleteUserAccount released phone mark skipped", {
      targetUserId,
      message: error.message,
    });
  }

  functions.logger.info("deleteUserAccount completed", {
    targetUserId,
    role,
    deletedAuth,
    deletedFirestore,
    deletedBy: context.auth.uid,
  });

  return { ok: true, deletedAuth, deletedFirestore };
});

exports.deleteMyAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const targetUserId = context.auth.uid;
  const userDoc = await admin.firestore().collection("users").doc(targetUserId).get();
  const driverDoc = await admin.firestore().collection("drivers").doc(targetUserId).get();

  if (!userDoc.exists && !driverDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }

  let role = userDoc.exists && userDoc.data()
    ? String(userDoc.data().role || "")
    : "";
  let phone = userDoc.exists && userDoc.data()
    ? normalizePhone(String(userDoc.data().phone || ""))
    : "";

  if (driverDoc.exists && driverDoc.data()) {
    if (!role) {
      role = "driver";
    }
    if (!phone || phone === "+964") {
      phone = normalizePhone(String(driverDoc.data().phone || ""));
    }
  }

  if (role === "manager" || role === "assistant") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Manager and assistant accounts cannot be deleted from the mobile app.",
    );
  }

  if (role !== "customer" && role !== "driver") {
    throw new functions.https.HttpsError("failed-precondition", "Unsupported account type.");
  }

  let deletedAuth = false;
  let deletedFirestore = false;

  try {
    await deleteAccountStorageFiles(targetUserId);
  } catch (error) {
    functions.logger.warn("deleteMyAccount storage cleanup skipped", {
      targetUserId,
      message: error.message,
    });
  }

  try {
    await deleteUserFirestoreData(targetUserId, role);
    deletedFirestore = true;
  } catch (error) {
    functions.logger.error("deleteMyAccount firestore delete failed", {
      targetUserId,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Could not delete profile data: ${error.message || error.code || "unknown error"}`,
    );
  }

  try {
    deletedAuth = await deleteAuthCredentialsForAccount(targetUserId, phone);
    if (!deletedAuth) {
      deletedAuth = true;
    }
  } catch (error) {
    functions.logger.error("deleteMyAccount auth delete failed", {
      targetUserId,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Could not delete login credentials: ${error.message || error.code || "unknown error"}`,
    );
  }

  try {
    await markReleasedPhone(phone, targetUserId);
  } catch (error) {
    functions.logger.warn("deleteMyAccount released phone mark skipped", {
      targetUserId,
      message: error.message,
    });
  }

  functions.logger.info("deleteMyAccount completed", {
    targetUserId,
    role,
    deletedAuth,
    deletedFirestore,
  });

  return { ok: true, deletedAuth, deletedFirestore };
});

exports.cleanupReleasedPhoneAuth = authAdminCallable(async (data) => {
  const payload = parseCallableData(data);
  const phone = normalizePhone(String(payload.phone || "").trim());
  if (!phone || phone === "+964") {
    throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
  }

  const phoneKey = phoneKeyFromPhone(phone);
  let released = false;
  try {
    const releasedDoc = await admin.firestore().collection("released_phones").doc(phoneKey).get();
    released = releasedDoc.exists;
  } catch (error) {
    functions.logger.error("cleanupReleasedPhoneAuth released_phones lookup failed", {
      phoneKey,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Phone is not available for registration.",
    );
  }

  if (!released) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Phone is not available for registration.",
    );
  }

  try {
    await deleteAuthCredentialsForAccount("", phone);
  } catch (error) {
    functions.logger.error("cleanupReleasedPhoneAuth auth delete failed", {
      phoneKey,
      code: error.code,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Could not prepare phone for registration. Try again.",
    );
  }

  await clearReleasedPhone(phone);
  return { ok: true };
});

const SUPPORT_AUTO_REPLY_AR =
  "شكراً لتواصلك معنا. سنرد على رسالتك خلال 24 ساعة.";

const ACTIVE_RIDE_STATUSES = [
  "searching",
  "matched",
  "accepted",
  "inProgress",
  "awaitingCashPayment",
];

exports.onSupportMessageCreated = functions.firestore
  .document("support_messages/{messageId}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    if (data.isFromManager || data.isAutoReply) {
      return null;
    }

    const userId = String(data.userId || "").trim();
    if (!userId) {
      return null;
    }

    await admin.firestore().collection("support_messages").add({
      userId,
      userRole: "manager",
      userName: "Support",
      phone: "",
      message: SUPPORT_AUTO_REPLY_AR,
      isFromManager: true,
      isAutoReply: true,
      status: "open",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });

exports.expireStaleActiveRides = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000),
    );
    let expiredCount = 0;

    for (const status of ACTIVE_RIDE_STATUSES) {
      const snapshot = await db
        .collection("rides")
        .where("status", "==", status)
        .where("createdAt", "<", cutoff)
        .get();

      for (const doc of snapshot.docs) {
        const ride = doc.data() || {};
        const driverId = String(ride.driverId || "").trim();
        const batch = db.batch();
        batch.update(doc.ref, {
          status: "cancelled",
          cancelReason: "expired_after_24h",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (driverId) {
          batch.update(db.collection("drivers").doc(driverId), {
            hasActiveRide: false,
            operationalStatus: "available",
          });
        }
        await batch.commit();
        expiredCount += 1;
      }
    }

    if (expiredCount > 0) {
      functions.logger.info("expireStaleActiveRides completed", { expiredCount });
    }
    return null;
  });

// --- Driver wallet (internal prepaid balance + SuperQi manual recharge) ---

function deriveWalletStatus(balanceIqd, minBalanceIqd, lowBalanceWarningIqd) {
  if (balanceIqd < minBalanceIqd) return "blocked";
  if (balanceIqd <= lowBalanceWarningIqd) return "low";
  return "active";
}

async function getWalletConfig() {
  const doc = await admin.firestore().collection("config").doc("wallet").get();
  const data = doc.data() || {};
  return {
    minBalanceIqd: Math.max(1, Number(data.minBalanceIqd) || 1),
    lowBalanceWarningIqd: Number(data.lowBalanceWarningIqd) || 5000,
    minWithdrawalIqd: Math.max(1000, Number(data.minWithdrawalIqd) || 5000),
    maxWithdrawalIqd: Math.max(0, Number(data.maxWithdrawalIqd) || 0),
    withdrawalsEnabled: data.withdrawalsEnabled !== false,
    companySuperQiNumber: String(data.companySuperQiNumber || ""),
    companySuperQiName: String(data.companySuperQiName || "Hello Tuk-Tuk"),
    managerWhatsappNumber: String(data.managerWhatsappNumber || ""),
    rechargeInstructionsEn: String(
      data.rechargeInstructionsEn ||
        "Transfer the amount to the company SuperQi number, then submit your receipt for verification.",
    ),
    rechargeInstructionsAr: String(
      data.rechargeInstructionsAr ||
        "حوّل المبلغ إلى رقم سوبر كي الخاص بالشركة، ثم أرسل إيصال الدفع للمراجعة.",
    ),
    enabledMethods: Array.isArray(data.enabledMethods)
      ? data.enabledMethods.map(String)
      : ["superQi", "cash", "bankTransfer"],
  };
}

function luhnCheck(cardNumber) {
  let sum = 0;
  let alternate = false;
  for (let i = cardNumber.length - 1; i >= 0; i -= 1) {
    let n = Number(cardNumber[i]);
    if (!Number.isFinite(n)) return false;
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 === 0;
}

function isValidMastercard(cardNumber) {
  const digits = String(cardNumber || "").replace(/\D/g, "");
  if (digits.length !== 16) return false;
  const prefix2 = Number(digits.slice(0, 2));
  const prefix4 = Number(digits.slice(0, 4));
  const isMc =
    (prefix2 >= 51 && prefix2 <= 55) || (prefix4 >= 2221 && prefix4 <= 2720);
  return isMc && luhnCheck(digits);
}

function makeWithdrawalReferenceId() {
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const rand = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `WD-${y}${m}${day}-${rand}`;
}

async function applyWalletDelta({
  driverId,
  amountIqd,
  type,
  createdBy,
  note = "",
  description = "",
  rideId = "",
  rechargeRequestId = "",
  withdrawalRequestId = "",
  rewardCampaignId = "",
  rewardGrantId = "",
  referenceId = "",
  status = "posted",
}) {
  const db = admin.firestore();
  const driverRef = db.collection("drivers").doc(driverId);
  const ledgerRef = db.collection("walletLedger").doc();
  const config = await getWalletConfig();
  const resolvedReferenceId =
    referenceId ||
    withdrawalRequestId ||
    rechargeRequestId ||
    rideId ||
    rewardGrantId ||
    ledgerRef.id;

  return db.runTransaction(async (tx) => {
    const driverSnap = await tx.get(driverRef);
    if (!driverSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Driver not found.");
    }
    const current = Number(driverSnap.data().walletBalanceIqd) || 0;
    const next = current + amountIqd;
    if (next < 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Insufficient wallet balance.",
      );
    }
    const walletStatus = deriveWalletStatus(
      next,
      config.minBalanceIqd,
      config.lowBalanceWarningIqd,
    );
    tx.update(driverRef, {
      walletBalanceIqd: next,
      walletStatus,
      walletUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(ledgerRef, {
      driverId,
      type,
      amountIqd,
      balanceAfterIqd: next,
      status: status || "posted",
      description: description || note || "",
      referenceId: resolvedReferenceId,
      rideId: rideId || null,
      rechargeRequestId: rechargeRequestId || null,
      withdrawalRequestId: withdrawalRequestId || null,
      rewardCampaignId: rewardCampaignId || null,
      rewardGrantId: rewardGrantId || null,
      createdBy: createdBy || "system",
      note: note || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      balanceAfterIqd: next,
      walletStatus,
      ledgerEntryId: ledgerRef.id,
      referenceId: resolvedReferenceId,
    };
  });
}

exports.saveWalletConfig = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const minBalanceIqd = Math.max(1, Math.trunc(Number(data.minBalanceIqd) || 1));
  const lowBalanceWarningIqd = Math.max(
    0,
    Math.trunc(Number(data.lowBalanceWarningIqd) || 5000),
  );
  const enabledMethods = Array.isArray(data.enabledMethods)
    ? data.enabledMethods.map(String)
    : ["superQi", "cash", "bankTransfer"];

  const minWithdrawalIqd = Math.max(
    1000,
    Math.trunc(Number(data.minWithdrawalIqd) || 5000),
  );
  const maxWithdrawalIqd = Math.max(
    0,
    Math.trunc(Number(data.maxWithdrawalIqd) || 0),
  );
  const withdrawalsEnabled = data.withdrawalsEnabled !== false;

  await admin.firestore().collection("config").doc("wallet").set(
    {
      minBalanceIqd,
      lowBalanceWarningIqd,
      minWithdrawalIqd,
      maxWithdrawalIqd,
      withdrawalsEnabled,
      companySuperQiNumber: String(data.companySuperQiNumber || "").trim(),
      companySuperQiName:
        String(data.companySuperQiName || "Hello Tuk-Tuk").trim() ||
        "Hello Tuk-Tuk",
      managerWhatsappNumber: String(data.managerWhatsappNumber || "").trim(),
      rechargeInstructionsEn: String(data.rechargeInstructionsEn || "").trim(),
      rechargeInstructionsAr: String(data.rechargeInstructionsAr || "").trim(),
      enabledMethods,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    },
    { merge: true },
  );
  return { ok: true };
});

/** One-time / ops: create wallet fields on drivers that never received them. */
exports.ensureDriverWallets = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings", "allDrivers"]);
  const db = admin.firestore();
  const config = await getWalletConfig();
  const snap = await db.collection("drivers").get();
  let updated = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const d = doc.data() || {};
    if (d.walletBalanceIqd != null && d.walletStatus) continue;
    const balance = Number(d.walletBalanceIqd) || 0;
    const walletStatus =
      d.walletStatus ||
      deriveWalletStatus(balance, config.minBalanceIqd, config.lowBalanceWarningIqd);
    batch.set(
      doc.ref,
      {
        walletBalanceIqd: d.walletBalanceIqd == null ? 0 : balance,
        walletStatus,
        walletUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    updated += 1;
    batchCount += 1;
    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
  if (batchCount > 0) {
    await batch.commit();
  }
  functions.logger.info("ensureDriverWallets", {
    updated,
    total: snap.size,
    by: context.auth.uid,
  });
  return { ok: true, updated, total: snap.size };
});

exports.submitWalletRechargeRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const amountIqd = Math.trunc(Number(data.amountIqd));
  const method = String(data.method || "superQi").trim();
  const screenshotUrl = String(data.screenshotUrl || "").trim();
  const referenceNumber = String(data.referenceNumber || "").trim();
  const notes = String(data.notes || "").trim();
  const allowed = new Set(["superQi", "cash", "bankTransfer", "gateway"]);

  if (!Number.isFinite(amountIqd) || amountIqd < 1000) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Minimum recharge is 1000 IQD.",
    );
  }
  if (!allowed.has(method)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid payment method.");
  }
  if (!screenshotUrl) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Payment screenshot is required.",
    );
  }

  const driverId = context.auth.uid;
  const driverDoc = await admin.firestore().collection("drivers").doc(driverId).get();
  if (!driverDoc.exists) {
    throw new functions.https.HttpsError("failed-precondition", "Driver profile required.");
  }
  const driver = driverDoc.data() || {};

  const ref = await admin.firestore().collection("walletRechargeRequests").add({
    driverId,
    driverName: String(driver.name || ""),
    driverPhone: String(driver.phone || ""),
    districtId: String(driver.assignedDistrictId || "").trim(),
    subDistrictId: String(driver.assignedSubDistrictId || "").trim(),
    method,
    amountIqd,
    screenshotUrl,
    referenceNumber,
    notes,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Notify managers (best effort).
  try {
    const managers = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "manager")
      .limit(20)
      .get();
    for (const doc of managers.docs) {
      const token = doc.data()?.fcmToken;
      await sendToToken(
        token,
        "Wallet recharge request",
        `${driver.name || "Driver"} requested ${amountIqd} IQD`,
        { type: "wallet_recharge_pending", requestId: ref.id },
        "default",
      );
    }
  } catch (error) {
    functions.logger.warn("wallet recharge manager notify failed", {
      message: error.message,
    });
  }

  return { ok: true, requestId: ref.id };
});

exports.reviewWalletRechargeRequest = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const requestId = String(data.requestId || "").trim();
  const approve = data.approve === true;
  const rejectionReason = String(data.rejectionReason || "").trim();
  const hasApprovedAmount = data.approvedAmountIqd !== undefined &&
    data.approvedAmountIqd !== null &&
    String(data.approvedAmountIqd).trim() !== "";
  const approvedAmountRaw = hasApprovedAmount
    ? Math.trunc(Number(data.approvedAmountIqd))
    : null;
  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId required.");
  }
  if (!approve && !rejectionReason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Rejection reason is required.",
    );
  }
  if (approve && hasApprovedAmount && (!Number.isFinite(approvedAmountRaw) || approvedAmountRaw < 1000)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Approved amount must be at least 1000 IQD.",
    );
  }

  const db = admin.firestore();
  const requestRef = db.collection("walletRechargeRequests").doc(requestId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(requestRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Request not found.");
    }
    const req = snap.data() || {};
    if (req.status !== "pending") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Request already reviewed.",
      );
    }
    if (!approve) {
      tx.update(requestRef, {
        status: "rejected",
        rejectionReason,
        reviewedBy: context.auth.uid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { driverId: String(req.driverId || ""), approved: false, amountIqd: 0 };
    }
    const requestedAmountIqd = Number(req.amountIqd) || 0;
    const creditAmountIqd = hasApprovedAmount
      ? approvedAmountRaw
      : requestedAmountIqd;
    if (!Number.isFinite(creditAmountIqd) || creditAmountIqd < 1000) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Approved amount must be at least 1000 IQD.",
      );
    }
    tx.update(requestRef, {
      status: "approved",
      rejectionReason: "",
      requestedAmountIqd,
      approvedAmountIqd: creditAmountIqd,
      amountIqd: creditAmountIqd,
      reviewedBy: context.auth.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      driverId: String(req.driverId || ""),
      approved: true,
      amountIqd: creditAmountIqd,
      requestedAmountIqd,
    };
  });

  if (result.approved && result.driverId) {
    const amountNote =
      result.requestedAmountIqd !== result.amountIqd
        ? `SuperQi/manual recharge approved (${requestId}); requested ${result.requestedAmountIqd}, credited ${result.amountIqd}`
        : `SuperQi/manual recharge approved (${requestId})`;
    await applyWalletDelta({
      driverId: result.driverId,
      amountIqd: result.amountIqd,
      type: "recharge",
      createdBy: context.auth.uid,
      note: amountNote,
      rechargeRequestId: requestId,
    });
  }

  if (result.driverId) {
    try {
      const driverUser = await db.collection("users").doc(result.driverId).get();
      const driverDoc = await db.collection("drivers").doc(result.driverId).get();
      const token =
        driverUser.data()?.fcmToken || driverDoc.data()?.fcmToken || null;
      await sendToToken(
        token,
        result.approved ? "Wallet recharged" : "Recharge rejected",
        result.approved
          ? `Your wallet was credited ${result.amountIqd} IQD.`
          : rejectionReason || "Your recharge request was rejected.",
        {
          type: result.approved ? "wallet_recharge_approved" : "wallet_recharge_rejected",
          requestId,
        },
        "default",
      );
    } catch (_) {}
  }

  return { ok: true, approved: result.approved };
});

exports.adjustDriverWallet = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const driverId = String(data.driverId || "").trim();
  const amountIqd = Math.trunc(Number(data.amountIqd));
  const note = String(data.note || "").trim();
  if (!driverId || !Number.isFinite(amountIqd) || amountIqd === 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid adjustment.");
  }
  if (!note) {
    throw new functions.https.HttpsError("invalid-argument", "Note is required.");
  }
  const result = await applyWalletDelta({
    driverId,
    amountIqd,
    type: amountIqd > 0 ? "adjustment" : "penalty",
    createdBy: context.auth.uid,
    note,
    description: note,
    referenceId: `ADJ-${Date.now()}`,
  });
  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: amountIqd > 0 ? "wallet.recharged" : "wallet.deducted",
    entityType: "driver",
    entityId: driverId,
    details: { amountIqd, note },
  });
  return { ok: true, ...result };
});

const OPEN_WITHDRAWAL_STATUSES = new Set(["pending", "approved", "processing"]);

exports.submitWalletWithdrawalRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const amountIqd = Math.trunc(Number(data.amountIqd));
  const cardholderName = String(data.cardholderName || "").trim();
  const cardNumber = String(data.cardNumber || "").replace(/\D/g, "");
  const config = await getWalletConfig();

  if (!config.withdrawalsEnabled) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Withdrawals are temporarily disabled.",
    );
  }
  if (!Number.isFinite(amountIqd) || amountIqd < config.minWithdrawalIqd) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Minimum withdrawal is ${config.minWithdrawalIqd} IQD.`,
    );
  }
  if (config.maxWithdrawalIqd > 0 && amountIqd > config.maxWithdrawalIqd) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Maximum withdrawal is ${config.maxWithdrawalIqd} IQD.`,
    );
  }
  if (!cardholderName || cardholderName.length < 2) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Cardholder name is required.",
    );
  }
  if (!isValidMastercard(cardNumber)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Enter a valid Mastercard number.",
    );
  }

  const driverId = context.auth.uid;
  const db = admin.firestore();
  const driverDoc = await db.collection("drivers").doc(driverId).get();
  if (!driverDoc.exists) {
    throw new functions.https.HttpsError("failed-precondition", "Driver profile required.");
  }
  const driver = driverDoc.data() || {};
  const balance = Number(driver.walletBalanceIqd) || 0;
  if (balance < amountIqd) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Insufficient wallet balance.",
    );
  }

  const openSnap = await db
    .collection("walletWithdrawalRequests")
    .where("driverId", "==", driverId)
    .where("status", "in", ["pending", "approved", "processing"])
    .limit(1)
    .get();
  if (!openSnap.empty) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You already have an open withdrawal request.",
    );
  }

  const referenceId = makeWithdrawalReferenceId();
  const requestRef = db.collection("walletWithdrawalRequests").doc();
  const secretRef = db.collection("walletWithdrawalSecrets").doc(requestRef.id);
  const batch = db.batch();
  batch.set(requestRef, {
    driverId,
    driverName: String(driver.name || ""),
    driverPhone: String(driver.phone || ""),
    districtId: String(driver.assignedDistrictId || "").trim(),
    subDistrictId: String(driver.assignedSubDistrictId || "").trim(),
    amountIqd,
    cardholderName,
    cardLast4: cardNumber.slice(-4),
    cardBrand: "mastercard",
    status: "pending",
    adminNote: "",
    rejectionReason: "",
    referenceId,
    ledgerEntryId: "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(secretRef, {
    cardNumber,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();

  try {
    const managers = await db
      .collection("users")
      .where("role", "==", "manager")
      .limit(20)
      .get();
    for (const doc of managers.docs) {
      await sendToToken(
        doc.data()?.fcmToken,
        "Wallet withdrawal request",
        `${driver.name || "Driver"} requested ${amountIqd} IQD`,
        { type: "wallet_withdrawal_pending", requestId: requestRef.id },
        "default",
      );
    }
  } catch (error) {
    functions.logger.warn("wallet withdrawal manager notify failed", {
      message: error.message,
    });
  }

  return { ok: true, requestId: requestRef.id, referenceId };
});

exports.cancelWalletWithdrawalRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const requestId = String(data.requestId || "").trim();
  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId required.");
  }
  const db = admin.firestore();
  const ref = db.collection("walletWithdrawalRequests").doc(requestId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Request not found.");
    }
    const req = snap.data() || {};
    if (req.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "Not your request.");
    }
    if (req.status !== "pending") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Only pending requests can be cancelled.",
      );
    }
    tx.update(ref, {
      status: "cancelled",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

exports.reviewWalletWithdrawalRequest = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const requestId = String(data.requestId || "").trim();
  const action = String(data.action || "").trim().toLowerCase();
  const adminNote = String(data.adminNote || "").trim();
  const rejectionReason = String(data.rejectionReason || "").trim();
  if (!requestId || !["approve", "reject"].includes(action)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "requestId and action (approve|reject) required.",
    );
  }
  if (action === "reject" && !rejectionReason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Rejection reason is required.",
    );
  }

  const db = admin.firestore();
  const ref = db.collection("walletWithdrawalRequests").doc(requestId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Request not found.");
    }
    const req = snap.data() || {};
    const status = String(req.status || "");
    if (action === "approve") {
      if (status !== "pending") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Only pending requests can be approved.",
        );
      }
      tx.update(ref, {
        status: "approved",
        adminNote,
        rejectionReason: "",
        reviewedBy: context.auth.uid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      if (!["pending", "approved", "processing"].includes(status)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Request cannot be rejected in its current status.",
        );
      }
      tx.update(ref, {
        status: "rejected",
        adminNote,
        rejectionReason,
        reviewedBy: context.auth.uid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return {
      driverId: String(req.driverId || ""),
      amountIqd: Number(req.amountIqd) || 0,
      approved: action === "approve",
      referenceId: String(req.referenceId || ""),
    };
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: action === "approve" ? "wallet.withdrawal_approved" : "wallet.withdrawal_rejected",
    entityType: "walletWithdrawalRequest",
    entityId: requestId,
    details: {
      amountIqd: result.amountIqd,
      referenceId: result.referenceId,
      rejectionReason,
      adminNote,
    },
  });

  if (result.driverId) {
    try {
      const driverUser = await db.collection("users").doc(result.driverId).get();
      const driverDoc = await db.collection("drivers").doc(result.driverId).get();
      const token =
        driverUser.data()?.fcmToken || driverDoc.data()?.fcmToken || null;
      await sendToToken(
        token,
        result.approved ? "Withdrawal approved" : "Withdrawal rejected",
        result.approved
          ? `Your withdrawal of ${result.amountIqd} IQD was approved.`
          : rejectionReason || "Your withdrawal request was rejected.",
        {
          type: result.approved
            ? "wallet_withdrawal_approved"
            : "wallet_withdrawal_rejected",
          requestId,
        },
        "default",
      );
    } catch (_) {}
  }

  return { ok: true, approved: result.approved };
});

exports.processWalletWithdrawalRequest = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const requestId = String(data.requestId || "").trim();
  const adminNote = String(data.adminNote || "").trim();
  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId required.");
  }
  const db = admin.firestore();
  const ref = db.collection("walletWithdrawalRequests").doc(requestId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Request not found.");
    }
    const req = snap.data() || {};
    if (req.status !== "approved") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Only approved requests can move to processing.",
      );
    }
    tx.update(ref, {
      status: "processing",
      adminNote: adminNote || req.adminNote || "",
      processedBy: context.auth.uid,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      driverId: String(req.driverId || ""),
      amountIqd: Number(req.amountIqd) || 0,
      referenceId: String(req.referenceId || ""),
    };
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "wallet.withdrawal_processing",
    entityType: "walletWithdrawalRequest",
    entityId: requestId,
    details: result,
  });

  if (result.driverId) {
    try {
      const driverUser = await db.collection("users").doc(result.driverId).get();
      const driverDoc = await db.collection("drivers").doc(result.driverId).get();
      const token =
        driverUser.data()?.fcmToken || driverDoc.data()?.fcmToken || null;
      await sendToToken(
        token,
        "Withdrawal processing",
        `Your withdrawal of ${result.amountIqd} IQD is being processed.`,
        { type: "wallet_withdrawal_processing", requestId },
        "default",
      );
    } catch (_) {}
  }

  return { ok: true };
});

exports.completeWalletWithdrawalRequest = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const requestId = String(data.requestId || "").trim();
  const adminNote = String(data.adminNote || "").trim();
  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId required.");
  }

  const db = admin.firestore();
  const ref = db.collection("walletWithdrawalRequests").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Request not found.");
  }
  const req = snap.data() || {};
  if (req.status !== "processing" && req.status !== "approved") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Only approved/processing requests can be completed.",
    );
  }
  if (req.ledgerEntryId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Withdrawal already completed.",
    );
  }

  const driverId = String(req.driverId || "");
  const amountIqd = Math.trunc(Number(req.amountIqd) || 0);
  const referenceId = String(req.referenceId || requestId);
  if (!driverId || amountIqd <= 0) {
    throw new functions.https.HttpsError("failed-precondition", "Invalid withdrawal.");
  }

  const delta = await applyWalletDelta({
    driverId,
    amountIqd: -amountIqd,
    type: "withdrawal",
    createdBy: context.auth.uid,
    note: `Withdrawal ${referenceId}`,
    description: `Mastercard withdrawal ${referenceId}`,
    withdrawalRequestId: requestId,
    referenceId,
    status: "posted",
  });

  await ref.update({
    status: "completed",
    adminNote: adminNote || req.adminNote || "",
    ledgerEntryId: delta.ledgerEntryId,
    processedBy: req.processedBy || context.auth.uid,
    processedAt: req.processedAt || admin.firestore.FieldValue.serverTimestamp(),
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "wallet.withdrawal_completed",
    entityType: "walletWithdrawalRequest",
    entityId: requestId,
    details: {
      amountIqd,
      referenceId,
      ledgerEntryId: delta.ledgerEntryId,
      balanceAfterIqd: delta.balanceAfterIqd,
    },
  });

  try {
    const driverUser = await db.collection("users").doc(driverId).get();
    const driverDoc = await db.collection("drivers").doc(driverId).get();
    const token =
      driverUser.data()?.fcmToken || driverDoc.data()?.fcmToken || null;
    await sendToToken(
      token,
      "Withdrawal completed",
      `${amountIqd} IQD was sent to your Mastercard.`,
      { type: "wallet_withdrawal_completed", requestId },
      "default",
    );
  } catch (_) {}

  return { ok: true, ...delta };
});

exports.getWithdrawalCardForAdmin = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["wallet", "earnings"]);
  const requestId = String(data.requestId || "").trim();
  if (!requestId) {
    throw new functions.https.HttpsError("invalid-argument", "requestId required.");
  }
  const db = admin.firestore();
  const [reqSnap, secretSnap] = await Promise.all([
    db.collection("walletWithdrawalRequests").doc(requestId).get(),
    db.collection("walletWithdrawalSecrets").doc(requestId).get(),
  ]);
  if (!reqSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Request not found.");
  }
  if (!secretSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Card details not found.");
  }
  const cardNumber = String(secretSnap.data()?.cardNumber || "").replace(/\D/g, "");
  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "wallet.withdrawal_card_viewed",
    entityType: "walletWithdrawalRequest",
    entityId: requestId,
    details: {
      cardLast4: cardNumber.slice(-4),
      referenceId: String(reqSnap.data()?.referenceId || ""),
    },
  });
  return {
    ok: true,
    cardNumber,
    cardLast4: cardNumber.slice(-4),
    cardholderName: String(reqSnap.data()?.cardholderName || ""),
  };
});

const serviceAreaCollections = {
  country: "serviceCountries",
  province: "serviceProvinces",
  district: "serviceDistricts",
  subDistrict: "serviceSubDistricts",
};

exports.saveServiceArea = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["serviceAreas", "pricing"]);
  const kind = String(data.kind || "").trim();
  const id = String(data.id || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "_");
  const payload = data.data && typeof data.data === "object" ? data.data : {};
  const mergeOnly = data.mergeOnly === true;
  const collection = serviceAreaCollections[kind];
  if (!collection || !id) {
    throw new functions.https.HttpsError("invalid-argument", "kind and id required.");
  }
  if (kind === "subDistrict" && payload.boundary !== undefined && payload.boundary !== null) {
    const boundary = payload.boundary;
    const isValidPoint = (p) =>
      p && Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng));
    if (!Array.isArray(boundary) || boundary.length < 3 || !boundary.every(isValidPoint)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "boundary must be an array of at least 3 {lat, lng} points.",
      );
    }
    payload.boundary = boundary.map((p) => ({ lat: Number(p.lat), lng: Number(p.lng) }));
  }
  const ref = admin.firestore().collection(collection).doc(id);
  if (mergeOnly) {
    await ref.set(
      {
        ...payload,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
  } else {
    await ref.set(
      {
        ...payload,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
  }
  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: `serviceArea.${kind}.saved`,
    entityType: kind,
    entityId: id,
    details: { mergeOnly },
  });
  return { ok: true, id };
});

const SERVICE_AREA_STATUSES = new Set([
  "active",
  "inactive",
  "maintenance",
  "archived",
]);

async function cascadeServiceAreaStatus({
  kind,
  id,
  status,
  actorUid,
  deletedAt = false,
}) {
  const db = admin.firestore();
  const stamp = {
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: actorUid,
    ...(deletedAt
      ? { deletedAt: admin.firestore.FieldValue.serverTimestamp() }
      : {}),
  };

  if (kind === "country") {
    await db.collection("serviceCountries").doc(id).set(stamp, { merge: true });
    const provinces = await db
      .collection("serviceProvinces")
      .where("countryId", "==", id)
      .get();
    for (const doc of provinces.docs) {
      await cascadeServiceAreaStatus({
        kind: "province",
        id: doc.id,
        status,
        actorUid,
        deletedAt,
      });
    }
    return;
  }

  if (kind === "province") {
    await db.collection("serviceProvinces").doc(id).set(stamp, { merge: true });
    const districts = await db
      .collection("serviceDistricts")
      .where("provinceId", "==", id)
      .get();
    for (const doc of districts.docs) {
      await cascadeServiceAreaStatus({
        kind: "district",
        id: doc.id,
        status,
        actorUid,
        deletedAt,
      });
    }
    return;
  }

  if (kind === "district") {
    await db.collection("serviceDistricts").doc(id).set(stamp, { merge: true });
    const subs = await db
      .collection("serviceSubDistricts")
      .where("districtId", "==", id)
      .get();
    const batch = db.batch();
    for (const doc of subs.docs) {
      batch.set(doc.ref, stamp, { merge: true });
    }
    await batch.commit();
    return;
  }

  if (kind === "subDistrict") {
    await db.collection("serviceSubDistricts").doc(id).set(stamp, { merge: true });
  }
}

exports.setServiceAreaStatus = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["serviceAreas", "pricing"]);
  const kind = String(data.kind || "").trim();
  const id = String(data.id || "").trim();
  const status = String(data.status || "").trim();
  const cascade = data.cascade !== false;
  if (!serviceAreaCollections[kind] || !id || !SERVICE_AREA_STATUSES.has(status)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "kind, id, and valid status required.",
    );
  }
  if (cascade) {
    await cascadeServiceAreaStatus({
      kind,
      id,
      status,
      actorUid: context.auth.uid,
    });
  } else {
    await admin.firestore().collection(serviceAreaCollections[kind]).doc(id).set(
      {
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
  }
  return { ok: true };
});

exports.deleteServiceArea = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["serviceAreas", "pricing"]);
  const kind = String(data.kind || "").trim();
  const id = String(data.id || "").trim();
  const collection = serviceAreaCollections[kind];
  if (!collection || !id) {
    throw new functions.https.HttpsError("invalid-argument", "kind and id required.");
  }
  // Soft-delete → archived (+ cascade) so history remains but new rides stop.
  await cascadeServiceAreaStatus({
    kind,
    id,
    status: "archived",
    actorUid: context.auth.uid,
    deletedAt: true,
  });
  return { ok: true };
});

exports.seedServiceAreas = functions.https.onCall(async (data, context) => {
  await assertAdminPermissionAny(context, ["serviceAreas", "pricing"]);
  const db = admin.firestore();
  const batch = db.batch();
  const countryRef = db.collection("serviceCountries").doc("iq");
  batch.set(
    countryRef,
    {
      nameEn: "Iraq",
      nameAr: "العراق",
      code: "IQ",
      currency: "IQD",
      status: "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    },
    { merge: true },
  );
  const provinceRef = db.collection("serviceProvinces").doc("babil");
  batch.set(
    provinceRef,
    {
      countryId: "iq",
      nameEn: "Babil Province",
      nameAr: "محافظة بابل",
      customerVisible: true,
      status: "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    },
    { merge: true },
  );

  const districts = [
    { id: "hilla", nameEn: "Al-Hillah District", nameAr: "قضاء الحلة", customerVisible: false },
    { id: "mahawil", nameEn: "Al-Mahawil District", nameAr: "قضاء المحاويل", customerVisible: false },
    { id: "musayab", nameEn: "Al-Musayab District", nameAr: "قضاء المسيب", customerVisible: false },
    { id: "hashimiya", nameEn: "Al-Hashimiya District", nameAr: "قضاء الهاشمية", customerVisible: true },
  ];
  for (const d of districts) {
    batch.set(
      db.collection("serviceDistricts").doc(d.id),
      {
        provinceId: "babil",
        countryId: "iq",
        nameEn: d.nameEn,
        nameAr: d.nameAr,
        customerVisible: d.customerVisible,
        status: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
  }

  const subs = [
    { id: "hilla_center", districtId: "hilla", nameEn: "Hilla Center", nameAr: "ناحية مركز الحلة", lat: 32.4637, lng: 44.4197, r: 22 },
    { id: "jameaa", districtId: "hilla", nameEn: "Al-Jamiyah", nameAr: "ناحية الجامعة", lat: 32.461, lng: 44.415, r: 22 },
    { id: "qadisiyah", districtId: "hilla", nameEn: "Al-Qadisiyah", nameAr: "حي القادسية", lat: 32.471, lng: 44.425, r: 22 },
    { id: "mahawil_center", districtId: "mahawil", nameEn: "Mahawil Center", nameAr: "ناحية مركز المحاويل", lat: 32.655, lng: 44.385, r: 22 },
    { id: "musayab_center", districtId: "musayab", nameEn: "Musayab Center", nameAr: "ناحية مركز المسيب", lat: 32.778, lng: 44.29, r: 22 },
    { id: "hashimiya_center", districtId: "hashimiya", nameEn: "Hashimiya Center", nameAr: "ناحية مركز الهاشمية", lat: 32.374, lng: 44.665, r: 22 },
    { id: "qasim", districtId: "hashimiya", nameEn: "Al-Qasim", nameAr: "ناحية القاسم", lat: 32.3014, lng: 44.6892, r: 25 },
    { id: "madhatiyah", districtId: "hashimiya", nameEn: "Al-Madhatiyah", nameAr: "ناحية المدحتية", lat: 32.3964, lng: 44.6536, r: 25 },
    { id: "shumali", districtId: "hashimiya", nameEn: "Al-Shumali", nameAr: "ناحية الشوملي", lat: 32.328, lng: 44.918, r: 28 },
    { id: "taleaa", districtId: "hashimiya", nameEn: "Al-Taleaa", nameAr: "ناحية الطليعة", lat: 32.35, lng: 44.78, r: 25 },
  ];
  for (const s of subs) {
    batch.set(
      db.collection("serviceSubDistricts").doc(s.id),
      {
        districtId: s.districtId,
        provinceId: "babil",
        countryId: "iq",
        nameEn: s.nameEn,
        nameAr: s.nameAr,
        latitude: s.lat,
        longitude: s.lng,
        searchRadiusKm: s.r,
        status: "active",
        services: ["ride"],
        useGlobalCommission: true,
        pricing: { useGlobalPricing: true },
        operatingHours: { alwaysOpen: true },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
  }

  await batch.commit();
  return { ok: true, districts: districts.length, subDistricts: subs.length };
});

// --- Ride lifecycle (server-authoritative) ---
const { createRidesModule } = require("./rides");
const ridesRuntime = createRidesModule({
  admin,
  functions,
  assertAdminPermissionAny,
});
exports.createRide = ridesRuntime.createRide;
exports.acceptRide = ridesRuntime.acceptRide;
exports.rejectRide = ridesRuntime.rejectRide;
exports.startRide = ridesRuntime.startRide;
exports.endRideAwaitingCash = ridesRuntime.endRideAwaitingCash;
exports.confirmCashCollected = ridesRuntime.confirmCashCollected;
exports.cancelRide = ridesRuntime.cancelRide;
exports.assignNearestDriver = ridesRuntime.assignNearestDriver;
exports.submitDriverRating = ridesRuntime.submitDriverRating;
exports.applyPendingRideEarnings = ridesRuntime.applyPendingRideEarnings;

// --- Driver Rewards & Incentives ---
const { createRewardsModule } = require("./rewards");
rewardsRuntime.mod = createRewardsModule({
  admin,
  functions,
  applyWalletDelta,
  sendToToken,
  assertAdminPermissionAny,
  writeAdminAuditLog,
});
exports.saveRewardCampaign = rewardsRuntime.mod.saveRewardCampaign;
exports.setRewardCampaignStatus = rewardsRuntime.mod.setRewardCampaignStatus;
exports.deleteRewardCampaign = rewardsRuntime.mod.deleteRewardCampaign;
exports.evaluateDriverRewards = rewardsRuntime.mod.evaluateDriverRewards;

exports.onDriverUpdatedForRewards = functions.firestore
  .document("drivers/{driverId}")
  .onUpdate(async (change, context) => {
    if (!rewardsRuntime.mod) return null;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    try {
      await rewardsRuntime.mod.accumulateOnlineSeconds(
        context.params.driverId,
        before,
        after,
      );
    } catch (error) {
      functions.logger.warn("online seconds accumulate failed", {
        driverId: context.params.driverId,
        message: error.message,
      });
    }
    return null;
  });

// --- Multi-Business Management ---
const { createBusinessModule } = require("./business");
const businessModule = createBusinessModule({
  admin,
  functions,
  assertAdminPermissionAny,
  sendToToken,
  authAdminCallable,
  writeAdminAuditLog,
});
exports.seedBusinessTypes = businessModule.seedBusinessTypes;
exports.saveBusinessTypes = businessModule.saveBusinessTypes;
exports.createBusinessPartner = businessModule.createBusinessPartner;
exports.setBusinessStatus = businessModule.setBusinessStatus;
exports.saveBusinessProfile = businessModule.saveBusinessProfile;
exports.submitBusinessForReview = businessModule.submitBusinessForReview;
exports.deleteBusiness = businessModule.deleteBusiness;
exports.saveBusinessCategory = businessModule.saveBusinessCategory;
exports.deleteBusinessCategory = businessModule.deleteBusinessCategory;
exports.saveBusinessProduct = businessModule.saveBusinessProduct;
exports.deleteBusinessProduct = businessModule.deleteBusinessProduct;
exports.duplicateBusinessProduct = businessModule.duplicateBusinessProduct;
exports.bulkUpdateBusinessPrices = businessModule.bulkUpdateBusinessPrices;
exports.placeBusinessOrder = businessModule.placeBusinessOrder;
exports.updateBusinessOrderStatus = businessModule.updateBusinessOrderStatus;

exports.applyReferralCode = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const uid = request.auth.uid;
  const code = String(request.data?.referralCode || "")
    .trim()
    .toUpperCase();
  if (!code) {
    throw new functions.https.HttpsError("invalid-argument", "Referral code required.");
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError("not-found", "User profile not found.");
  }
  const userData = userSnap.data() || {};
  if (userData.referralAppliedAt) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Referral already claimed.",
    );
  }
  if (userData.referralCode === code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "You cannot use your own referral code.",
    );
  }

  const referrerSnap = await db
    .collection("users")
    .where("referralCode", "==", code)
    .limit(1)
    .get();
  if (referrerSnap.empty) {
    throw new functions.https.HttpsError("not-found", "Invalid referral code.");
  }
  const referrerDoc = referrerSnap.docs[0];
  const referrerId = referrerDoc.id;
  if (referrerId === uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "You cannot refer yourself.",
    );
  }

  const appConfigSnap = await db.collection("config").doc("app").get();
  const appConfig = appConfigSnap.data() || {};
  const referralEnabled = appConfig.referralEnabled === true;
  const referrerReward = Math.max(
    0,
    Math.trunc(Number(appConfig.referralRewardReferrerIqd) || 0),
  );
  const newUserReward = Math.max(
    0,
    Math.trunc(Number(appConfig.referralRewardNewUserIqd) || 0),
  );

  if (!referralEnabled) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Referral program is not enabled.",
    );
  }

  await db.runTransaction(async (tx) => {
    const freshUser = await tx.get(userRef);
    if (!freshUser.exists) {
      throw new functions.https.HttpsError("not-found", "User profile not found.");
    }
    const freshData = freshUser.data() || {};
    if (freshData.referralAppliedAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Referral already claimed.",
      );
    }

    const referrerRef = db.collection("users").doc(referrerId);
    const freshReferrer = await tx.get(referrerRef);
    if (!freshReferrer.exists) {
      throw new functions.https.HttpsError("not-found", "Referrer not found.");
    }

    const userUpdates = {
      referralAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
      referralReferrerId: referrerId,
      referredByCode: code,
    };
    if (newUserReward > 0) {
      userUpdates.walletBalanceIqd =
        (Number(freshData.walletBalanceIqd) || 0) + newUserReward;
    }
    tx.update(userRef, userUpdates);

    if (referrerReward > 0) {
      const referrerData = freshReferrer.data() || {};
      tx.update(referrerRef, {
        walletBalanceIqd:
          (Number(referrerData.walletBalanceIqd) || 0) + referrerReward,
        referralRewardsEarnedIqd:
          (Number(referrerData.referralRewardsEarnedIqd) || 0) + referrerReward,
      });
    }
  });

  await writeAdminAuditLog({
    adminId: uid,
    action: "referral.applied",
    entityType: "user",
    entityId: uid,
    details: {
      referralCode: code,
      referrerId,
      referrerRewardIqd: referrerReward,
      newUserRewardIqd: newUserReward,
    },
  });

  return {
    ok: true,
    referrerId,
    referrerRewardIqd: referrerReward,
    newUserRewardIqd: newUserReward,
  };
});

exports.warnDriver = onCall({ region: "us-central1" }, async (request) => {
  const context = { auth: request.auth };
  await assertAdminPermissionAny(context, ["driverPerformance", "allDrivers"]);

  const driverId = String(request.data?.driverId || "").trim();
  const reason = String(request.data?.reason || "").trim();
  if (!driverId) {
    throw new functions.https.HttpsError("invalid-argument", "driverId required.");
  }

  const db = admin.firestore();
  const driverRef = db.collection("drivers").doc(driverId);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Driver not found.");
  }
  const driverData = driverSnap.data() || {};

  await driverRef.update({
    warningCount: admin.firestore.FieldValue.increment(1),
    lastWarningAt: admin.firestore.FieldValue.serverTimestamp(),
    lastWarningReason: reason || null,
  });

  const userSnap = await db.collection("users").doc(driverId).get();
  const token = userSnap.data()?.fcmToken;
  if (token) {
    await sendToToken(
      token,
      "Performance warning",
      reason || "Please review platform guidelines.",
      { type: "driver_warning", driverId },
      "customer_ride_accepted",
    );
  }

  await writeAdminAuditLog({
    adminId: context.auth.uid,
    action: "driver.warned",
    entityType: "driver",
    entityId: driverId,
    details: {
      driverName: driverData.name || "",
      reason: reason || "",
    },
  });

  return { ok: true };
});
