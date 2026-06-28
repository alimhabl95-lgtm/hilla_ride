const functions = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

require("dotenv").config();

if (!admin.apps.length) {
  admin.initializeApp();
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
  let digits = String(raw || "").replace(/\D/g, "");
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

exports.createAssistant = functions.https.onCall(async (data, context) => {
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

  const name = String(data.name || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "");
  const permissions = Array.isArray(data.permissions) ? data.permissions : [];

  if (!name || !email || password.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid assistant data.");
  }

  const sanitizedPermissions = permissions.filter((permission) =>
    allowedAssistantPermissions.has(permission),
  );

  const userRecord = await admin.auth().createUser({
    email,
    password,
    displayName: name,
  });

  await admin.firestore().collection("users").doc(userRecord.uid).set({
    name,
    email,
    phone: "",
    role: "assistant",
    age: 18,
    permissions: sanitizedPermissions,
    createdBy: context.auth.uid,
    isBlocked: false,
    cancelledRidesCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { uid: userRecord.uid };
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
exports.resetPasswordByPhoneVerified = functions.https.onCall(async (data) =>
  runResetPasswordByPhone(normalizePhone, data),
);

exports.registerWithPhonePassword = functions.https.onCall(async (data) =>
  runRegisterWithPhonePassword(data),
);

exports.resetPasswordByPhone = functions.https.onCall(async (data) =>
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

exports.requestPasswordReset = functions.https.onCall(async (data) => {
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

exports.updateAccountPhone = functions.https.onCall(async (data, context) => {
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
  const email = String(payload.email || "").trim();
  const age = Number(payload.age || 18);

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

  const db = admin.firestore();
  const activeUsers = await db.collection("users").where("phone", "==", phone).limit(1).get();
  if (!activeUsers.empty) {
    throw new functions.https.HttpsError(
      "already-exists",
      "An account with this phone number already exists.",
    );
  }

  await cleanupDeletedAccountArtifacts(phone, null);

  const phoneKey = phoneKeyFromPhone(phone);
  let userRecord;
  try {
    userRecord = await admin.auth().createUser({
      email: authEmailFromPhoneKey(phoneKey),
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

  const profile = {
    phone,
    role,
    name: fullName,
    age: Number.isFinite(age) && age > 0 ? age : 18,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (email) {
    profile.email = email;
  }
  if (role === "customer") {
    Object.assign(profile, await getSignupPromoFields());
  }

  try {
    await db.collection("users").doc(userRecord.uid).set(profile);
  } catch (error) {
    await admin.auth().deleteUser(userRecord.uid).catch(() => {});
    functions.logger.error("registerWithPhonePassword profile create failed", {
      uid: userRecord.uid,
      phoneKey,
      message: error.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Could not save account profile. Try again.",
    );
  }

  return { ok: true, uid: userRecord.uid };
}

exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  const targetUserId = String(data.userId || "").trim();
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

  const db = admin.firestore();

  if (targetUserId.startsWith("fake_")) {
    await assertAdminPermission(context, "allDrivers");
    const fakeDriver = await db.collection("drivers").doc(targetUserId).get();
    if (!fakeDriver.exists) {
      throw new functions.https.HttpsError("not-found", "Driver not found.");
    }
    if ((fakeDriver.data()?.isFakeDriver || false) !== true) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Only test drivers can be deleted this way.",
      );
    }
    await deleteDriverFirestoreData(targetUserId);
    return { ok: true, deletedAuth: false };
  }

  const targetDoc = await db.collection("users").doc(targetUserId).get();
  if (!targetDoc.exists || !targetDoc.data()) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }

  const role = String(targetDoc.data().role || "");
  if (role === "manager" || role === "assistant") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Manager and assistant accounts cannot be deleted here.",
    );
  }

  if (role === "customer") {
    await assertAdminPermission(context, "customers");
  } else if (role === "driver") {
    await assertAdminPermission(context, "allDrivers");
  } else {
    throw new functions.https.HttpsError("failed-precondition", "Unsupported account type.");
  }

  const phone = String(targetDoc.data().phone || "").trim();

  try {
    await admin.auth().deleteUser(targetUserId);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      functions.logger.error("Auth delete failed", { targetUserId, error: error.message });
      throw new functions.https.HttpsError(
        "internal",
        "Could not delete login account. Try again.",
      );
    }
  }

  if (phone) {
    try {
      await deleteAuthUserForPhone(phone);
    } catch (error) {
      functions.logger.warn("Auth delete by phone failed", {
        phone,
        message: error.message,
      });
    }
  }

  await deleteCollection(db.collection("users").doc(targetUserId).collection("saved_places"));

  const driverDoc = await db.collection("drivers").doc(targetUserId).get();
  if (driverDoc.exists) {
    await deleteDriverFirestoreData(targetUserId);
  }

  await db.collection("users").doc(targetUserId).delete();

  if (phone) {
    const phoneKey = phone.replace(/\D/g, "");
    await db.collection("released_phones").doc(phoneKey).set({
      phone,
      previousUid: targetUserId,
      releasedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { ok: true, deletedAuth: true };
});
