const functions = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

require("dotenv").config();

if (!admin.apps.length) {
  admin.initializeApp();
}

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
      for (const offeredDriverId of after.offeredDriverIds) {
        const driverDoc = await admin
          .firestore()
          .collection("drivers")
          .doc(String(offeredDriverId))
          .get();
        const driverData = driverDoc.data() || {};
        if (driverData.isFakeDriver && driverData.autoAcceptRides) {
          continue;
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
  });

const allowedAssistantPermissions = new Set([
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

  return { ok: true, docId };
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
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

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
  "AIzaSyCygbeGlDUlA7l0GkJjB8TUHvHNUlHwsBg";

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

  const audience = String(data.audience || "").trim();
  const title = String(data.title || "").trim();
  const body = String(data.message || data.body || "").trim();

  if (!title || !body) {
    throw new functions.https.HttpsError("invalid-argument", "Title and message required.");
  }
  if (audience !== "drivers" && audience !== "customers") {
    throw new functions.https.HttpsError("invalid-argument", "Audience must be drivers or customers.");
  }

  const tokens = new Set();
  if (audience === "drivers") {
    const snapshot = await admin.firestore().collection("drivers").get();
    for (const doc of snapshot.docs) {
      const driver = doc.data() || {};
      if (driver.isBlocked || driver.isRemoved || driver.isFakeDriver) continue;
      if (driver.approvalStatus !== "approved") continue;
      if (driver.fcmToken) tokens.add(driver.fcmToken);
    }
  } else {
    const snapshot = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "customer")
      .get();
    for (const doc of snapshot.docs) {
      const user = doc.data() || {};
      if (user.isBlocked) continue;
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
  });

  return { sent, total: tokens.size, audience };
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

  await driverRef.set(update, { merge: true });

  functions.logger.info("setDriverApprovalStatus", {
    driverId,
    status,
    reviewedBy: context.auth.uid,
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
