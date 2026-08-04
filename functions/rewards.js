/**
 * Driver Rewards & Incentives — campaign CRUD, progress, auto-credit, audit.
 * Wired from functions/index.js with applyWalletDelta + sendToToken.
 */

const CONDITION_TYPES = new Set([
  "completedTrips",
  "totalEarnings",
  "onlineHours",
  "rating",
  "acceptanceRate",
  "cancellationRate",
  "custom",
]);

const REWARD_TYPES = new Set([
  "wallet_credit",
  "bonus",
  "commission_discount",
  "free_trips",
  "custom",
]);

const CAMPAIGN_STATUSES = new Set([
  "draft",
  "active",
  "paused",
  "ended",
  "deleted",
]);

const OPS = new Set(["gte", "gt", "lte", "lt", "eq"]);

function progressDocId(campaignId, driverId) {
  return `${campaignId}_${driverId}`;
}

function toNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function compare(op, actual, expected) {
  switch (op) {
    case "gt":
      return actual > expected;
    case "lte":
      return actual <= expected;
    case "lt":
      return actual < expected;
    case "eq":
      return actual === expected;
    case "gte":
    default:
      return actual >= expected;
  }
}

function sanitizeCondition(raw) {
  const type = String(raw?.type || "").trim();
  if (!CONDITION_TYPES.has(type)) {
    throw new Error(`Invalid condition type: ${type}`);
  }
  const op = OPS.has(String(raw?.op || "").trim())
    ? String(raw.op).trim()
    : "gte";
  const value = toNumber(raw?.value, 0);
  const scope = ["lifetime", "campaign", "monthly"].includes(raw?.scope)
    ? raw.scope
    : "campaign";
  const customKey = String(raw?.customKey || raw?.key || "").trim();
  if (type === "custom" && !customKey) {
    throw new Error("custom condition requires customKey");
  }
  return {
    type,
    op,
    value,
    scope,
    customKey: type === "custom" ? customKey : "",
  };
}

function sanitizeReward(raw) {
  const type = String(raw?.type || "wallet_credit").trim();
  if (!REWARD_TYPES.has(type)) {
    throw new Error(`Invalid reward type: ${type}`);
  }
  const amountIqd = Math.max(0, Math.trunc(toNumber(raw?.amountIqd, 0)));
  const commissionDiscountPercent = Math.min(
    100,
    Math.max(0, toNumber(raw?.commissionDiscountPercent, 0)),
  );
  const freeTripsCount = Math.max(0, Math.trunc(toNumber(raw?.freeTripsCount, 0)));
  const durationDays = Math.max(0, Math.trunc(toNumber(raw?.durationDays, 0)));
  if (
    (type === "wallet_credit" || type === "bonus") &&
    amountIqd <= 0
  ) {
    throw new Error("Wallet/bonus reward requires amountIqd > 0");
  }
  if (type === "commission_discount" && commissionDiscountPercent <= 0) {
    throw new Error("Commission discount requires commissionDiscountPercent > 0");
  }
  if (type === "free_trips" && freeTripsCount <= 0) {
    throw new Error("Free trips reward requires freeTripsCount > 0");
  }
  return {
    type,
    amountIqd,
    commissionDiscountPercent,
    freeTripsCount,
    durationDays,
    customPayload:
      raw?.customPayload && typeof raw.customPayload === "object"
        ? raw.customPayload
        : {},
  };
}

function sanitizeCampaignPayload(data, { isCreate }) {
  const titleEn = String(data.titleEn || "").trim();
  const titleAr = String(data.titleAr || "").trim();
  if (!titleEn && !titleAr) {
    throw new Error("Campaign title is required");
  }
  const status = String(data.status || (isCreate ? "draft" : "draft")).trim();
  if (!CAMPAIGN_STATUSES.has(status)) {
    throw new Error("Invalid campaign status");
  }
  const conditions = Array.isArray(data.conditions)
    ? data.conditions.map(sanitizeCondition)
    : [];
  if (conditions.length === 0) {
    throw new Error("At least one condition is required");
  }
  const reward = sanitizeReward(data.reward || {});
  const conditionLogic =
    String(data.conditionLogic || "and").toLowerCase() === "or" ? "or" : "and";
  const maxGrantsPerDriver = Math.max(
    1,
    Math.trunc(toNumber(data.maxGrantsPerDriver, 1)),
  );
  const maxTotalGrantsRaw = data.maxTotalGrants;
  const maxTotalGrants =
    maxTotalGrantsRaw === null ||
    maxTotalGrantsRaw === undefined ||
    String(maxTotalGrantsRaw).trim() === ""
      ? null
      : Math.max(1, Math.trunc(toNumber(maxTotalGrantsRaw, 1)));
  const cooldownHours = Math.max(0, Math.trunc(toNumber(data.cooldownHours, 0)));

  let startAt = null;
  let endAt = null;
  if (data.startAt) {
    const d = new Date(data.startAt);
    if (!Number.isNaN(d.getTime())) startAt = d;
  }
  if (data.endAt) {
    const d = new Date(data.endAt);
    if (!Number.isNaN(d.getTime())) endAt = d;
  }

  return {
    titleEn: titleEn || titleAr,
    titleAr: titleAr || titleEn,
    descriptionEn: String(data.descriptionEn || "").trim(),
    descriptionAr: String(data.descriptionAr || "").trim(),
    status,
    conditionLogic,
    conditions,
    reward,
    maxGrantsPerDriver,
    maxTotalGrants,
    cooldownHours,
    startAt,
    endAt,
    priority: Math.trunc(toNumber(data.priority, 0)),
    notifyOnGrant: data.notifyOnGrant !== false,
  };
}

function campaignIsLive(campaign, now = new Date()) {
  if (!campaign || campaign.status !== "active") return false;
  if (campaign.startAt) {
    const start =
      typeof campaign.startAt.toDate === "function"
        ? campaign.startAt.toDate()
        : new Date(campaign.startAt);
    if (start && !Number.isNaN(start.getTime()) && now < start) return false;
  }
  if (campaign.endAt) {
    const end =
      typeof campaign.endAt.toDate === "function"
        ? campaign.endAt.toDate()
        : new Date(campaign.endAt);
    if (end && !Number.isNaN(end.getTime()) && now > end) return false;
  }
  return true;
}

function acceptanceRate(driver) {
  const received = toNumber(driver.statsOffersReceived, 0);
  const accepted = toNumber(driver.statsOffersAccepted, 0);
  if (received <= 0) return 100;
  return (accepted / received) * 100;
}

function cancellationRate(driver) {
  const completed = toNumber(driver.completedRidesCount, 0);
  const cancelled = toNumber(driver.cancelledRidesCount, 0);
  const total = completed + cancelled;
  if (total <= 0) return 0;
  return (cancelled / total) * 100;
}

function metricForCondition(condition, { driver, progress }) {
  const scope = condition.scope || "campaign";
  switch (condition.type) {
    case "completedTrips":
      if (scope === "lifetime") return toNumber(driver.completedRidesCount, 0);
      if (scope === "monthly") return toNumber(driver.monthlyRideCount, 0);
      return toNumber(progress.completedTrips, 0);
    case "totalEarnings":
      if (scope === "lifetime") return toNumber(driver.totalDriverEarningsIqd, 0);
      return toNumber(progress.totalEarningsIqd, 0);
    case "onlineHours":
      if (scope === "lifetime") {
        return toNumber(driver.onlineSecondsTotal, 0) / 3600;
      }
      return toNumber(progress.onlineSeconds, 0) / 3600;
    case "rating":
      return toNumber(driver.rating, 0);
    case "acceptanceRate":
      return acceptanceRate(driver);
    case "cancellationRate":
      return cancellationRate(driver);
    case "custom": {
      const key = condition.customKey;
      if (!key) return 0;
      if (Object.prototype.hasOwnProperty.call(progress, key)) {
        return toNumber(progress[key], 0);
      }
      return toNumber(driver[key], 0);
    }
    default:
      return 0;
  }
}

function conditionsMet(campaign, ctx) {
  const conditions = Array.isArray(campaign.conditions) ? campaign.conditions : [];
  if (conditions.length === 0) return false;
  const results = conditions.map((c) => {
    const actual = metricForCondition(c, ctx);
    return compare(c.op || "gte", actual, toNumber(c.value, 0));
  });
  if (campaign.conditionLogic === "or") {
    return results.some(Boolean);
  }
  return results.every(Boolean);
}

function createRewardsModule({
  admin,
  functions,
  applyWalletDelta,
  sendToToken,
  assertAdminPermissionAny,
}) {
  const db = () => admin.firestore();

  async function writeAudit({
    action,
    actorUid,
    campaignId = "",
    driverId = "",
    grantId = "",
    details = {},
  }) {
    await db().collection("rewardAuditLogs").add({
      action,
      actorUid: actorUid || "system",
      campaignId: campaignId || null,
      driverId: driverId || null,
      grantId: grantId || null,
      details,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  async function loadActiveCampaigns() {
    const snap = await db()
      .collection("rewardCampaigns")
      .where("status", "==", "active")
      .limit(100)
      .get();
    return snap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((c) => campaignIsLive(c));
  }

  async function getOrCreateProgress(tx, campaignId, driverId) {
    const ref = db()
      .collection("rewardProgress")
      .doc(progressDocId(campaignId, driverId));
    const snap = await tx.get(ref);
    if (snap.exists) {
      return { ref, data: snap.data() || {} };
    }
    const data = {
      campaignId,
      driverId,
      completedTrips: 0,
      totalEarningsIqd: 0,
      onlineSeconds: 0,
      grantsCount: 0,
      lastGrantAt: null,
      lastEvaluatedAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    tx.set(ref, data);
    return { ref, data };
  }

  async function applyNonWalletReward({
    driverId,
    campaign,
    grantId,
  }) {
    const reward = campaign.reward || {};
    const type = reward.type;
    const activeRef = db()
      .collection("drivers")
      .doc(driverId)
      .collection("activeRewards")
      .doc(grantId);
    const now = Date.now();
    const durationMs =
      Math.max(0, Math.trunc(toNumber(reward.durationDays, 0))) *
      24 *
      60 *
      60 *
      1000;
    const expiresAt =
      durationMs > 0
        ? admin.firestore.Timestamp.fromMillis(now + durationMs)
        : null;

    if (type === "commission_discount") {
      await activeRef.set({
        campaignId: campaign.id,
        grantId,
        type,
        commissionDiscountPercent: toNumber(reward.commissionDiscountPercent, 0),
        remainingUses: null,
        expiresAt,
        status: "active",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }
    if (type === "free_trips") {
      await activeRef.set({
        campaignId: campaign.id,
        grantId,
        type,
        freeTripsRemaining: Math.trunc(toNumber(reward.freeTripsCount, 0)),
        expiresAt,
        status: "active",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }
    if (type === "custom") {
      await activeRef.set({
        campaignId: campaign.id,
        grantId,
        type,
        customPayload: reward.customPayload || {},
        expiresAt,
        status: "active",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  async function grantReward({
    campaign,
    driverId,
    progressRef,
    progressData,
    actorUid = "system",
    trigger = "auto",
  }) {
    const reward = campaign.reward || {};
    const grantsCount = toNumber(progressData.grantsCount, 0);
    const maxPerDriver = Math.max(1, toNumber(campaign.maxGrantsPerDriver, 1));
    if (grantsCount >= maxPerDriver) {
      return { granted: false, reason: "max_per_driver" };
    }
    if (campaign.maxTotalGrants != null) {
      const campaignRef = db().collection("rewardCampaigns").doc(campaign.id);
      const campaignSnap = await campaignRef.get();
      const totalGranted = toNumber(campaignSnap.data()?.totalGrantedCount, 0);
      if (totalGranted >= campaign.maxTotalGrants) {
        return { granted: false, reason: "max_total" };
      }
    }
    const cooldownHours = Math.max(0, toNumber(campaign.cooldownHours, 0));
    if (cooldownHours > 0 && progressData.lastGrantAt) {
      const last =
        typeof progressData.lastGrantAt.toDate === "function"
          ? progressData.lastGrantAt.toDate()
          : new Date(progressData.lastGrantAt);
      const elapsedH = (Date.now() - last.getTime()) / (1000 * 60 * 60);
      if (elapsedH < cooldownHours) {
        return { granted: false, reason: "cooldown" };
      }
    }

    const grantRef = db().collection("rewardGrants").doc();
    const grantId = grantRef.id;
    const titleEn = campaign.titleEn || "Reward";
    const titleAr = campaign.titleAr || titleEn;
    let walletResult = null;
    const amountIqd = Math.trunc(toNumber(reward.amountIqd, 0));
    const isWallet =
      reward.type === "wallet_credit" || reward.type === "bonus";

    if (isWallet && amountIqd > 0) {
      walletResult = await applyWalletDelta({
        driverId,
        amountIqd,
        type: "reward",
        createdBy: actorUid,
        note: `Reward: ${titleEn} (${campaign.id})`,
        rewardCampaignId: campaign.id,
        rewardGrantId: grantId,
      });
    } else {
      await applyNonWalletReward({ driverId, campaign, grantId });
    }

    await grantRef.set({
      campaignId: campaign.id,
      campaignTitleEn: titleEn,
      campaignTitleAr: titleAr,
      driverId,
      rewardType: reward.type,
      amountIqd: isWallet ? amountIqd : 0,
      commissionDiscountPercent: toNumber(reward.commissionDiscountPercent, 0),
      freeTripsCount: toNumber(reward.freeTripsCount, 0),
      customPayload: reward.customPayload || {},
      walletBalanceAfterIqd: walletResult?.balanceAfterIqd ?? null,
      trigger,
      createdBy: actorUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await progressRef.set(
      {
        grantsCount: grantsCount + 1,
        lastGrantAt: admin.firestore.FieldValue.serverTimestamp(),
        lastGrantId: grantId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await db()
      .collection("rewardCampaigns")
      .doc(campaign.id)
      .set(
        {
          totalGrantedCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    await writeAudit({
      action: "reward_granted",
      actorUid,
      campaignId: campaign.id,
      driverId,
      grantId,
      details: {
        rewardType: reward.type,
        amountIqd: isWallet ? amountIqd : 0,
        trigger,
      },
    });

    if (campaign.notifyOnGrant !== false) {
      try {
        const userSnap = await db().collection("users").doc(driverId).get();
        const driverSnap = await db().collection("drivers").doc(driverId).get();
        const token =
          userSnap.data()?.fcmToken || driverSnap.data()?.fcmToken || null;
        const bodyEn =
          isWallet && amountIqd > 0
            ? `You earned ${amountIqd} IQD: ${titleEn}`
            : `You unlocked a reward: ${titleEn}`;
        const bodyAr =
          isWallet && amountIqd > 0
            ? `حصلت على ${amountIqd} د.ع: ${titleAr}`
            : `فتحت مكافأة: ${titleAr}`;
        await sendToToken(
          token,
          "Reward unlocked",
          bodyEn,
          {
            type: "driver_reward_credited",
            campaignId: campaign.id,
            grantId,
            amountIqd: String(isWallet ? amountIqd : 0),
            titleAr,
            bodyAr,
          },
          "default",
        );
      } catch (error) {
        functions.logger.warn("reward notify failed", {
          driverId,
          campaignId: campaign.id,
          message: error.message,
        });
      }
    }

    return { granted: true, grantId, walletResult };
  }

  async function evaluateDriverCampaigns(driverId, {
    tripIncrement = false,
    tripEarningsIqd = 0,
    onlineSecondsDelta = 0,
    actorUid = "system",
    trigger = "auto",
  } = {}) {
    const driverSnap = await db().collection("drivers").doc(driverId).get();
    if (!driverSnap.exists) return { evaluated: 0, granted: 0 };
    const driver = driverSnap.data() || {};
    if (driver.isFakeDriver === true) return { evaluated: 0, granted: 0 };

    const campaigns = await loadActiveCampaigns();
    let granted = 0;
    for (const campaign of campaigns) {
      const progressRef = db()
        .collection("rewardProgress")
        .doc(progressDocId(campaign.id, driverId));

      await db().runTransaction(async (tx) => {
        const snap = await tx.get(progressRef);
        const data = snap.exists
          ? snap.data() || {}
          : {
              campaignId: campaign.id,
              driverId,
              completedTrips: 0,
              totalEarningsIqd: 0,
              onlineSeconds: 0,
              grantsCount: 0,
            };
        const next = {
          ...data,
          campaignId: campaign.id,
          driverId,
          completedTrips:
            toNumber(data.completedTrips, 0) + (tripIncrement ? 1 : 0),
          totalEarningsIqd:
            toNumber(data.totalEarningsIqd, 0) +
            (tripIncrement ? Math.max(0, Math.trunc(tripEarningsIqd)) : 0),
          onlineSeconds:
            toNumber(data.onlineSeconds, 0) + Math.max(0, onlineSecondsDelta),
          lastEvaluatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (!snap.exists) {
          next.createdAt = admin.firestore.FieldValue.serverTimestamp();
        }
        tx.set(progressRef, next, { merge: true });
      });

      const progressSnap = await progressRef.get();
      const progress = progressSnap.data() || {};
      if (!conditionsMet(campaign, { driver, progress })) {
        continue;
      }
      const result = await grantReward({
        campaign,
        driverId,
        progressRef,
        progressData: progress,
        actorUid,
        trigger,
      });
      if (result.granted) granted += 1;
    }
    return { evaluated: campaigns.length, granted };
  }

  /**
   * Apply free-trip / commission-discount before wallet debit.
   * Returns { commissionIqd, freeTripUsed, discountPercent, activeRewardId }.
   */
  async function resolveEffectiveCommission(driverId, baseCommissionIqd) {
    const base = Math.max(0, Math.trunc(toNumber(baseCommissionIqd, 0)));
    if (base <= 0) {
      return {
        commissionIqd: 0,
        freeTripUsed: false,
        discountPercent: 0,
        activeRewardId: null,
      };
    }
    const now = admin.firestore.Timestamp.now();
    const snap = await db()
      .collection("drivers")
      .doc(driverId)
      .collection("activeRewards")
      .where("status", "==", "active")
      .limit(40)
      .get();

    let bestFree = null;
    let bestDiscount = null;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (data.expiresAt && data.expiresAt.toMillis && data.expiresAt.toMillis() < now.toMillis()) {
        await doc.ref.set({ status: "expired" }, { merge: true });
        continue;
      }
      if (data.type === "free_trips" && toNumber(data.freeTripsRemaining, 0) > 0) {
        if (!bestFree) bestFree = { id: doc.id, ref: doc.ref, data };
      }
      if (
        data.type === "commission_discount" &&
        toNumber(data.commissionDiscountPercent, 0) > 0
      ) {
        const pct = toNumber(data.commissionDiscountPercent, 0);
        if (!bestDiscount || pct > toNumber(bestDiscount.data.commissionDiscountPercent, 0)) {
          bestDiscount = { id: doc.id, ref: doc.ref, data };
        }
      }
    }

    if (bestFree) {
      const remaining = toNumber(bestFree.data.freeTripsRemaining, 0) - 1;
      await bestFree.ref.set(
        {
          freeTripsRemaining: Math.max(0, remaining),
          status: remaining <= 0 ? "consumed" : "active",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        commissionIqd: 0,
        freeTripUsed: true,
        discountPercent: 100,
        activeRewardId: bestFree.id,
      };
    }

    if (bestDiscount) {
      const pct = Math.min(
        100,
        toNumber(bestDiscount.data.commissionDiscountPercent, 0),
      );
      const commissionIqd = Math.trunc(base * (1 - pct / 100));
      return {
        commissionIqd,
        freeTripUsed: false,
        discountPercent: pct,
        activeRewardId: bestDiscount.id,
      };
    }

    return {
      commissionIqd: base,
      freeTripUsed: false,
      discountPercent: 0,
      activeRewardId: null,
    };
  }

  /** Accumulate online seconds when driver goes offline or heartbeat. */
  async function accumulateOnlineSeconds(driverId, driverBefore, driverAfter) {
    const wasOnline = driverBefore?.isOnline === true;
    const isOnline = driverAfter?.isOnline === true;
    const onlineSince = driverBefore?.onlineSince;
    let delta = 0;

    if (wasOnline && onlineSince) {
      const sinceMs =
        typeof onlineSince.toMillis === "function"
          ? onlineSince.toMillis()
          : new Date(onlineSince).getTime();
      if (Number.isFinite(sinceMs)) {
        delta = Math.max(0, Math.floor((Date.now() - sinceMs) / 1000));
      }
    }

    const updates = {};
    if (isOnline && !wasOnline && !driverAfter?.onlineSince) {
      updates.onlineSince = admin.firestore.FieldValue.serverTimestamp();
    }
    if (!isOnline && wasOnline) {
      if (driverAfter?.onlineSince != null) {
        updates.onlineSince = null;
      }
      if (delta > 0) {
        updates.onlineSecondsTotal = admin.firestore.FieldValue.increment(delta);
      }
    }
    // Heartbeat while staying online: flush every ~5 minutes worth if onlineSince old
    if (wasOnline && isOnline && onlineSince && delta >= 300) {
      updates.onlineSecondsTotal = admin.firestore.FieldValue.increment(delta);
      updates.onlineSince = admin.firestore.FieldValue.serverTimestamp();
    }

    if (Object.keys(updates).length > 0) {
      await db().collection("drivers").doc(driverId).set(updates, { merge: true });
    }

    if (delta > 0 && (!isOnline || (wasOnline && isOnline && delta >= 300))) {
      try {
        await evaluateDriverCampaigns(driverId, {
          onlineSecondsDelta: delta,
          trigger: "online_hours",
        });
      } catch (error) {
        functions.logger.warn("reward online evaluate failed", {
          driverId,
          message: error.message,
        });
      }
    }
  }

  async function bumpOfferStats(driverIds, field) {
    const ids = [...new Set((driverIds || []).map(String).filter(Boolean))];
    await Promise.all(
      ids.map((id) =>
        db()
          .collection("drivers")
          .doc(id)
          .set(
            {
              [field]: admin.firestore.FieldValue.increment(1),
              statsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          ),
      ),
    );
  }

  // --- Callables ---

  const saveRewardCampaign = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["rewards", "wallet", "earnings"]);
    const idRaw = String(data.id || "").trim();
    const isCreate = !idRaw;
    let payload;
    try {
      payload = sanitizeCampaignPayload(data, { isCreate });
    } catch (error) {
      throw new functions.https.HttpsError("invalid-argument", error.message);
    }

    const ref = isCreate
      ? db().collection("rewardCampaigns").doc()
      : db().collection("rewardCampaigns").doc(idRaw);

    if (!isCreate) {
      const existing = await ref.get();
      if (!existing.exists) {
        throw new functions.https.HttpsError("not-found", "Campaign not found.");
      }
    }

    const write = {
      ...payload,
      startAt: payload.startAt
        ? admin.firestore.Timestamp.fromDate(payload.startAt)
        : null,
      endAt: payload.endAt
        ? admin.firestore.Timestamp.fromDate(payload.endAt)
        : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    };
    if (isCreate) {
      write.createdAt = admin.firestore.FieldValue.serverTimestamp();
      write.createdBy = context.auth.uid;
      write.totalGrantedCount = 0;
    }

    await ref.set(write, { merge: !isCreate });
    await writeAudit({
      action: isCreate ? "campaign_created" : "campaign_updated",
      actorUid: context.auth.uid,
      campaignId: ref.id,
      details: { status: payload.status, titleEn: payload.titleEn },
    });
    return { ok: true, id: ref.id };
  });

  const setRewardCampaignStatus = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["rewards", "wallet", "earnings"]);
    const id = String(data.id || "").trim();
    const status = String(data.status || "").trim();
    if (!id || !CAMPAIGN_STATUSES.has(status)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "id and valid status required.",
      );
    }
    const ref = db().collection("rewardCampaigns").doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Campaign not found.");
    }
    await ref.set(
      {
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
        ...(status === "deleted"
          ? { deletedAt: admin.firestore.FieldValue.serverTimestamp() }
          : {}),
      },
      { merge: true },
    );
    await writeAudit({
      action: "campaign_status_changed",
      actorUid: context.auth.uid,
      campaignId: id,
      details: { status, previous: snap.data()?.status },
    });
    return { ok: true };
  });

  const deleteRewardCampaign = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["rewards", "wallet", "earnings"]);
    const id = String(data.id || "").trim();
    if (!id) {
      throw new functions.https.HttpsError("invalid-argument", "id required.");
    }
    await db()
      .collection("rewardCampaigns")
      .doc(id)
      .set(
        {
          status: "deleted",
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: context.auth.uid,
        },
        { merge: true },
      );
    await writeAudit({
      action: "campaign_deleted",
      actorUid: context.auth.uid,
      campaignId: id,
    });
    return { ok: true };
  });

  const evaluateDriverRewards = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["rewards", "wallet", "earnings"]);
    const driverId = String(data.driverId || "").trim();
    if (!driverId) {
      throw new functions.https.HttpsError("invalid-argument", "driverId required.");
    }
    const result = await evaluateDriverCampaigns(driverId, {
      actorUid: context.auth.uid,
      trigger: "manual_admin",
    });
    return { ok: true, ...result };
  });

  return {
    saveRewardCampaign,
    setRewardCampaignStatus,
    deleteRewardCampaign,
    evaluateDriverRewards,
    evaluateDriverCampaigns,
    resolveEffectiveCommission,
    accumulateOnlineSeconds,
    bumpOfferStats,
    campaignIsLive,
  };
}

module.exports = {
  createRewardsModule,
  CONDITION_TYPES,
  REWARD_TYPES,
};
