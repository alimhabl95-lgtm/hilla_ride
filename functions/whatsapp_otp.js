const crypto = require("crypto");
const path = require("path");
const twilio = require("twilio");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

require("dotenv").config({ path: path.join(__dirname, ".env") });

const VERIFY_TOKEN_TTL_MS = 15 * 60 * 1000;
const VERIFY_CHANNEL = String(process.env.TWILIO_VERIFY_CHANNEL || "sms").trim() || "sms";
const VERIFY_CODE_TTL_SECONDS = 10 * 60;
const MAX_VERIFY_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60 * 1000;
const VALID_PURPOSES = new Set(["signup", "reset_password"]);
const lastSentAtByPhoneKey = new Map();
const verifyAttemptsByPhoneKey = new Map();

function parseCallablePayload(data) {
  if (data && typeof data === "object" && data.data && typeof data.data === "object") {
    return data.data;
  }
  return data && typeof data === "object" ? data : {};
}

function phoneKeyFromE164(phone) {
  return String(phone || "").replace(/\D/g, "");
}

function getAuthTokenForSigning() {
  const runtimeConfig = loadRuntimeTwilioConfig();
  const authToken = pickTwilioValue(
    process.env.TWILIO_AUTH_TOKEN,
    runtimeConfig.auth_token,
  );
  if (!authToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SMS verification is not configured on the server.",
    );
  }
  return authToken;
}

function getOtpSecret() {
  const authToken = getAuthTokenForSigning();
  const project =
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "hello-tiktok-57dc5";
  return crypto
    .createHash("sha256")
    .update(`otp-v1:${project}:${authToken}`)
    .digest("hex");
}

function createVerificationToken(phoneKey, purpose) {
  const exp = Date.now() + VERIFY_TOKEN_TTL_MS;
  const nonce = crypto.randomBytes(12).toString("hex");
  const sig = crypto
    .createHmac("sha256", getOtpSecret())
    .update(`verify:${phoneKey}:${purpose}:${exp}:${nonce}`)
    .digest("hex");
  return `${exp}.${nonce}.${sig}`;
}

function parseVerificationToken(phoneKey, purpose, verificationToken) {
  const parts = String(verificationToken || "").split(".");
  if (parts.length !== 3) {
    return false;
  }

  const [expStr, nonce, sig] = parts;
  const exp = Number(expStr);
  if (!Number.isFinite(exp) || exp < Date.now()) {
    return false;
  }

  const expected = crypto
    .createHmac("sha256", getOtpSecret())
    .update(`verify:${phoneKey}:${purpose}:${exp}:${nonce}`)
    .digest("hex");
  return expected === sig;
}

function assertResendCooldown(phoneKey) {
  const lastSentMs = lastSentAtByPhoneKey.get(phoneKey) || 0;
  if (lastSentMs > 0 && Date.now() - lastSentMs < RESEND_COOLDOWN_MS) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Please wait before requesting another code.",
    );
  }
}

function markOtpSent(phoneKey) {
  lastSentAtByPhoneKey.set(phoneKey, Date.now());
  verifyAttemptsByPhoneKey.delete(phoneKey);
}

function loadRuntimeTwilioConfig() {
  try {
    return functions.config().twilio || {};
  } catch (error) {
    functions.logger.warn("functions.config() unavailable", { error: error.message });
    return {};
  }
}

let cachedTwilioConfig = null;

function pickTwilioValue(envValue, configValue) {
  const env = String(envValue || "").trim();
  if (env) return env;
  return String(configValue || "").trim();
}

function getTwilioConfig() {
  if (cachedTwilioConfig) {
    return cachedTwilioConfig;
  }

  const runtimeConfig = loadRuntimeTwilioConfig();
  const accountSid = pickTwilioValue(
    process.env.TWILIO_ACCOUNT_SID,
    runtimeConfig.account_sid,
  );
  const authToken = pickTwilioValue(
    process.env.TWILIO_AUTH_TOKEN,
    runtimeConfig.auth_token,
  );
  const verifyServiceSid = pickTwilioValue(
    process.env.TWILIO_VERIFY_SERVICE_SID,
    runtimeConfig.verify_service_sid,
  );

  if (!accountSid || !authToken || !verifyServiceSid) {
    functions.logger.error("Twilio Verify config missing", {
      hasAccountSid: Boolean(accountSid),
      hasAuthToken: Boolean(authToken),
      hasVerifyServiceSid: Boolean(verifyServiceSid),
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SMS verification is not configured on the server.",
    );
  }

  cachedTwilioConfig = { accountSid, authToken, verifyServiceSid };
  functions.logger.info("Twilio Verify config loaded", {
    accountSidSuffix: accountSid.slice(-4),
    verifyServiceSidSuffix: verifyServiceSid.slice(-4),
    source: String(process.env.TWILIO_ACCOUNT_SID || "").trim()
      ? "env"
      : "functions.config",
  });
  return cachedTwilioConfig;
}

function twilioClient() {
  const { accountSid, authToken } = getTwilioConfig();
  return twilio(accountSid, authToken);
}

function twilioVerifyErrorMessage(error, action) {
  const code = Number(error?.code || error?.status || 0);
  const message = String(
    error?.message || error?.moreInfo || error?.detail || "",
  ).trim();
  const verb = action === "verify" ? "verify" : "send";

  if (code === 20003) {
    return "SMS service credentials are invalid. Contact support.";
  }
  if (code === 20404) {
    return "Verification code expired or not found. Tap Resend code and try again.";
  }
  if (code === 60200) {
    return "This phone number is not valid for SMS.";
  }
  if (code === 60202) {
    return "Too many incorrect attempts. Request a new code.";
  }
  if (code === 60203) {
    return "Too many code requests. Please wait before trying again.";
  }
  if (code === 60212) {
    return "Too many requests for this number. Try again later.";
  }
  if (/phone calls not allowed/i.test(message)) {
    return "Voice verification is not enabled for this country in Twilio. Use SMS instead.";
  }
  if (message) {
    return `Could not send verification code: ${message}`;
  }
  if (code) {
    return `Could not send verification code (Twilio error ${code}). Try again.`;
  }
  return action === "verify"
    ? "Incorrect verification code."
    : "Could not send verification code. Try again.";
}

async function startPhoneVerification(phoneE164) {
  const { verifyServiceSid } = getTwilioConfig();
  const client = twilioClient();

  functions.logger.info("Starting phone verification", {
    phoneKey: phoneKeyFromE164(phoneE164),
    verifyServiceSidSuffix: verifyServiceSid.slice(-4),
    channel: VERIFY_CHANNEL,
  });

  const result = await client.verify.v2
    .services(verifyServiceSid)
    .verifications.create({
      to: phoneE164,
      channel: VERIFY_CHANNEL,
    });

  functions.logger.info("Phone verification started", {
    sid: result.sid,
    status: result.status,
    channel: VERIFY_CHANNEL,
  });

  return result;
}

async function checkPhoneVerification(phoneE164, code) {
  const { verifyServiceSid } = getTwilioConfig();
  const client = twilioClient();
  const trimmedCode = String(code || "").trim();

  functions.logger.info("Checking phone verification", {
    phoneKey: phoneKeyFromE164(phoneE164),
    verifyServiceSidSuffix: verifyServiceSid.slice(-4),
  });

  const result = await client.verify.v2
    .services(verifyServiceSid)
    .verificationChecks.create({
      to: phoneE164,
      code: trimmedCode,
    });

  functions.logger.info("Phone verification checked", {
    sid: result.sid,
    status: result.status,
    to: result.to,
  });

  return result.status === "approved";
}

function assertValidVerification(phoneKey, purpose, verificationToken) {
  if (!parseVerificationToken(phoneKey, purpose, verificationToken)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Phone verification required.",
    );
  }
}

async function consumeVerification() {
  // Verification tokens are stateless and expire on their own.
}

async function getSignupPromoFields() {
  try {
    const promoDoc = await admin.firestore().collection("config").doc("promo_FREE3").get();
    if (!promoDoc.exists) return {};
    const data = promoDoc.data() || {};
    if (data.enabled !== true || data.autoAssignOnSignup !== true) return {};
    return {
      promoCode: data.code || "FREE3",
      promoRidesUsed: 0,
      promoRidesLimit: Number(data.maxRides || 0),
    };
  } catch (_) {
    return {};
  }
}

function authEmailFromPhoneKey(phoneKey) {
  return `${phoneKey}@hello-tiktok.app`;
}

async function authUserExistsForPhone(phone) {
  const phoneKey = phoneKeyFromE164(phone);
  try {
    await admin.auth().getUserByEmail(authEmailFromPhoneKey(phoneKey));
    return true;
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return false;
    }
    functions.logger.error("authUserExistsForPhone failed", {
      code: error.code,
      message: error.message,
    });
    return false;
  }
}

async function resolveAuthUidForPhone(phone) {
  const phoneKey = phoneKeyFromE164(phone);
  try {
    const userRecord = await admin.auth().getUserByEmail(authEmailFromPhoneKey(phoneKey));
    return userRecord.uid;
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return null;
    }
    throw error;
  }
}

function createSendWhatsAppOtp(normalizePhone) {
  return functions.https.onCall(async (data) => {
    try {
      const payload = parseCallablePayload(data);
      const phone = normalizePhone(String(payload.phone || "").trim());
      const purpose = String(payload.purpose || "").trim();
      if (!phone || phone === "+964") {
        throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
      }
      if (!VALID_PURPOSES.has(purpose)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid verification purpose.");
      }

      const phoneKey = phoneKeyFromE164(phone);
      const accountExists = await authUserExistsForPhone(phone);

      if (purpose === "signup" && accountExists) {
        try {
          const released = await admin
            .firestore()
            .collection("released_phones")
            .doc(phoneKey)
            .get();
          if (!released.exists) {
            throw new functions.https.HttpsError(
              "already-exists",
              "An account with this phone number already exists.",
            );
          }
        } catch (error) {
          if (error instanceof functions.https.HttpsError) {
            throw error;
          }
          functions.logger.warn("released_phones lookup failed", {
            phoneKey,
            message: error.message,
          });
        }
      }

      if (purpose === "reset_password" && !accountExists) {
        throw new functions.https.HttpsError(
          "not-found",
          "No account found for this phone number.",
        );
      }

      assertResendCooldown(phoneKey);

      try {
        await startPhoneVerification(phone);
      } catch (error) {
        if (error instanceof functions.https.HttpsError) {
          throw error;
        }
        cachedTwilioConfig = null;
        functions.logger.error("Twilio Verify send failed", {
          phoneKey,
          purpose,
          code: error?.code,
          status: error?.status,
          message: error?.message,
          moreInfo: error?.moreInfo,
        });
        throw new functions.https.HttpsError(
          "failed-precondition",
          twilioVerifyErrorMessage(error, "send"),
        );
      }

      markOtpSent(phoneKey);

      return { ok: true, expiresInSeconds: VERIFY_CODE_TTL_SECONDS };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      functions.logger.error("sendWhatsAppOtp unexpected failure", {
        error: error.message,
        code: error.code,
        name: error.name,
        stack: error.stack,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        error.message
          ? `Could not place verification call: ${error.message}`
          : "Could not place verification call. Try again.",
      );
    }
  });
}

function createSendWhatsAppOtpDebug(normalizePhone) {
  return functions.https.onCall(async (data) => {
    const steps = [];
    try {
      const payload = parseCallablePayload(data);
      const phone = normalizePhone(String(payload.phone || "").trim());
      const purpose = String(payload.purpose || "signup").trim();
      steps.push({ step: "normalize", phone, purpose });

      const phoneKey = phoneKeyFromE164(phone);
      const accountExists = await authUserExistsForPhone(phone);
      steps.push({ step: "authLookup", accountExists });

      const { accountSid, verifyServiceSid } = getTwilioConfig();
      steps.push({
        step: "twilioConfig",
        accountSidSuffix: accountSid.slice(-4),
        verifyServiceSidSuffix: verifyServiceSid.slice(-4),
        channel: VERIFY_CHANNEL,
      });

      const result = await startPhoneVerification(phone);
      steps.push({
        step: "twilioVerifySend",
        ok: true,
        status: result.status,
        sid: result.sid,
      });

      return { ok: true, steps };
    } catch (error) {
      steps.push({
        step: "error",
        name: error?.name,
        code: error?.code,
        message: error?.message,
      });
      return { ok: false, steps };
    }
  });
}

function createVerifyWhatsAppOtp(normalizePhone) {
  return functions.https.onCall(async (data) => {
    const payload = parseCallablePayload(data);
    const phone = normalizePhone(String(payload.phone || "").trim());
    const purpose = String(payload.purpose || "").trim();
    const code = String(payload.code || "").trim();
    if (!phone || !code) {
      throw new functions.https.HttpsError("invalid-argument", "Phone and code are required.");
    }
    if (!VALID_PURPOSES.has(purpose)) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid verification purpose.");
    }
    if (!/^\d{4,8}$/.test(code)) {
      throw new functions.https.HttpsError("invalid-argument", "Incorrect verification code.");
    }

    const phoneKey = phoneKeyFromE164(phone);
    const attempts = Number(verifyAttemptsByPhoneKey.get(phoneKey) || 0) + 1;
    if (attempts > MAX_VERIFY_ATTEMPTS) {
      verifyAttemptsByPhoneKey.delete(phoneKey);
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many attempts. Request a new code.",
      );
    }

    let approved = false;
    try {
      approved = await checkPhoneVerification(phone, code);
    } catch (error) {
      cachedTwilioConfig = null;
      functions.logger.error("Twilio Verify check failed", {
        phoneKey,
        purpose,
        code: error?.code,
        message: error?.message,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        twilioVerifyErrorMessage(error, "verify"),
      );
    }

    if (!approved) {
      verifyAttemptsByPhoneKey.set(phoneKey, attempts);
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Incorrect verification code. Request a new code if this keeps failing.",
      );
    }

    verifyAttemptsByPhoneKey.delete(phoneKey);
    const verificationToken = createVerificationToken(phoneKey, purpose);

    return { ok: true, verificationToken };
  });
}

async function runSignUpWithVerifiedPhone(normalizePhone, data, auth) {
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const payload = parseCallablePayload(data);
  const phone = normalizePhone(String(payload.phone || "").trim());
  const fullName = String(payload.fullName || "").trim();
  const role = String(payload.role || "customer").trim();
  const email = String(payload.email || "").trim();
  const verificationToken = String(payload.verificationToken || "").trim();

  if (!phone || !fullName || !verificationToken) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Phone, name, and verification are required.",
    );
  }
  if (!["customer", "driver"].includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid account role.");
  }

  const phoneKey = phoneKeyFromE164(phone);
  assertValidVerification(phoneKey, "signup", verificationToken);

  const expectedEmail = authEmailFromPhoneKey(phoneKey);
  const authEmail = String(auth.token?.email || "").trim().toLowerCase();
  if (authEmail !== expectedEmail.toLowerCase()) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Verified phone does not match the signed-in account.",
    );
  }

  const userRef = admin.firestore().collection("users").doc(auth.uid);
  const existingProfile = await userRef.get();
  if (existingProfile.exists) {
    throw new functions.https.HttpsError(
      "already-exists",
      "An account with this phone number already exists.",
    );
  }

  const profile = {
    phone,
    role,
    name: fullName,
    age: Number(payload.age || 18),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (email) profile.email = email;
  if (role === "customer") {
    Object.assign(profile, await getSignupPromoFields());
  }

  try {
    await userRef.set(profile);
  } catch (error) {
    functions.logger.error("Firestore profile create failed", {
      uid: auth.uid,
      phoneKey,
      message: error?.message,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Could not save account profile. Try again.",
    );
  }

  await consumeVerification(phoneKey);
  return { ok: true, uid: auth.uid };
}

function createSignUpWithVerifiedPhone(normalizePhone) {
  return functions.https.onCall(async (data, context) =>
    runSignUpWithVerifiedPhone(normalizePhone, data, context.auth),
  );
}

function createResetPasswordByPhoneVerified(normalizePhone) {
  return functions.https.onCall(async (data) => {
    const payload = parseCallablePayload(data);
    const phone = normalizePhone(String(payload.phone || "").trim());
    const newPassword = String(payload.newPassword || "");
    const verificationToken = String(payload.verificationToken || "").trim();

    if (!phone || !newPassword) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Phone and new password are required.",
      );
    }
    if (newPassword.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Password must be at least 6 characters.",
      );
    }

    const phoneKey = phoneKeyFromE164(phone);
    if (verificationToken) {
      assertValidVerification(phoneKey, "reset_password", verificationToken);
    }

    const uid = await resolveAuthUidForPhone(phone);
    if (!uid) {
      throw new functions.https.HttpsError("not-found", "No account found for this phone number.");
    }

    try {
      await admin.auth().updateUser(uid, { password: newPassword });
    } catch (_) {
      throw new functions.https.HttpsError("internal", "Could not reset password.");
    }

    await consumeVerification(phoneKey);
    return { ok: true };
  });
}

module.exports = {
  createSendWhatsAppOtp,
  createVerifyWhatsAppOtp,
  createSignUpWithVerifiedPhone,
  runSignUpWithVerifiedPhone,
  createResetPasswordByPhoneVerified,
  createSendWhatsAppOtpDebug,
};
