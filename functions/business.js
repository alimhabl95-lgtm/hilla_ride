/**
 * Multi-Business Management — partners, catalog, orders.
 */

const DEFAULT_BUSINESS_TYPES = {
  restaurant: { nameEn: "Restaurant", nameAr: "مطعم", icon: "restaurant", sortOrder: 10, active: true },
  supermarket: { nameEn: "Supermarket", nameAr: "سوبر ماركت", icon: "store", sortOrder: 20, active: true },
  pharmacy: { nameEn: "Pharmacy", nameAr: "صيدلية", icon: "local_pharmacy", sortOrder: 30, active: true },
  bakery: { nameEn: "Bakery", nameAr: "مخبز", icon: "bakery_dining", sortOrder: 40, active: true },
  flower_shop: { nameEn: "Flower Shop", nameAr: "محل زهور", icon: "local_florist", sortOrder: 50, active: true },
  grocery: { nameEn: "Grocery Store", nameAr: "بقالة", icon: "shopping_basket", sortOrder: 60, active: true },
  electronics: { nameEn: "Electronics", nameAr: "إلكترونيات", icon: "devices", sortOrder: 70, active: true },
  water_delivery: { nameEn: "Water Delivery", nameAr: "توصيل ماء", icon: "water_drop", sortOrder: 75, active: true },
  gas_cylinder: { nameEn: "Gas Cylinder Delivery", nameAr: "توصيل اسطوانة غاز", icon: "propane_tank", sortOrder: 78, active: true },
  pet_shop: { nameEn: "Pet Shop", nameAr: "مستلزمات حيوانات", icon: "pets", sortOrder: 80, active: true },
  laundry: { nameEn: "Laundry", nameAr: "مغسلة", icon: "local_laundry_service", sortOrder: 90, active: true },
  courier: { nameEn: "Courier Services", nameAr: "خدمات توصيل", icon: "local_shipping", sortOrder: 100, active: true },
};

const BUSINESS_STATUSES = new Set([
  "draft",
  "pendingReview",
  "approved",
  "live",
  "rejected",
  "suspended",
  "archived",
]);

const ORDER_STATUSES = new Set([
  "pending",
  "accepted",
  "preparing",
  "ready",
  "outForDelivery",
  "delivered",
  "cancelled",
  "rejected",
]);

function createBusinessModule({
  admin,
  functions,
  assertAdminPermissionAny,
  sendToToken,
  authAdminCallable,
  writeAdminAuditLog,
}) {
  const db = () => admin.firestore();

  async function assertBusinessOwner(context, businessId) {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const userSnap = await db().collection("users").doc(context.auth.uid).get();
    const user = userSnap.data() || {};
    if (user.role === "manager") return { uid: context.auth.uid, role: "manager" };
    if (
      user.role === "assistant" &&
      Array.isArray(user.permissions) &&
      user.permissions.includes("businessPartners")
    ) {
      return { uid: context.auth.uid, role: "assistant" };
    }
    const bizSnap = await db().collection("businesses").doc(businessId).get();
    if (!bizSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Business not found.");
    }
    const biz = bizSnap.data() || {};
    if (biz.ownerUid !== context.auth.uid && user.role !== "businessOwner") {
      throw new functions.https.HttpsError("permission-denied", "Not business owner.");
    }
    if (user.role === "businessOwner" && user.businessId !== businessId) {
      throw new functions.https.HttpsError("permission-denied", "Wrong business.");
    }
    return { uid: context.auth.uid, role: user.role || "businessOwner", business: biz };
  }

  async function notifyOwner(businessId, title, body, data = {}) {
    try {
      const biz = (await db().collection("businesses").doc(businessId).get()).data() || {};
      const ownerUid = String(biz.ownerUid || "");
      if (!ownerUid) return;
      const user = (await db().collection("users").doc(ownerUid).get()).data() || {};
      await sendToToken(user.fcmToken, title, body, data, "default");
    } catch (_) {}
  }

  const seedBusinessTypes = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["businessPartners", "pricing"]);
    await db().collection("config").doc("businessTypes").set(
      {
        types: DEFAULT_BUSINESS_TYPES,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
    return { ok: true, count: Object.keys(DEFAULT_BUSINESS_TYPES).length };
  });

  const saveBusinessTypes = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["businessPartners", "pricing"]);
    const types = data.types && typeof data.types === "object" ? data.types : {};
    await db().collection("config").doc("businessTypes").set(
      {
        types,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
    return { ok: true };
  });

  const createBusinessPartner = authAdminCallable(async (data, context) => {
    await assertAdminPermissionAny(context, ["businessPartners"]);
    const nameEn = String(data.nameEn || "").trim();
    const nameAr = String(data.nameAr || "").trim() || nameEn;
    const typeId = String(data.typeId || "restaurant").trim();
    const ownerEmail = String(data.ownerEmail || "").trim().toLowerCase();
    const ownerPassword = String(data.ownerPassword || "");
    const ownerName = String(data.ownerName || "").trim() || nameEn;
    if (!nameEn || !ownerEmail || ownerPassword.length < 6) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Name, owner email, and password (6+) required.",
      );
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email: ownerEmail,
        password: ownerPassword,
        displayName: ownerName,
        emailVerified: true,
      });
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        throw new functions.https.HttpsError(
          "already-exists",
          "Owner email already registered.",
        );
      }
      throw new functions.https.HttpsError("internal", error.message);
    }

    const bizRef = db().collection("businesses").doc();
    try {
      await db().runTransaction(async (tx) => {
        tx.set(bizRef, {
          nameEn,
          nameAr,
          typeId,
          status: "approved",
          descriptionEn: "",
          descriptionAr: "",
          logoUrl: "",
          coverUrl: "",
          phone: String(data.phone || "").trim(),
          address: "",
          latitude: 0,
          longitude: 0,
          provinceId: String(data.provinceId || "").trim(),
          districtId: String(data.districtId || "").trim(),
          subDistrictId: String(data.subDistrictId || "").trim(),
          ownerUid: userRecord.uid,
          ownerEmail,
          commissionPercent: Number(data.commissionPercent) || 15,
          rating: 0,
          ratingCount: 0,
          totalOrders: 0,
          totalRevenueIqd: 0,
          hours: { alwaysOpen: true, days: {} },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: context.auth.uid,
        });
        tx.set(db().collection("users").doc(userRecord.uid), {
          email: ownerEmail,
          name: ownerName,
          role: "businessOwner",
          businessId: bizRef.id,
          phone: String(data.phone || "").trim(),
          isBlocked: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: context.auth.uid,
        });
      });
    } catch (error) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (_) {}
      throw error;
    }

    return { ok: true, businessId: bizRef.id, ownerUid: userRecord.uid };
  });

  const setBusinessStatus = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["businessPartners"]);
    const businessId = String(data.businessId || "").trim();
    const status = String(data.status || "").trim();
    const rejectionReason = String(data.rejectionReason || "").trim();
    if (!businessId || !BUSINESS_STATUSES.has(status)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "businessId and valid status required.",
      );
    }
    await db().collection("businesses").doc(businessId).set(
      {
        status,
        rejectionReason: status === "rejected" ? rejectionReason : "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
        ...(status === "live"
          ? { wentLiveAt: admin.firestore.FieldValue.serverTimestamp() }
          : {}),
      },
      { merge: true },
    );
    await notifyOwner(
      businessId,
      "Business status updated",
      `Your business is now: ${status}`,
      { type: "business_status", businessId, status },
    );
    if (typeof writeAdminAuditLog === "function") {
      await writeAdminAuditLog({
        adminId: context.auth.uid,
        action: `business.${status}`,
        entityType: "business",
        entityId: businessId,
        details: { status, rejectionReason },
      });
    }
    return { ok: true };
  });

  const saveBusinessProfile = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    await assertBusinessOwner(context, businessId);
    const payload = data.data && typeof data.data === "object" ? data.data : {};
    const allowed = [
      "nameEn",
      "nameAr",
      "descriptionEn",
      "descriptionAr",
      "logoUrl",
      "coverUrl",
      "phone",
      "address",
      "latitude",
      "longitude",
      "provinceId",
      "districtId",
      "subDistrictId",
      "hours",
      "typeId",
      // Phase-2 ready: temporary close without changing status / requiring app migration
      "temporarilyClosed",
    ];
    const update = {};
    for (const key of allowed) {
      if (payload[key] !== undefined) update[key] = payload[key];
    }
    // Admin-only commission
    const userSnap = await db().collection("users").doc(context.auth.uid).get();
    const role = userSnap.data()?.role;
    if (
      (role === "manager" || role === "assistant") &&
      payload.commissionPercent !== undefined
    ) {
      update.commissionPercent = Number(payload.commissionPercent) || 15;
    }
    update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    await db().collection("businesses").doc(businessId).set(update, { merge: true });
    return { ok: true };
  });

  const submitBusinessForReview = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    await assertBusinessOwner(context, businessId);
    const products = await db()
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .limit(1)
      .get();
    if (products.empty) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Add at least one product before submitting.",
      );
    }
    await db().collection("businesses").doc(businessId).set(
      {
        status: "pendingReview",
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { ok: true };
  });

  const deleteBusiness = functions.https.onCall(async (data, context) => {
    await assertAdminPermissionAny(context, ["businessPartners"]);
    const businessId = String(data.businessId || "").trim();
    if (!businessId) {
      throw new functions.https.HttpsError("invalid-argument", "businessId required.");
    }
    await db().collection("businesses").doc(businessId).set(
      {
        status: "archived",
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid,
      },
      { merge: true },
    );
    return { ok: true };
  });

  const saveBusinessCategory = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    await assertBusinessOwner(context, businessId);
    const payload = data.data && typeof data.data === "object" ? data.data : {};
    const categoryId = String(data.categoryId || "").trim();
    const ref = categoryId
      ? db().collection("businesses").doc(businessId).collection("categories").doc(categoryId)
      : db().collection("businesses").doc(businessId).collection("categories").doc();
    await ref.set(
      {
        nameEn: String(payload.nameEn || "").trim(),
        nameAr: String(payload.nameAr || "").trim(),
        sortOrder: Number(payload.sortOrder) || 0,
        active: payload.active !== false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(categoryId
          ? {}
          : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );
    return { ok: true, id: ref.id };
  });

  const deleteBusinessCategory = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    const categoryId = String(data.categoryId || "").trim();
    await assertBusinessOwner(context, businessId);
    await db()
      .collection("businesses")
      .doc(businessId)
      .collection("categories")
      .doc(categoryId)
      .delete();
    return { ok: true };
  });

  const saveBusinessProduct = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    await assertBusinessOwner(context, businessId);
    const payload = data.data && typeof data.data === "object" ? data.data : {};
    const productId = String(data.productId || "").trim();
    const ref = productId
      ? db().collection("businesses").doc(businessId).collection("products").doc(productId)
      : db().collection("businesses").doc(businessId).collection("products").doc();
    await ref.set(
      {
        categoryId: String(payload.categoryId || "").trim(),
        nameEn: String(payload.nameEn || "").trim(),
        nameAr: String(payload.nameAr || "").trim(),
        descriptionEn: String(payload.descriptionEn || "").trim(),
        descriptionAr: String(payload.descriptionAr || "").trim(),
        imageUrl: String(payload.imageUrl || "").trim(),
        priceIqd: Math.max(0, Math.trunc(Number(payload.priceIqd) || 0)),
        discountPercent: Math.max(0, Number(payload.discountPercent) || 0),
        available: payload.available !== false,
        prepMinutes: Math.max(0, Math.trunc(Number(payload.prepMinutes) || 15)),
        sortOrder: Math.trunc(Number(payload.sortOrder) || 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(productId
          ? {}
          : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );
    return { ok: true, id: ref.id };
  });

  const deleteBusinessProduct = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    const productId = String(data.productId || "").trim();
    await assertBusinessOwner(context, businessId);
    await db()
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(productId)
      .delete();
    return { ok: true };
  });

  const duplicateBusinessProduct = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    const productId = String(data.productId || "").trim();
    await assertBusinessOwner(context, businessId);
    const snap = await db()
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .doc(productId)
      .get();
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Product not found.");
    }
    const copy = { ...(snap.data() || {}) };
    copy.nameEn = `${copy.nameEn || "Product"} (copy)`;
    copy.nameAr = `${copy.nameAr || "منتج"} (نسخة)`;
    copy.createdAt = admin.firestore.FieldValue.serverTimestamp();
    copy.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    const ref = await db()
      .collection("businesses")
      .doc(businessId)
      .collection("products")
      .add(copy);
    return { ok: true, id: ref.id };
  });

  const bulkUpdateBusinessPrices = functions.https.onCall(async (data, context) => {
    const businessId = String(data.businessId || "").trim();
    await assertBusinessOwner(context, businessId);
    const updates = Array.isArray(data.updates) ? data.updates : [];
    const batch = db().batch();
    for (const row of updates.slice(0, 400)) {
      const productId = String(row.productId || "").trim();
      if (!productId) continue;
      const ref = db()
        .collection("businesses")
        .doc(businessId)
        .collection("products")
        .doc(productId);
      const patch = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
      if (row.priceIqd !== undefined) {
        patch.priceIqd = Math.max(0, Math.trunc(Number(row.priceIqd) || 0));
      }
      if (row.discountPercent !== undefined) {
        patch.discountPercent = Math.max(0, Number(row.discountPercent) || 0);
      }
      if (row.available !== undefined) patch.available = row.available === true;
      batch.set(ref, patch, { merge: true });
    }
    await batch.commit();
    return { ok: true, count: updates.length };
  });

  const placeBusinessOrder = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const businessId = String(data.businessId || "").trim();
    const items = Array.isArray(data.items) ? data.items : [];
    if (!businessId || items.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "Business and items required.");
    }
    const bizSnap = await db().collection("businesses").doc(businessId).get();
    if (!bizSnap.exists || bizSnap.data()?.status !== "live") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Business is not live.",
      );
    }
    const biz = bizSnap.data() || {};
    if (biz.temporarilyClosed === true) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Business is temporarily closed.",
      );
    }
    let subtotal = 0;
    const normalized = [];
    for (const item of items) {
      const productId = String(item.productId || "").trim();
      const qty = Math.max(1, Math.trunc(Number(item.quantity) || 1));
      const productSnap = await db()
        .collection("businesses")
        .doc(businessId)
        .collection("products")
        .doc(productId)
        .get();
      if (!productSnap.exists || productSnap.data()?.available === false) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Product unavailable: ${productId}`,
        );
      }
      const p = productSnap.data() || {};
      const price = Math.trunc(Number(p.priceIqd) || 0);
      const discount = Math.max(0, Number(p.discountPercent) || 0);
      const unit = discount > 0 ? Math.round(price * (100 - discount) / 100) : price;
      subtotal += unit * qty;
      normalized.push({
        productId,
        nameEn: String(p.nameEn || ""),
        nameAr: String(p.nameAr || ""),
        unitPriceIqd: unit,
        quantity: qty,
      });
    }
    const deliveryFeeIqd = Math.max(0, Math.trunc(Number(data.deliveryFeeIqd) || 2000));
    const totalIqd = subtotal + deliveryFeeIqd;
    const commissionPercent = Number(biz.commissionPercent) || 15;
    const platformCommissionIqd = Math.round(subtotal * commissionPercent / 100);
    const businessEarningsIqd = subtotal - platformCommissionIqd;

    const customerSnap = await db().collection("users").doc(context.auth.uid).get();
    const customer = customerSnap.data() || {};

    const orderRef = await db().collection("businessOrders").add({
      businessId,
      businessName: biz.nameEn || biz.nameAr || "",
      customerId: context.auth.uid,
      customerName: String(customer.name || ""),
      customerPhone: String(customer.phone || ""),
      driverId: "",
      status: "pending",
      items: normalized,
      subtotalIqd: subtotal,
      deliveryFeeIqd,
      totalIqd,
      platformCommissionIqd,
      businessEarningsIqd,
      commissionPercent,
      districtId: String(biz.districtId || ""),
      subDistrictId: String(biz.subDistrictId || ""),
      pickupLat: Number(biz.latitude) || 0,
      pickupLng: Number(biz.longitude) || 0,
      dropoffLat: Number(data.dropoffLat) || 0,
      dropoffLng: Number(data.dropoffLng) || 0,
      dropoffLabel: String(data.dropoffLabel || "").trim(),
      notes: String(data.notes || "").trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await notifyOwner(
      businessId,
      "New order received",
      `${String(customer.name || "Customer")} placed an order for ${totalIqd} IQD`,
      { type: "business_order_new", orderId: orderRef.id, totalIqd: String(totalIqd) },
    );

    return { ok: true, orderId: orderRef.id };
  });

  const updateBusinessOrderStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }
    const orderId = String(data.orderId || "").trim();
    const status = String(data.status || "").trim();
    if (!orderId || !ORDER_STATUSES.has(status)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "orderId and valid status required.",
      );
    }
    const orderRef = db().collection("businessOrders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found.");
    }
    const order = orderSnap.data() || {};
    const userSnap = await db().collection("users").doc(context.auth.uid).get();
    const user = userSnap.data() || {};
    const isAdmin = user.role === "manager" || user.role === "assistant";
    const isOwner =
      user.role === "businessOwner" && user.businessId === order.businessId;
    const isDriver = user.role === "driver";
    const isCustomer = context.auth.uid === order.customerId;

    if (!isAdmin && !isOwner && !isDriver && !isCustomer) {
      throw new functions.https.HttpsError("permission-denied", "Not allowed.");
    }

    const update = {
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (data.driverId) update.driverId = String(data.driverId);
    if (isDriver && !order.driverId && status === "outForDelivery") {
      update.driverId = context.auth.uid;
    }
    if (status === "delivered") {
      update.deliveredAt = admin.firestore.FieldValue.serverTimestamp();
      await db().collection("businesses").doc(String(order.businessId)).set(
        {
          totalOrders: admin.firestore.FieldValue.increment(1),
          totalRevenueIqd: admin.firestore.FieldValue.increment(
            Number(order.businessEarningsIqd) || 0,
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await orderRef.set(update, { merge: true });

    const customerStatusMessages = {
      accepted: {
        title: "Order accepted",
        body: "Your order has been accepted and is being prepared.",
      },
      preparing: {
        title: "Order preparing",
        body: "Your order is being prepared.",
      },
      ready: {
        title: "Order ready",
        body: "Your order is ready for pickup or delivery.",
      },
      outForDelivery: {
        title: "Out for delivery",
        body: "Your order is on the way.",
      },
      delivered: {
        title: "Order delivered",
        body: "Your order has been delivered. Enjoy!",
      },
      cancelled: {
        title: "Order cancelled",
        body: "Your order was cancelled.",
      },
      rejected: {
        title: "Order rejected",
        body: "Your order was rejected by the store.",
      },
    };
    const statusMessage = customerStatusMessages[status] || {
      title: "Order update",
      body: `Your order is now: ${status}`,
    };

    // Notify customer
    try {
      const cust = await db().collection("users").doc(String(order.customerId)).get();
      await sendToToken(
        cust.data()?.fcmToken,
        statusMessage.title,
        statusMessage.body,
        { type: "business_order_status", orderId, status },
        "default",
      );
    } catch (_) {}

    if (status === "cancelled") {
      await notifyOwner(
        String(order.businessId),
        "Order cancelled",
        `Order #${orderId.slice(-6)} was cancelled`,
        { type: "business_order_cancelled", orderId, status },
      );
    }

    return { ok: true };
  });

  return {
    seedBusinessTypes,
    saveBusinessTypes,
    createBusinessPartner,
    setBusinessStatus,
    saveBusinessProfile,
    submitBusinessForReview,
    deleteBusiness,
    saveBusinessCategory,
    deleteBusinessCategory,
    saveBusinessProduct,
    deleteBusinessProduct,
    duplicateBusinessProduct,
    bulkUpdateBusinessPrices,
    placeBusinessOrder,
    updateBusinessOrderStatus,
  };
}

module.exports = { createBusinessModule, DEFAULT_BUSINESS_TYPES };
