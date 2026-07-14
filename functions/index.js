const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

function stringValue(value, fallback = "") {
  if (value === undefined || value === null) return fallback;
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return fallback;
}

function isInvalidTokenError(error) {
  return error &&
    (error.code === "messaging/registration-token-not-registered" ||
      error.code === "messaging/invalid-registration-token");
}

async function getUserTokens(uid, userData) {
  const tokens = new Map();
  const rootToken = userData && userData.fcmToken;

  if (rootToken && typeof rootToken === "string") {
    tokens.set(rootToken, {source: "user"});
  }

  const tokenSnapshot = await db
    .collection("users")
    .doc(uid)
    .collection("fcmTokens")
    .get();

  tokenSnapshot.docs.forEach((doc) => {
    const data = doc.data();
    const token = data.token || doc.id;
    if (token && typeof token === "string") {
      tokens.set(token, {source: "subcollection", ref: doc.ref});
    }
  });

  return tokens;
}

async function pruneInvalidToken(uid, tokenInfo) {
  if (tokenInfo.source === "subcollection" && tokenInfo.ref) {
    await tokenInfo.ref.delete();
    return;
  }

  if (tokenInfo.source === "user") {
    await db.collection("users").doc(uid).update({
      fcmToken: admin.firestore.FieldValue.delete(),
    });
  }
}

async function sendPushToUser(uid, notification, notificationId) {
  if (!uid) return null;

  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data();
  if (!userData || userData.notificationsEnabled === false) return null;

  const tokens = await getUserTokens(uid, userData);
  if (tokens.size === 0) return null;

  const title = stringValue(notification.title, "Workable");
  const body = stringValue(notification.message, "You have a new update.");
  const type = stringValue(notification.type, "general");
  const status = stringValue(notification.status, "update");
  const category = stringValue(
    notification.notificationCategory,
    "marketplace_update"
  );

  const metadata = notification.metadata || {};
  const data = {
    notificationId,
    type,
    status,
    category,
    requiresAction: String(notification.requiresAction === true),
    demandSignalId: stringValue(metadata.demandSignalId),
    categoryName: stringValue(metadata.categoryName),
    bookingId: stringValue(metadata.bookingId || notification.bookingId),
    documentId: stringValue(metadata.documentId || notification.documentId),
    chatId: stringValue(metadata.chatId),
    chatWithId: stringValue(metadata.chatWithId),
    chatWithName: stringValue(metadata.chatWithName),
    userRole: stringValue(metadata.userRole),
    reviewId: stringValue(metadata.reviewId),
    workerId: stringValue(metadata.workerId),
    couponId: stringValue(metadata.couponId),
    couponCode: stringValue(metadata.couponCode),
  };

  const results = await Promise.all(
    Array.from(tokens.entries()).map(async ([token, tokenInfo]) => {
      try {
        await admin.messaging().send({
          token,
          notification: {title, body},
          data,
          android: {
            priority: notification.requiresAction === true ? "high" : "normal",
            notification: {
              channelId: "workable_updates",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
        return {success: true};
      } catch (error) {
        if (isInvalidTokenError(error)) {
          await pruneInvalidToken(uid, tokenInfo);
        }
        console.error("Push send failed", {uid, notificationId, error});
        return {success: false};
      }
    })
  );

  const successCount = results.filter((result) => result.success).length;
  await db
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .doc(notificationId)
    .set({
      pushStatus: successCount > 0 ? "sent" : "failed",
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushSuccessCount: successCount,
      pushTargetCount: tokens.size,
    }, {merge: true});

  return null;
}

function cleanMetadata(metadata) {
  const cleaned = {};
  Object.keys(metadata || {}).forEach((key) => {
    const value = metadata[key];
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      cleaned[key] = String(value);
    }
  });
  return cleaned;
}

async function createUserNotification({
  uid,
  title,
  message,
  type,
  notificationCategory,
  status = "update",
  requiresAction = false,
  metadata = {},
}) {
  if (!uid) return null;

  return db
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({
      title,
      message,
      type,
      status,
      requiresAction,
      notificationCategory,
      metadata: cleanMetadata(metadata),
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "cloud_function",
    });
}

function textFrom(data, keys, fallback) {
  for (const key of keys) {
    const value = stringValue(data && data[key]);
    if (value && value.toLowerCase() !== "null") return value;
  }
  return fallback;
}

function notificationIdFor(parts) {
  return parts
    .map((part) => stringValue(part).replace(/[^a-zA-Z0-9_-]/g, "_"))
    .filter((part) => part)
    .join("__")
    .slice(0, 240);
}

function normalizeReferralCode(value) {
  return stringValue(value).replace(/[^a-zA-Z0-9]/g, "").toUpperCase();
}

async function setUserNotification({
  uid,
  notificationId,
  title,
  message,
  type,
  notificationCategory,
  status = "update",
  requiresAction = false,
  metadata = {},
}) {
  if (!uid || !notificationId) return null;

  return db
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .doc(notificationId)
    .set({
      title,
      message,
      body: message,
      type,
      status,
      requiresAction,
      category: notificationCategory,
      notificationCategory,
      metadata: cleanMetadata(metadata),
      ...cleanMetadata(metadata),
      isRead: false,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "cloud_function",
    }, {merge: true});
}

async function createRepeatServiceCoupon({
  bookingId,
  booking,
  customerId,
  workerId,
  service,
}) {
  if (!bookingId || !customerId) return null;

  const couponId = notificationIdFor(["repeat_coupon", bookingId, customerId]);
  const couponRef = db
    .collection("users")
    .doc(customerId)
    .collection("coupons")
    .doc(couponId);
  const existing = await couponRef.get();
  if (existing.exists) return null;

  const now = new Date();
  const validUntil = new Date(now.getTime());
  validUntil.setMonth(validUntil.getMonth() + 2);
  const codeSeed = bookingId.replace(/[^a-zA-Z0-9]/g, "").slice(-6).toUpperCase();
  const code = `WORKABLE${codeSeed || "NEXT10"}`;
  const city = textFrom(booking, ["city", "serviceCity", "customerCity"], "");

  await couponRef.set({
    source: "booking_completion",
    bookingId,
    customerId,
    workerId,
    service,
    city,
    code,
    discountType: "percent",
    discountValue: 10,
    maxDiscount: 100,
    currency: "INR",
    status: "active",
    validFrom: admin.firestore.Timestamp.fromDate(now),
    validUntil: admin.firestore.Timestamp.fromDate(validUntil),
    usageLimit: 1,
    usedCount: 0,
    shareable: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return setUserNotification({
    uid: customerId,
    notificationId: notificationIdFor(["coupon_reward", bookingId, customerId]),
    title: "A thank-you coupon is ready",
    message: `Use ${code} within 2 months for 10% off your next Workable service.`,
    type: "coupon_reward",
    notificationCategory: "coupon",
    status: "coupon_ready",
    requiresAction: false,
    metadata: {
      bookingId,
      workerId,
      service,
      couponId,
      couponCode: code,
      userRole: "customer",
    },
  });
}

async function markCouponRedeemed({
  customerId,
  couponId,
  bookingId,
  transactionId,
}) {
  if (!customerId || !couponId || !bookingId) return null;

  const couponRef = db
    .collection("users")
    .doc(customerId)
    .collection("coupons")
    .doc(couponId);
  const couponSnap = await couponRef.get();
  if (!couponSnap.exists) return null;

  const coupon = couponSnap.data() || {};
  if (stringValue(coupon.status) === "used") return null;

  return couponRef.set({
    status: "used",
    usedCount: admin.firestore.FieldValue.increment(1),
    usedAt: admin.firestore.FieldValue.serverTimestamp(),
    redeemedBookingId: bookingId,
    redeemedTransactionId: transactionId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function createReferralConversionForUser(uid, userData) {
  const code = normalizeReferralCode(userData && userData.referredByCode);
  if (!uid || !code) return null;

  const userRef = db.collection("users").doc(uid);
  const referralRef = db.collection("referrals").doc(`referred_${uid}`);
  const existingReferral = await referralRef.get();
  if (existingReferral.exists) {
    const existing = existingReferral.data() || {};
    const existingCode = normalizeReferralCode(existing.referralCode);
    if (existingCode && existingCode !== code) {
      return userRef.set({
        referredByUserId: stringValue(existing.referrerId),
        referredByCode: existingCode,
        referralStatus: stringValue(existing.status, "tracked"),
        referralTamperBlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return null;
  }

  const referrerSnapshot = await db
    .collection("users")
    .where("referralCode", "==", code)
    .limit(1)
    .get();

  if (referrerSnapshot.empty) {
    return userRef.set({
      referredByCode: code,
      referralStatus: "invalid_code",
      referralCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  const referrerDoc = referrerSnapshot.docs[0];
  const referrerId = referrerDoc.id;
  if (referrerId === uid) {
    return userRef.set({
      referredByCode: code,
      referralStatus: "self_referral_blocked",
      referralCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const referrer = referrerDoc.data() || {};
  const referredName = textFrom(userData, ["name", "displayName"], "New customer");
  const referredRole = stringValue(userData && userData.userType, "customer");
  const initialStatus = referredRole === "worker" ?
    "pending_worker_onboarding" :
    "pending_first_paid_booking";
  const notificationMessage = referredRole === "worker" ?
    `${referredName} joined as a worker with your referral code. Reward unlocks after worker onboarding policy is approved.` :
    `${referredName} signed up with your referral code. Reward unlocks after their first paid booking.`;

  const batch = db.batch();
  batch.set(referralRef, {
    referrerId,
    referrerName: textFrom(referrer, ["name", "displayName"], "Workable user"),
    referralCode: code,
    referredUserId: uid,
    referredUserName: referredName,
    referredUserEmail: stringValue(userData && userData.email),
    referredUserPhone: stringValue(
      (userData && userData.phoneNumber) || (userData && userData.phone)
    ),
    referredUserRole: referredRole,
    status: initialStatus,
    rewardStatus: "locked",
    rewardAmount: 0,
    rewardCurrency: "INR",
    source: "signup_referral_code",
    createdAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(userRef, {
    referredByUserId: referrerId,
    referredByCode: code,
    referralStatus: initialStatus,
    referralTrackedAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(referrerDoc.ref, {
    referralSignupCount: admin.firestore.FieldValue.increment(1),
    lastReferralSignupAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(
    referrerDoc.ref.collection("notifications").doc(notificationIdFor([
      "referral_joined",
      uid,
      referrerId,
    ])),
    {
      title: "Your referral joined Workable",
      message: notificationMessage,
      body: notificationMessage,
      type: "referral_joined",
      status: initialStatus,
      requiresAction: false,
      notificationCategory: "referral",
      category: "referral",
      metadata: {
        referredUserId: uid,
        referredUserRole: referredRole,
        referralCode: code,
        userRole: "customer",
      },
      isRead: false,
      read: false,
      createdAt: now,
      updatedAt: now,
      source: "cloud_function",
    },
    {merge: true}
  );

  return batch.commit();
}

async function unlockReferralRewardForCustomer({customerId, bookingId, booking}) {
  if (!customerId || !bookingId) return null;

  const snapshot = await db
    .collection("referrals")
    .where("referredUserId", "==", customerId)
    .where("status", "==", "pending_first_paid_booking")
    .limit(1)
    .get();
  if (snapshot.empty) return null;

  const referralDoc = snapshot.docs[0];
  const referral = referralDoc.data() || {};
  const referrerId = stringValue(referral.referrerId);
  if (!referrerId) return null;

  const rewardAmount = 50;
  const bookingAmount = Number(
    booking && (
      booking.finalAmount ||
      booking.totalAmount ||
      booking.amountPaid ||
      booking.price ||
      booking.estimatedPrice ||
      0
    )
  ) || 0;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const referrerRef = db.collection("users").doc(referrerId);
  const referrerSnapshot = await referrerRef.get();
  const referrer = referrerSnapshot.data() || {};
  const referrerSignupCount = Number(referrer.referralSignupCount || 0);
  const referrerCompletedCount = Number(referrer.referralCompletedCount || 0);
  const referrerSpend = Number(referrer.referralAttributedSpend || 0);
  const batch = db.batch();

  batch.set(referralDoc.ref, {
    status: "completed",
    rewardStatus: "ready_for_credit",
    rewardAmount,
    rewardCurrency: "INR",
    firstPaidBookingId: bookingId,
    firstPaidBookingAmount: bookingAmount,
    referredCustomerSpend: bookingAmount,
    referredCustomerPaidBookingCount: admin.firestore.FieldValue.increment(1),
    referrerTotalJoinedSnapshot: referrerSignupCount,
    referrerCompletedCountSnapshot: referrerCompletedCount + 1,
    referrerAttributedSpendSnapshot: referrerSpend + bookingAmount,
    completedAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(referrerRef, {
    referralCompletedCount: admin.firestore.FieldValue.increment(1),
    referralAttributedSpend: admin.firestore.FieldValue.increment(bookingAmount),
    referralPaidBookingCount: admin.firestore.FieldValue.increment(1),
    referralRewardPendingAmount: admin.firestore.FieldValue.increment(rewardAmount),
    lastReferralRewardAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(
    referrerRef.collection("notifications").doc(notificationIdFor([
      "referral_reward_ready",
      customerId,
      bookingId,
    ])),
    {
      title: "Referral reward unlocked",
      message: `A referred customer completed their first paid booking. Rs ${rewardAmount} reward is ready for review.`,
      body: `A referred customer completed their first paid booking. Rs ${rewardAmount} reward is ready for review.`,
      type: "referral_reward_ready",
      status: "reward_ready",
      requiresAction: false,
      notificationCategory: "referral",
      category: "referral",
      metadata: {
        referredUserId: customerId,
        bookingId,
        rewardAmount: String(rewardAmount),
        bookingAmount: String(bookingAmount),
        userRole: "customer",
      },
      isRead: false,
      read: false,
      createdAt: now,
      updatedAt: now,
      source: "cloud_function",
    },
    {merge: true}
  );

  return batch.commit();
}

exports.reviewReferralReward = functions.https.onCall(
  async (data, context) => {
    const adminId = await requireCallableAdmin(context);
    const referralId = requireCleanText(
      data && data.referralId,
      "Referral",
      {min: 2, max: 160}
    );
    const decision = requireCleanText(data && data.decision, "Decision", {
      min: 6,
      max: 20,
    });
    const note = stringValue(data && data.note).trim().slice(0, 300);
    const requestedAmount = Number(data && data.rewardAmount);

    if (!["approved", "rejected", "credited"].includes(decision)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Decision must be approved, rejected, or credited."
      );
    }

    const referralRef = db.collection("referrals").doc(referralId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    let referrerId = "";
    let referredUserId = "";
    let rewardAmount = 0;
    let previousRewardStatus = "";
    let status = "";

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(referralRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Referral record not found."
        );
      }

      const referral = snapshot.data() || {};
      referrerId = stringValue(referral.referrerId);
      referredUserId = stringValue(referral.referredUserId);
      previousRewardStatus = stringValue(referral.rewardStatus, "locked");
      status = stringValue(referral.status, "tracked");
      rewardAmount = Number(referral.rewardAmount || 0);
      if (requestedAmount > 0 && previousRewardStatus !== "credited") {
        rewardAmount = requestedAmount;
      }

      if (!referrerId || !referredUserId) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Referral record is missing user information."
        );
      }

      const update = {
        rewardAmount,
        adminNote: note,
        reviewedBy: adminId,
        reviewedAt: now,
        updatedAt: now,
        reviewSource: "cloud_function",
      };

      const referrerRef = db.collection("users").doc(referrerId);
      const shouldRemovePending =
        previousRewardStatus === "ready_for_credit" ||
        previousRewardStatus === "approved";

      if (decision === "approved") {
        if (previousRewardStatus === "credited") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "This referral reward is already credited."
          );
        }
        transaction.update(referralRef, {
          ...update,
          status: status === "pending_worker_onboarding" ?
            "completed" :
            status,
          rewardStatus: "approved",
          approvedBy: adminId,
          approvedAt: now,
        });
        if (!shouldRemovePending && rewardAmount > 0) {
          transaction.set(referrerRef, {
            referralRewardPendingAmount:
              admin.firestore.FieldValue.increment(rewardAmount),
            updatedAt: now,
          }, {merge: true});
        }
      }

      if (decision === "rejected") {
        if (previousRewardStatus === "credited") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Credited referral rewards cannot be rejected."
          );
        }
        transaction.update(referralRef, {
          ...update,
          rewardStatus: "rejected",
          rejectionReason: note || "Referral reward was not approved.",
          rejectedBy: adminId,
          rejectedAt: now,
        });
        if (shouldRemovePending && rewardAmount > 0) {
          transaction.set(referrerRef, {
            referralRewardPendingAmount:
              admin.firestore.FieldValue.increment(-rewardAmount),
            updatedAt: now,
          }, {merge: true});
        }
      }

      if (decision === "credited") {
        if (previousRewardStatus === "credited") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "This referral reward is already credited."
          );
        }
        if (rewardAmount <= 0) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Reward amount must be greater than zero before crediting."
          );
        }
        transaction.update(referralRef, {
          ...update,
          status: "reward_credited",
          rewardStatus: "credited",
          creditedBy: adminId,
          creditedAt: now,
        });
        transaction.set(referrerRef, {
          referralRewardPendingAmount: shouldRemovePending ?
            admin.firestore.FieldValue.increment(-rewardAmount) :
            admin.firestore.FieldValue.increment(0),
          referralRewardCreditedAmount:
            admin.firestore.FieldValue.increment(rewardAmount),
          referralRewardCreditedCount:
            admin.firestore.FieldValue.increment(1),
          lastReferralCreditedAt: now,
          updatedAt: now,
        }, {merge: true});
      }
    });

    const notificationTitle = decision === "credited" ?
      "Referral reward credited" :
      decision === "approved" ?
        "Referral reward approved" :
        "Referral reward rejected";
    const notificationMessage = decision === "credited" ?
      `Your referral reward of Rs ${rewardAmount} was credited.` :
      decision === "approved" ?
        `Your referral reward of Rs ${rewardAmount} was approved and is waiting for credit.` :
        `Your referral reward was rejected${note ? `: ${note}` : "."}`;

    await setUserNotification({
      uid: referrerId,
      notificationId: notificationIdFor([
        "referral_reward_review",
        referralId,
        decision,
      ]),
      title: notificationTitle,
      message: notificationMessage,
      type: "referral_reward_review",
      notificationCategory: "referral",
      status: decision,
      requiresAction: false,
      metadata: {
        referralId,
        referredUserId,
        rewardAmount: String(rewardAmount),
        userRole: "customer",
      },
    });

    return {
      referralId,
      status: decision,
      rewardAmount,
    };
  }
);

async function workerIdsForCategory(categoryName) {
  const workerIds = new Set();
  const skillsSnapshot = await db
    .collection("workers")
    .where("skills", "array-contains", categoryName)
    .limit(50)
    .get();
  skillsSnapshot.docs.forEach((doc) => workerIds.add(doc.id));

  const categoriesSnapshot = await db
    .collection("workers")
    .where("serviceCategories", "array-contains", categoryName)
    .limit(50)
    .get();
  categoriesSnapshot.docs.forEach((doc) => workerIds.add(doc.id));

  return Array.from(workerIds);
}

function determineVerificationTier(statuses) {
  const selfie = statuses.selfie === "verified";
  const pan = statuses.pan === "verified";
  const address =
    statuses.addressProof === "verified" || statuses.address === "verified";
  const govtId = [
    "aadhaar",
    "passport",
    "voter",
    "voterId",
    "driving_license",
    "drivingLicense",
  ].some((idType) => statuses[idType] === "verified");
  const police =
    statuses.backgroundCheck === "verified" ||
    statuses.policeCertificate === "verified";

  if (selfie && govtId && pan && address && police) {
    return "police_verified";
  }
  if (selfie && govtId && pan && address) {
    return "verified";
  }
  return "new";
}

function firstNonEmpty(values) {
  for (const value of values) {
    const text = stringValue(value).trim();
    if (text && text.toLowerCase() !== "null") return text;
  }
  return "";
}

function resolveWorkerLocation(workerData) {
  const location = workerData.location;
  if (location && typeof location.latitude === "number" &&
    typeof location.longitude === "number") {
    return location;
  }

  if (typeof location === "string") {
    const parts = location.split(",");
    if (parts.length === 2) {
      const lat = Number(parts[0].trim());
      const lng = Number(parts[1].trim());
      if (isUsableCoordinate(lat, lng)) {
        return new admin.firestore.GeoPoint(lat, lng);
      }
    }
  }

  const lat = Number(workerData.latitude);
  const lng = Number(workerData.longitude);
  if (isUsableCoordinate(lat, lng)) {
    return new admin.firestore.GeoPoint(lat, lng);
  }

  return null;
}

function isUsableCoordinate(lat, lng) {
  return Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    !(lat === 0 && lng === 0) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180;
}

async function loadVerificationStatuses(uid) {
  const snapshot = await db
    .collection("users")
    .doc(uid)
    .collection("identityVerification")
    .get();
  const statuses = {};
  snapshot.docs.forEach((doc) => {
    statuses[doc.id] = stringValue(doc.data().status, "incomplete");
  });
  return statuses;
}

async function syncWorkerVisibility(uid) {
  const workerRef = db.collection("workers").doc(uid);
  const [workerDoc, userDoc, statuses] = await Promise.all([
    workerRef.get(),
    db.collection("users").doc(uid).get(),
    loadVerificationStatuses(uid),
  ]);

  if (!workerDoc.exists) {
    await db.collection("users").doc(uid).set({
      verification: {tier: determineVerificationTier(statuses)},
    }, {merge: true});
    return null;
  }

  const workerData = workerDoc.data() || {};
  const userData = userDoc.data() || {};
  const tier = determineVerificationTier(statuses);
  const imageUrl = firstNonEmpty([
    workerData.imageUrl,
    workerData.profileImageUrl,
    userData.imageUrl,
    userData.profileImageUrl,
    userData.profileImage,
    userData.photoUrl,
  ]);
  const location = resolveWorkerLocation(workerData);
  const hasProfileImage = Boolean(imageUrl);
  const selfieVerified = statuses.selfie === "verified";
  const disabled =
    workerData.accountDisabled === true ||
    workerData.accountStatus === "disabled";
  const visibleToUsers =
    hasProfileImage && selfieVerified && Boolean(location) && !disabled;

  const workerUpdate = {
    visibleToUsers,
    visibilityUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    verification: {
      ...statuses,
      tier,
      selfie: statuses.selfie || "incomplete",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
  if (imageUrl) {
    workerUpdate.imageUrl = imageUrl;
    workerUpdate.profileImageUrl = imageUrl;
  }
  if (location) {
    workerUpdate.location = location;
  }

  await Promise.all([
    workerRef.set(workerUpdate, {merge: true}),
    db.collection("users").doc(uid).set({
      verification: {tier},
    }, {merge: true}),
  ]);
  return null;
}

function todayKey() {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${now.getFullYear()}-${month}-${day}`;
}

function openAiApiKey() {
  return process.env.OPENAI_API_KEY;
}

function openAiModel() {
  return process.env.OPENAI_MODEL || "gpt-5.6-luna";
}

function estimateTokens(text) {
  const clean = stringValue(text).trim();
  if (!clean) return 0;
  return Math.ceil(clean.length / 4);
}

function normalizeCacheKey(query) {
  return stringValue(query)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .slice(0, 18)
    .join("-");
}

function normalizeDemandText(value) {
  return stringValue(value)
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function slugForDemand(value) {
  const slug = normalizeDemandText(value)
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return slug || "unknown";
}

function demandSignalIdFor(normalizedQuery, city) {
  const base = `${slugForDemand(city)}_${slugForDemand(normalizedQuery)}`;
  return base.length <= 90 ? base : base.slice(0, 90);
}

function requireCallableAuth(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Please log in again to continue."
    );
  }
  return context.auth.uid;
}

function requireCleanText(value, fieldName, {min = 1, max = 120} = {}) {
  const text = stringValue(value).trim();
  if (text.length < min || text.length > max || text.includes("/")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} is invalid.`
    );
  }
  return text;
}

async function requireCallableAdmin(context) {
  const uid = requireCallableAuth(context);
  const userDoc = await db.collection("users").doc(uid).get();
  const userType = stringValue(userDoc.data() && userDoc.data().userType);
  if (userType !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can perform this action."
    );
  }
  return uid;
}

async function requireCallableAdminRole(context, role) {
  const uid = requireCallableAuth(context);
  const userDoc = await db.collection("users").doc(uid).get();
  const user = userDoc.data() || {};
  const userType = stringValue(user.userType);
  const adminRole = stringValue(user.adminRole).toLowerCase();
  const adminRoles = Array.isArray(user.adminRoles) ?
    user.adminRoles.map((item) => stringValue(item).toLowerCase()) :
    [];
  const hasLegacyAdminAccess =
    userType === "admin" && !adminRole && adminRoles.length === 0;
  const allowed = userType === "admin" && (
    hasLegacyAdminAccess ||
    adminRole === role ||
    adminRole === "super_admin" ||
    adminRoles.includes(role) ||
    adminRoles.includes("super_admin")
  );
  if (!allowed) {
    throw new functions.https.HttpsError(
      "permission-denied",
      `${role.replace(/_/g, " ")} permission is required.`
    );
  }
  return uid;
}

function writeAdminAuditLog({
  adminId,
  action,
  targetCollection,
  targetId,
  note = "",
  previousState = {},
  newState = {},
}) {
  return db.collection("adminAuditLogs").add({
    adminId,
    action,
    targetCollection,
    targetId,
    note,
    previousState,
    newState,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function cacheTtlHours(diagnosis) {
  const urgency = stringValue(diagnosis && diagnosis.urgency);
  const confidence = stringValue(diagnosis && diagnosis.confidence);
  if (urgency === "Urgent") return 6;
  if (confidence === "high") return 72;
  if (confidence === "medium") return 24;
  return 0;
}

function cacheExpiryFromNow(hours) {
  return admin.firestore.Timestamp.fromMillis(
    Date.now() + hours * 60 * 60 * 1000
  );
}

function validPayoutMethod(method, payoutDetails) {
  if (method === "bank") {
    return Boolean(
      stringValue(payoutDetails.bankAccountNumber).trim() &&
      stringValue(payoutDetails.ifsc).trim()
    );
  }
  return stringValue(payoutDetails.upiId).includes("@");
}

function workerPayoutConfig(worker) {
  const payout = worker && typeof worker.payout === "object" ?
    worker.payout :
    {};
  const topLevelMethod = stringValue(worker && worker.paymentMethod).toLowerCase();
  const method = payout.defaultMethod === "bank" || topLevelMethod === "bank" ?
    "bank" :
    "upi";

  return {
    method,
    details: {
      ...payout,
      upiId: stringValue(payout.upiId || (worker && worker.upiId)),
      bankAccountName: stringValue(
        payout.bankAccountName || (worker && worker.bankAccountName)
      ),
      bankAccountNumber: stringValue(
        payout.bankAccountNumber || (worker && worker.bankAccountNumber)
      ),
      ifsc: stringValue(payout.ifsc || (worker && worker.ifscCode)),
    },
  };
}

function bookingWorkerAmount(data) {
  const candidates = [
    data && data.price,
    data && data.estimatedPrice,
    data && data.amount,
    data && data.totalAmount,
  ];
  for (const value of candidates) {
    if (typeof value === "number" && value > 0) return value;
    const match = stringValue(value).match(/\d+(\.\d+)?/);
    if (match) {
      const parsed = Number(match[0]);
      if (parsed > 0) return parsed;
    }
  }
  return 0;
}

function isPayoutEligibleBooking(data) {
  const status = stringValue(data && data.status).toLowerCase();
  const paymentStatus = stringValue(data && data.paymentStatus).toLowerCase();
  const payoutStatus = stringValue(data && data.payoutStatus).toLowerCase();
  const earned =
    status === "completed" ||
    status === "paid" ||
    paymentStatus === "paid";
  const activeOrPaidPayout = ["requested", "processing", "paid"].includes(
    payoutStatus
  );
  return earned && !activeOrPaidPayout;
}

function isCompletedPaidBooking(data) {
  const status = stringValue(data && data.status).toLowerCase();
  const paymentStatus = stringValue(data && data.paymentStatus).toLowerCase();
  return status === "completed" || status === "paid" || paymentStatus === "paid";
}

function timestampToDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  return null;
}

function parseBookingScheduledDate(booking) {
  const direct = timestampToDate(booking.scheduledAt || booking.bookingDateTime);
  if (direct) return direct;

  const dateText = stringValue(booking.preferredDate || booking.date).trim();
  const timeText = stringValue(booking.preferredTime || booking.time).trim();
  if (!dateText) return null;

  const parsed = new Date(`${dateText} ${timeText || "00:00"}`);
  if (!Number.isNaN(parsed.getTime())) return parsed;

  const fallback = new Date(dateText);
  return Number.isNaN(fallback.getTime()) ? null : fallback;
}

function achievementMonthKey(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

function workerBadgeLevel({
  completedJobs,
  verifiedHours,
  averageRating,
  reviewCount,
  onTimePercent,
}) {
  const rating = reviewCount >= 3 || averageRating > 0 ? averageRating : 4.0;
  if (
    completedJobs >= 250 &&
    verifiedHours >= 1200 &&
    rating >= 4.8 &&
    onTimePercent >= 95
  ) return "Platinum";
  if (completedJobs >= 120 && verifiedHours >= 500 && rating >= 4.7) {
    return "Diamond";
  }
  if (completedJobs >= 50 && verifiedHours >= 150 && rating >= 4.5) {
    return "Gold";
  }
  if (completedJobs >= 15 && verifiedHours >= 40 && rating >= 4.2) {
    return "Silver";
  }
  return "Verified";
}

function bookingVerifiedHours(booking) {
  const storedMinutes = Number(booking.verifiedWorkMinutes);
  if (Number.isFinite(storedMinutes) && storedMinutes > 0 && storedMinutes <= 16 * 60) {
    return storedMinutes / 60;
  }

  const timeline = booking.timeline || {};
  const start = timestampToDate(booking.workStartedAt || timeline.in_progress);
  const end = timestampToDate(
    booking.workCompletedAt ||
    booking.completionRequestedAt ||
    booking.completedAt ||
    booking.paidAt ||
    booking.customerConfirmedCompletionAt ||
    timeline.work_completed ||
    timeline.completion_requested ||
    timeline.completed ||
    timeline.paid
  );
  if (!start || !end || end <= start) return 0;
  const minutes = (end.getTime() - start.getTime()) / 60000;
  if (minutes <= 0 || minutes > 16 * 60) return 0;
  return minutes / 60;
}

function bookingVerifiedMinutes(booking) {
  return Math.round(bookingVerifiedHours(booking) * 60);
}

function bookingOnTimeResult(booking) {
  const scheduled = parseBookingScheduledDate(booking);
  const started = timestampToDate(booking.workStartedAt || (booking.timeline || {}).in_progress);
  if (!scheduled || !started) return null;
  const delayMinutes = (started.getTime() - scheduled.getTime()) / 60000;
  return delayMinutes <= 15;
}

function monthlyAchievementLabels({
  monthlyCompletedJobs,
  monthlyVerifiedHours,
  averageRating,
  onTimePercent,
  completedJobs,
}) {
  const labels = [];
  if (monthlyCompletedJobs >= 10 && averageRating >= 4.7) labels.push("Top worker");
  if (monthlyCompletedJobs >= 3 && completedJobs < 25) labels.push("Rising professional");
  if (monthlyVerifiedHours >= 40) labels.push("Verified hours milestone");
  if (onTimePercent >= 95 && monthlyCompletedJobs >= 5) labels.push("Most punctual professional");
  if (monthlyCompletedJobs >= 5 && averageRating >= 4.8) labels.push("Customer favourite");
  return labels;
}

async function syncWorkerAchievement(workerId, preferredDate = new Date()) {
  if (!workerId) return null;

  const [workerSnapshot, bookingsSnapshot, reviewsSnapshot] = await Promise.all([
    db.collection("workers").doc(workerId).get(),
    db.collection("bookings").where("workerId", "==", workerId).get(),
    db.collection("reviews").where("workerId", "==", workerId).get(),
  ]);

  const worker = workerSnapshot.data() || {};
  const completedBookings = bookingsSnapshot.docs
    .map((doc) => ({id: doc.id, ...doc.data()}))
    .filter(isCompletedPaidBooking);
  const monthKey = achievementMonthKey(preferredDate);
  const monthlyBookings = completedBookings.filter((booking) => {
    const date = timestampToDate(booking.paidAt || booking.completedAt || booking.updatedAt);
    return achievementMonthKey(date || preferredDate) === monthKey;
  });

  const ratings = reviewsSnapshot.docs
    .map((doc) => Number((doc.data() || {}).rating))
    .filter((rating) => Number.isFinite(rating) && rating > 0);
  const averageRating = ratings.length > 0 ?
    Math.round((ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length) * 10) / 10 :
    Number(worker.averageRating || worker.rating || 0);
  const verifiedHours = completedBookings.reduce(
    (total, booking) => total + bookingVerifiedHours(booking),
    0
  );
  const monthlyVerifiedHours = monthlyBookings.reduce(
    (total, booking) => total + bookingVerifiedHours(booking),
    0
  );
  const verifiedWorkMinutes = completedBookings.reduce(
    (total, booking) => total + bookingVerifiedMinutes(booking),
    0
  );
  const punctualityResults = completedBookings
    .map(bookingOnTimeResult)
    .filter((value) => value !== null);
  const computedOnTimePercent = punctualityResults.length > 0 ?
    Math.round(
      (punctualityResults.filter(Boolean).length / punctualityResults.length) * 100
    ) :
    0;
  const customerCounts = {};
  completedBookings.forEach((booking) => {
    const customerId = stringValue(booking.customerId);
    if (!customerId) return;
    customerCounts[customerId] = (customerCounts[customerId] || 0) + 1;
  });
  const repeatCustomers = Object.values(customerCounts)
    .filter((count) => count > 1).length;
  const onTimePercent = computedOnTimePercent ||
    Number(worker.onTimePercent || worker.punctualityScore || 0);
  const badgeLevel = workerBadgeLevel({
    completedJobs: completedBookings.length,
    verifiedHours,
    averageRating,
    reviewCount: ratings.length,
    onTimePercent,
  });

  const now = admin.firestore.FieldValue.serverTimestamp();
  const achievementRef = db
    .collection("workers")
    .doc(workerId)
    .collection("achievements")
    .doc(monthKey);

  const achievementData = {
    workerId,
    month: monthKey,
    completedJobs: completedBookings.length,
    monthlyCompletedJobs: monthlyBookings.length,
    verifiedHours: Math.round(verifiedHours * 10) / 10,
    monthlyVerifiedHours: Math.round(monthlyVerifiedHours * 10) / 10,
    verifiedWorkMinutes,
    averageRating,
    reviewCount: ratings.length,
    repeatCustomers,
    onTimePercent,
    punctualityTrackedJobs: punctualityResults.length,
    badgeLevel,
    achievementLabels: monthlyAchievementLabels({
      monthlyCompletedJobs: monthlyBookings.length,
      monthlyVerifiedHours,
      averageRating,
      onTimePercent,
      completedJobs: completedBookings.length,
    }),
    certificateNumber: `WRK-${workerId.slice(0, 6).toUpperCase()}-${monthKey.replace("-", "")}`,
    source: "cloud_function",
    updatedAt: now,
    createdAt: now,
  };

  await Promise.all([
    achievementRef.set(achievementData, {merge: true}),
    db.collection("workers").doc(workerId).set({
      badgeLevel,
      workerBadge: {
        level: badgeLevel,
        completedJobs: completedBookings.length,
        verifiedHours: Math.round(verifiedHours * 10) / 10,
        averageRating,
        reviewCount: ratings.length,
        repeatCustomers,
        onTimePercent,
        verifiedWorkMinutes,
        punctualityTrackedJobs: punctualityResults.length,
        updatedAt: now,
      },
      completedJobsCount: completedBookings.length,
      averageRating,
      reviewCount: ratings.length,
      totalReviews: ratings.length,
      verifiedWorkMinutes,
      onTimePercent,
      punctualityTrackedJobs: punctualityResults.length,
      updatedAt: now,
    }, {merge: true}),
  ]);

  return achievementData;
}

async function getCachedSmartDiagnosis(query) {
  const cacheKey = normalizeCacheKey(query);
  if (!cacheKey || cacheKey.length < 4) {
    return null;
  }

  const cacheRef = db.collection("smartBookingAiCache").doc(cacheKey);
  const snapshot = await cacheRef.get();
  if (!snapshot.exists) return null;

  const data = snapshot.data() || {};
  const expiresAt = data.expiresAt;
  if (
    !expiresAt ||
    typeof expiresAt.toMillis !== "function" ||
    expiresAt.toMillis() <= Date.now()
  ) {
    await cacheRef.set({
      status: "expired",
      lastExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return null;
  }

  await cacheRef.set({
    hitCount: admin.firestore.FieldValue.increment(1),
    lastHitAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    cacheKey,
    diagnosis: data.diagnosis || localAiFallback(query),
  };
}

async function saveCachedSmartDiagnosis({query, diagnosis, model}) {
  const cacheKey = normalizeCacheKey(query);
  const ttlHours = cacheTtlHours(diagnosis);
  if (!cacheKey || ttlHours <= 0) return null;

  await db.collection("smartBookingAiCache").doc(cacheKey).set({
    cacheKey,
    normalizedQuery: cacheKey,
    diagnosis,
    model,
    ttlHours,
    expiresAt: cacheExpiryFromNow(ttlHours),
    hitCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return cacheKey;
}

function localAiFallback(query) {
  const normalized = stringValue(query).toLowerCase();
  let category = "General Help";
  if (normalized.includes("leak") || normalized.includes("pipe")) {
    category = "Plumbing";
  } else if (
    normalized.includes("power") ||
    normalized.includes("electric") ||
    normalized.includes("short circuit")
  ) {
    category = "Electrical";
  } else if (
    normalized.includes("pickup") ||
    normalized.includes("pick up") ||
    normalized.includes("deliver") ||
    normalized.includes("drop")
  ) {
    category = "Pickup And Delivery";
  } else if (normalized.includes("ac") || normalized.includes("cooling")) {
    category = "AC Service";
  } else if (normalized.includes("elder") || normalized.includes("hospital")) {
    category = "Elder Or Family Support";
  }

  const urgent = [
    "urgent",
    "emergency",
    "now",
    "asap",
    "leak",
    "short circuit",
    "hospital",
  ].some((word) => normalized.includes(word));

  return {
    category,
    urgency: urgent ? "Urgent" : "Normal",
    confidence: "fallback",
    summary:
      "Backend AI provider is not configured yet, so Workable returned a safe local diagnosis fallback.",
    questions: [
      "What is the exact location?",
      "When should this be handled?",
      "Is there any safety risk right now?",
    ],
  };
}

function smartBookingSchema() {
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      category: {
        type: "string",
        description: "Best marketplace service category for this request.",
      },
      urgency: {
        type: "string",
        enum: ["Normal", "Today", "Urgent"],
        description: "Practical urgency level.",
      },
      confidence: {
        type: "string",
        enum: ["low", "medium", "high"],
        description: "Confidence in the classification.",
      },
      summary: {
        type: "string",
        description: "Short customer-facing diagnosis summary.",
      },
      questions: {
        type: "array",
        minItems: 3,
        maxItems: 5,
        items: {type: "string"},
        description: "Only the most useful follow-up questions.",
      },
      recommendedPath: {
        type: "string",
        enum: ["worker_booking", "help_request", "emergency"],
      },
      priceRange: {
        type: "string",
        description: "Very rough local-market price range or 'Unknown'.",
      },
      safetyNote: {
        type: "string",
        description: "Brief safety guidance. Empty string if not needed.",
      },
    },
    required: [
      "category",
      "urgency",
      "confidence",
      "summary",
      "questions",
      "recommendedPath",
      "priceRange",
      "safetyNote",
    ],
  };
}

function extractOutputText(responseJson) {
  if (typeof responseJson.output_text === "string") {
    return responseJson.output_text;
  }

  const output = Array.isArray(responseJson.output) ? responseJson.output : [];
  for (const item of output) {
    const content = Array.isArray(item.content) ? item.content : [];
    for (const part of content) {
      if (part.type === "output_text" && typeof part.text === "string") {
        return part.text;
      }
    }
  }

  return "";
}

function normalizeOpenAiDiagnosis(parsed, query) {
  const fallback = localAiFallback(query);
  return {
    category: stringValue(parsed.category, fallback.category),
    urgency: ["Normal", "Today", "Urgent"].includes(parsed.urgency)
      ? parsed.urgency
      : fallback.urgency,
    confidence: ["low", "medium", "high"].includes(parsed.confidence)
      ? parsed.confidence
      : "medium",
    summary: stringValue(parsed.summary, fallback.summary),
    questions: Array.isArray(parsed.questions) && parsed.questions.length > 0
      ? parsed.questions
        .map((question) => stringValue(question).trim())
        .filter((question) => question)
        .slice(0, 5)
      : fallback.questions,
    recommendedPath: [
      "worker_booking",
      "help_request",
      "emergency",
    ].includes(parsed.recommendedPath)
      ? parsed.recommendedPath
      : "help_request",
    priceRange: stringValue(parsed.priceRange, "Unknown"),
    safetyNote: stringValue(parsed.safetyNote),
  };
}

async function callOpenAiSmartDiagnosis({apiKey, query}) {
  const model = openAiModel();

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      store: false,
      max_output_tokens: 550,
      reasoning: {effort: "none"},
      instructions:
        "You are Workable's smart booking classifier for a local help " +
        "marketplace. Classify the customer's need, detect urgency, ask " +
        "only necessary follow-up questions, and never claim that a worker " +
        "is available. Do not provide medical, legal, financial, or safety " +
        "guarantees. For dangerous electrical, fire, gas, violence, medical, " +
        "or life-risk cases, recommend emergency help and include a brief " +
        "safety note telling the user to contact local emergency services.",
      input: [
        {
          role: "user",
          content:
            "Customer request: " + query +
            "\nReturn only the structured diagnosis.",
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "workable_smart_booking_diagnosis",
          strict: true,
          schema: smartBookingSchema(),
        },
      },
    }),
  });

  const responseJson = await response.json();
  if (!response.ok) {
    const message =
      responseJson.error && responseJson.error.message
        ? responseJson.error.message
        : "OpenAI diagnosis request failed.";
    throw new Error(message);
  }

  const text = extractOutputText(responseJson);
  const parsed = JSON.parse(text);
  return {
    model,
    diagnosis: normalizeOpenAiDiagnosis(parsed, query),
    usage: responseJson.usage || {},
  };
}

async function recordAiCallResult(uid, dateKey, data) {
  return db
    .collection("aiUsage")
    .doc(uid)
    .collection("days")
    .doc(dateKey)
    .set({
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
}

async function reserveAiQuota(uid, {reason, estimatedTokens}) {
  const dateKey = todayKey();
  const allowance = 3;
  const usageRef = db
    .collection("aiUsage")
    .doc(uid)
    .collection("days")
    .doc(dateKey);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(usageRef);
    const usage = snapshot.exists ? snapshot.data() : {};
    const used = Number(usage.aiCallsUsed || 0);

    if (used >= allowance) {
      transaction.set(
        usageRef,
        {
          uid,
          dateKey,
          dailyAllowance: allowance,
          blockedAiCalls: admin.firestore.FieldValue.increment(1),
          lastBlockedReason: reason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(snapshot.exists
            ? {}
            : {createdAt: admin.firestore.FieldValue.serverTimestamp()}),
        },
        {merge: true}
      );

      return {
        allowed: false,
        remaining: 0,
        dateKey,
        dailyAllowance: allowance,
      };
    }

    transaction.set(
      usageRef,
      {
        uid,
        dateKey,
        dailyAllowance: allowance,
        aiCallsUsed: admin.firestore.FieldValue.increment(1),
        estimatedTokens: admin.firestore.FieldValue.increment(estimatedTokens),
        lastAiReason: reason,
        lastAiReservedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(snapshot.exists
          ? {}
          : {createdAt: admin.firestore.FieldValue.serverTimestamp()}),
      },
      {merge: true}
    );

    return {
      allowed: true,
      remaining: allowance - used - 1,
      dateKey,
      dailyAllowance: allowance,
    };
  });
}

exports.runSmartBookingAiDiagnosis = functions.https.onCall(
  async (data, context) => {
    const uid = requireCallableAuth(context);
    const query = stringValue(data && data.query).trim();
    const reason = stringValue(
      data && data.reason,
      "smart_booking_diagnosis"
    );

    if (query.length < 8) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Please describe the help you need in a little more detail."
      );
    }

    if (query.length > 1200) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Please keep the request shorter than 1200 characters."
      );
    }

    const apiKey = openAiApiKey();

    if (!apiKey) {
      return {
        aiUsed: false,
        providerConfigured: false,
        quotaReserved: false,
        diagnosis: localAiFallback(query),
      };
    }

    const cached = await getCachedSmartDiagnosis(query);
    if (cached) {
      await db.collection("aiUsage").doc(uid).collection("days").doc(todayKey())
        .set({
          uid,
          dateKey: todayKey(),
          cachedAiHits: admin.firestore.FieldValue.increment(1),
          lastCacheKey: cached.cacheKey,
          lastCachedHitAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

      return {
        aiUsed: true,
        providerConfigured: true,
        quotaReserved: false,
        cached: true,
        cacheKey: cached.cacheKey,
        diagnosis: cached.diagnosis,
      };
    }

    const estimated = estimateTokens(query) + 350;
    const quota = await reserveAiQuota(uid, {
      reason,
      estimatedTokens: estimated,
    });

    if (!quota.allowed) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Your Smart Helps for today are finished. You can still use free local matching and normal booking."
      );
    }

    try {
      const aiResult = await callOpenAiSmartDiagnosis({apiKey, query});
      const inputTokens =
        Number(aiResult.usage.input_tokens || aiResult.usage.prompt_tokens || 0);
      const outputTokens = Number(
        aiResult.usage.output_tokens || aiResult.usage.completion_tokens || 0
      );
      const totalTokens = Number(
        aiResult.usage.total_tokens || inputTokens + outputTokens || 0
      );

      await recordAiCallResult(uid, quota.dateKey, {
        lastAiStatus: "success",
        lastAiModel: aiResult.model,
        lastAiInputTokens: inputTokens,
        lastAiOutputTokens: outputTokens,
        lastAiTotalTokens: totalTokens,
        actualTokens: admin.firestore.FieldValue.increment(totalTokens),
      });

      const cacheKey = await saveCachedSmartDiagnosis({
        query,
        diagnosis: aiResult.diagnosis,
        model: aiResult.model,
      });

      return {
        aiUsed: true,
        providerConfigured: true,
        quotaReserved: true,
        cached: false,
        cacheKey: cacheKey || "",
        quota,
        diagnosis: aiResult.diagnosis,
      };
    } catch (error) {
      console.error("Smart booking AI diagnosis failed", {
        uid,
        reason,
        error,
      });

      await recordAiCallResult(uid, quota.dateKey, {
        lastAiStatus: "fallback_after_provider_error",
        failedAiCalls: admin.firestore.FieldValue.increment(1),
        lastAiError: stringValue(error && error.message, "Unknown AI error"),
      });

      return {
        aiUsed: false,
        providerConfigured: true,
        quotaReserved: true,
        quota,
        diagnosis: {
          ...localAiFallback(query),
          summary:
            "The AI provider could not complete the diagnosis, so Workable used a safe backend fallback.",
        },
      };
    }
  }
);

exports.recordSmartDemandSignal = functions.https.onCall(
  async (data, context) => {
    const uid = requireCallableAuth(context);
    const query = requireCleanText(data && data.query, "Search phrase", {
      min: 2,
      max: 180,
    });
    const normalizedQuery = normalizeDemandText(
      data && data.normalizedQuery ? data.normalizedQuery : query
    );
    const guessedCategory = requireCleanText(
      data && data.guessedCategory,
      "Guessed category",
      {min: 2, max: 80}
    );
    const city = requireCleanText(data && data.city, "City", {
      min: 1,
      max: 80,
    });
    const customerName = requireCleanText(
      data && data.customerName ? data.customerName : "Customer",
      "Customer name",
      {min: 1, max: 80}
    );
    const signalId = demandSignalIdFor(normalizedQuery, city);
    const ref = db.collection("demandSignals").doc(signalId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const now = admin.firestore.FieldValue.serverTimestamp();

      if (snapshot.exists) {
        transaction.update(ref, {
          searchCount: admin.firestore.FieldValue.increment(1),
          lastSearchPhrase: query,
          guessedCategory,
          city,
          customerIds: admin.firestore.FieldValue.arrayUnion(uid),
          lastSearchedAt: now,
          updatedAt: now,
          lastSignalSource: "cloud_function",
        });
      } else {
        transaction.set(ref, {
          searchPhrase: query,
          lastSearchPhrase: query,
          normalizedPhrase: normalizedQuery,
          guessedCategory,
          city,
          status: "open",
          searchCount: 1,
          customerIds: [uid],
          firstCustomerId: uid,
          firstCustomerName: customerName,
          source: "customer_search",
          writeSource: "cloud_function",
          adminAction: "pending_category_review",
          createdAt: now,
          lastSearchedAt: now,
          updatedAt: now,
        });
      }
    });

    return {signalId};
  }
);

exports.claimDemandOpportunity = functions.https.onCall(
  async (data, context) => {
    const workerId = requireCallableAuth(context);
    const signalId = requireCleanText(data && data.signalId, "Opportunity", {
      min: 2,
      max: 140,
    });
    const fallbackSkill = requireCleanText(
      data && data.skill ? data.skill : "General Help",
      "Skill",
      {min: 2, max: 100}
    );
    const workerRef = db.collection("workers").doc(workerId);
    const signalRef = db.collection("demandSignals").doc(signalId);

    return db.runTransaction(async (transaction) => {
      const [workerSnapshot, signalSnapshot] = await Promise.all([
        transaction.get(workerRef),
        transaction.get(signalRef),
      ]);

      if (!workerSnapshot.exists) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Worker profile not found."
        );
      }
      if (!signalSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "This opportunity is no longer available."
        );
      }

      const signal = signalSnapshot.data() || {};
      const skill = stringValue(signal.guessedCategory, fallbackSkill).trim() ||
        fallbackSkill;
      const now = admin.firestore.FieldValue.serverTimestamp();

      transaction.update(workerRef, {
        skills: admin.firestore.FieldValue.arrayUnion(skill),
        services: admin.firestore.FieldValue.arrayUnion(skill),
        serviceCategories: admin.firestore.FieldValue.arrayUnion(skill),
        opportunitySignalsClaimed:
          admin.firestore.FieldValue.arrayUnion(signalId),
        profileUpdatedAt: now,
        updatedAt: now,
      });

      transaction.update(
        signalRef,
        "claimedWorkerIds",
        admin.firestore.FieldValue.arrayUnion(workerId),
        new admin.firestore.FieldPath("claimedWorkers", workerId),
        {
          workerId,
          claimedAt: now,
          skillAdded: skill,
          source: "cloud_function",
        },
        "workerInterestCount",
        admin.firestore.FieldValue.increment(1),
        "lastClaimedAt",
        now,
        "updatedAt",
        now
      );

      return {skill};
    });
  }
);

exports.suggestWorkerSignupSkill = functions.https.onCall(
  async (data, context) => {
    const uid = requireCallableAuth(context);
    const skill = requireCleanText(data && data.skill, "Skill", {
      min: 2,
      max: 100,
    });

    await db.collection("skills").doc(skill).set({
      name: skill,
      status: "active",
      source: "worker_signup",
      suggestedByWorkerIds: admin.firestore.FieldValue.arrayUnion(uid),
      lastSeenInWorkerSignup: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {skill};
  }
);

exports.createPayoutRequest = functions.https.onCall(
  async (data, context) => {
    const workerId = requireCallableAuth(context);
    const requestedBookingIds = Array.isArray(data && data.bookingIds) ?
      data.bookingIds.map((id) => stringValue(id).trim()).filter((id) => id) :
      [];

    const workerRef = db.collection("workers").doc(workerId);
    const workerSnapshot = await workerRef.get();
    if (!workerSnapshot.exists) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Worker profile was not found."
      );
    }

    const payout = workerPayoutConfig(workerSnapshot.data() || {});
    if (!validPayoutMethod(payout.method, payout.details)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Add a valid payout method before requesting payout."
      );
    }

    const bookingsSnapshot = await db
      .collection("bookings")
      .where("workerId", "==", workerId)
      .get();

    const candidateRefs = bookingsSnapshot.docs.filter((doc) => {
      if (
        requestedBookingIds.length > 0 &&
        !requestedBookingIds.includes(doc.id)
      ) {
        return false;
      }
      return isPayoutEligibleBooking(doc.data() || {});
    }).map((doc) => doc.ref);

    if (candidateRefs.length === 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No completed paid jobs are available for payout."
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const requestRef = db.collection("payoutRequests").doc();
    let amount = 0;
    let bookingIds = [];

    await db.runTransaction(async (transaction) => {
      const freshWorkerSnapshot = await transaction.get(workerRef);
      if (!freshWorkerSnapshot.exists) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Worker profile was not found."
        );
      }

      const freshPayout = workerPayoutConfig(freshWorkerSnapshot.data() || {});
      if (!validPayoutMethod(freshPayout.method, freshPayout.details)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Add a valid payout method before requesting payout."
        );
      }

      const freshEligible = [];
      for (const bookingRef of candidateRefs) {
        const bookingSnapshot = await transaction.get(bookingRef);
        if (!bookingSnapshot.exists) continue;
        const booking = bookingSnapshot.data() || {};
        if (stringValue(booking.workerId) !== workerId) continue;
        if (!isPayoutEligibleBooking(booking)) continue;
        freshEligible.push({ref: bookingRef, data: booking});
      }

      bookingIds = freshEligible.map((item) => item.ref.id);
      amount = freshEligible.reduce(
        (total, item) => total + bookingWorkerAmount(item.data),
        0
      );

      if (bookingIds.length === 0 || amount <= 0) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "No completed paid jobs are available for payout."
        );
      }

      transaction.set(requestRef, {
        workerId,
        amount,
        bookingIds,
        status: "pending",
        payoutMethod: freshPayout.method,
        payoutDetails: freshPayout.details,
        requestedAt: now,
        updatedAt: now,
        source: "cloud_function",
      });

      freshEligible.forEach((item) => {
        transaction.update(item.ref, {
          payoutStatus: "requested",
          payoutRequestId: requestRef.id,
          payoutRequestedAt: now,
          updatedAt: now,
        });
      });
    });

    await setUserNotification({
      uid: workerId,
      notificationId: notificationIdFor([
        "payout_requested",
        requestRef.id,
      ]),
      title: "Payout request submitted",
      message: `Your payout request for Rs ${amount} is waiting for admin review.`,
      type: "payout_requested",
      notificationCategory: "payout",
      status: "pending",
      requiresAction: false,
      metadata: {
        payoutRequestId: requestRef.id,
        workerId,
        amount: String(amount),
        userRole: "worker",
      },
    });

    return {
      payoutRequestId: requestRef.id,
      amount,
      bookingCount: bookingIds.length,
    };
  }
);

exports.reviewPayoutRequest = functions.https.onCall(
  async (data, context) => {
    const adminId = await requireCallableAdminRole(context, "payment_admin");
    const payoutRequestId = requireCleanText(
      data && data.payoutRequestId,
      "Payout request",
      {min: 2, max: 140}
    );
    const decision = requireCleanText(data && data.decision, "Decision", {
      min: 4,
      max: 20,
    });
    const note = stringValue(data && data.note).trim().slice(0, 300);

    if (!["approved", "rejected"].includes(decision)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Decision must be approved or rejected."
      );
    }

    const requestRef = db.collection("payoutRequests").doc(payoutRequestId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    let workerId = "";
    let amount = 0;
    let bookingIds = [];
    let previousStatus = "";

    await db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Payout request not found."
        );
      }

      const request = requestSnapshot.data() || {};
      const currentStatus = stringValue(request.status, "pending");
      previousStatus = currentStatus;
      if (currentStatus !== "pending") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "This payout request has already been reviewed."
        );
      }

      workerId = stringValue(request.workerId);
      amount = Number(request.amount || 0);
      bookingIds = Array.isArray(request.bookingIds)
        ? request.bookingIds.map((id) => stringValue(id)).filter((id) => id)
        : [];

      if (!workerId || bookingIds.length === 0 || amount <= 0) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Payout request is missing worker, amount, or booking details."
        );
      }

      if (decision === "approved") {
        transaction.update(requestRef, {
          status: "paid",
          approvedBy: adminId,
          approvedAt: now,
          paidAt: now,
          adminNote: note,
          updatedAt: now,
          reviewSource: "cloud_function",
        });

        bookingIds.forEach((bookingId) => {
          transaction.update(db.collection("bookings").doc(bookingId), {
            payoutStatus: "paid",
            payoutPaidAt: now,
            payoutReviewedBy: adminId,
            payoutRequestId,
            updatedAt: now,
          });
        });
      } else {
        transaction.update(requestRef, {
          status: "rejected",
          rejectedBy: adminId,
          rejectedAt: now,
          rejectionReason: note || "Payout request could not be approved.",
          updatedAt: now,
          reviewSource: "cloud_function",
        });

        bookingIds.forEach((bookingId) => {
          transaction.update(db.collection("bookings").doc(bookingId), {
            payoutStatus: "rejected",
            payoutRequestId: admin.firestore.FieldValue.delete(),
            payoutRejectedAt: now,
            payoutReviewedBy: adminId,
            updatedAt: now,
          });
        });
      }
    });

    await writeAdminAuditLog({
      adminId,
      action: "review_payout_request",
      targetCollection: "payoutRequests",
      targetId: payoutRequestId,
      note,
      previousState: {status: previousStatus},
      newState: {
        status: decision === "approved" ? "paid" : "rejected",
        decision,
        amount,
        bookingCount: bookingIds.length,
      },
    });

    await setUserNotification({
      uid: workerId,
      notificationId: notificationIdFor([
        "payout_review",
        payoutRequestId,
        decision,
      ]),
      title: decision === "approved" ? "Payout marked paid" : "Payout rejected",
      message: decision === "approved"
        ? `Your payout of Rs ${amount} was marked as paid.`
        : `Your payout request was rejected${note ? `: ${note}` : "."}`,
      type: "payout_update",
      notificationCategory: "payout",
      status: decision === "approved" ? "paid" : "rejected",
      requiresAction: decision === "rejected",
      metadata: {
        payoutRequestId,
        workerId,
        amount: String(amount),
        userRole: "worker",
      },
    });

    return {
      status: decision === "approved" ? "paid" : "rejected",
      payoutRequestId,
      bookingCount: bookingIds.length,
    };
  }
);

exports.reviewPaymentRequest = functions.https.onCall(
  async (data, context) => {
    const adminId = await requireCallableAdminRole(context, "payment_admin");
    const bookingId = requireCleanText(data && data.bookingId, "Booking", {
      min: 2,
      max: 140,
    });
    const decision = requireCleanText(data && data.decision, "Decision", {
      min: 4,
      max: 20,
    });
    const note = stringValue(data && data.note).trim().slice(0, 300);

    if (!["approved", "rejected"].includes(decision)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Decision must be approved or rejected."
      );
    }

    const bookingRef = db.collection("bookings").doc(bookingId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    let helpRequestId = "";
    let previousStatus = "";
    let previousPaymentStatus = "";

    await db.runTransaction(async (transaction) => {
      const bookingSnapshot = await transaction.get(bookingRef);
      if (!bookingSnapshot.exists) {
        throw new functions.https.HttpsError("not-found", "Booking not found.");
      }

      const booking = bookingSnapshot.data() || {};
      const paymentStatus = stringValue(booking.paymentStatus);
      const status = stringValue(booking.status);
      previousStatus = status;
      previousPaymentStatus = paymentStatus;
      const reviewable = status === "payment_under_review" ||
        paymentStatus === "customer_reported_paid" ||
        paymentStatus === "cash_pending_confirmation" ||
        paymentStatus === "payment_under_review";

      if (!reviewable) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "This booking is not waiting for payment review."
        );
      }

      helpRequestId = stringValue(booking.sourceHelpRequestId);
      if (decision === "approved") {
        const approvedData = {
          status: "completed",
          paymentStatus: "paid",
          paymentReviewStatus: "approved",
          paymentReviewedBy: adminId,
          paymentReviewerRole: "admin",
          paymentReviewNote: note || "Admin approved payment review.",
          paidAt: now,
          completedAt: now,
          "timeline.paid": now,
          "timeline.completed": now,
          updatedAt: now,
          paymentReviewSource: "cloud_function",
        };

        transaction.update(bookingRef, approvedData);
        if (helpRequestId) {
          transaction.update(db.collection("helpRequests").doc(helpRequestId), {
            ...approvedData,
          });
        }
      } else {
        const reason = note || "Payment could not be verified.";
        const rejectedData = {
          status: "payment_due",
          paymentStatus: "payment_rejected",
          paymentReviewStatus: "rejected",
          paymentReviewedBy: adminId,
          paymentReviewerRole: "admin",
          paymentRejectionReason: reason,
          paymentRejectedAt: now,
          updatedAt: now,
          paymentReviewSource: "cloud_function",
        };

        transaction.update(bookingRef, rejectedData);
        if (helpRequestId) {
          transaction.update(db.collection("helpRequests").doc(helpRequestId), {
            ...rejectedData,
          });
        }
      }
    });

    await writeAdminAuditLog({
      adminId,
      action: "review_payment_request",
      targetCollection: "bookings",
      targetId: bookingId,
      note,
      previousState: {
        status: previousStatus,
        paymentStatus: previousPaymentStatus,
      },
      newState: {
        status: decision === "approved" ? "completed" : "payment_due",
        paymentStatus: decision === "approved" ? "paid" : "payment_rejected",
        decision,
        helpRequestId,
      },
    });

    const transactionSnapshot = await db
      .collection("transactions")
      .where("bookingId", "==", bookingId)
      .get();
    if (!transactionSnapshot.empty) {
      const batch = db.batch();
      transactionSnapshot.docs.forEach((doc) => {
        const transactionUpdate = {
          status: decision === "approved" ? "paid" : "payment_rejected",
          paymentReviewStatus: decision,
          paymentReviewedBy: adminId,
          paymentReviewerRole: "admin",
          updatedAt: now,
        };
        if (decision === "approved") {
          transactionUpdate.paymentReviewNote = note;
          transactionUpdate.paidAt = now;
        } else {
          transactionUpdate.paymentRejectionReason =
            note || "Payment could not be verified.";
        }
        batch.update(doc.ref, transactionUpdate);
      });
      await batch.commit();
    }

    return {
      status: decision === "approved" ? "paid" : "payment_rejected",
      bookingId,
      helpRequestId,
    };
  }
);

exports.notifyOnHelpRequestAccepted = functions.firestore
  .document("helpRequests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {requestId} = context.params;

    if (before.status === "accepted" || after.status !== "accepted") {
      return null;
    }

    const customerId = stringValue(after.customerId);
    const workerId = stringValue(after.workerId || after.acceptedWorkerId);
    const workerName = stringValue(after.workerName, "A worker");
    const bookingId = stringValue(after.linkedBookingId);
    if (!customerId || !workerId) return null;

    return setUserNotification({
      uid: customerId,
      notificationId: notificationIdFor([
        "help_request_accepted",
        requestId,
        workerId,
      ]),
      title: "Help request accepted",
      message: `${workerName} accepted your help request.`,
      type: "help_request_accepted",
      notificationCategory: "help_request",
      status: "accepted",
      requiresAction: true,
      metadata: {
        helpRequestId: requestId,
        bookingId,
        workerId,
        workerName,
        userRole: "customer",
      },
    });
  });

exports.notifyOnLinkedHelpBookingUpdate = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {bookingId} = context.params;
    const helpRequestId = stringValue(after.sourceHelpRequestId);
    if (!helpRequestId) return null;

    const customerId = stringValue(after.customerId);
    const workerId = stringValue(after.workerId);
    const service = textFrom(after, ["service", "serviceType"], "help request");
    const tasks = [];

    const statusBefore = stringValue(before.status);
    const statusAfter = stringValue(after.status);
    const paymentBefore = stringValue(before.paymentStatus);
    const paymentAfter = stringValue(after.paymentStatus);

    if (statusBefore !== statusAfter) {
      if (statusAfter === "in_progress" && customerId) {
        tasks.push(setUserNotification({
          uid: customerId,
          notificationId: notificationIdFor([
            "help_work_started",
            bookingId,
            statusAfter,
          ]),
          title: "Help work started",
          message: `Your worker has started: ${service}.`,
          type: "help_request_work_started",
          notificationCategory: "help_request",
          status: "in_progress",
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "customer",
          },
        }));
      }

      if (statusAfter === "completion_requested" && customerId) {
        tasks.push(setUserNotification({
          uid: customerId,
          notificationId: notificationIdFor([
            "help_completion_requested",
            bookingId,
          ]),
          title: "Confirm completed help",
          message: `Your worker marked ${service} as completed. Please review it.`,
          type: "help_request_completion_requested",
          notificationCategory: "help_request",
          status: "completion_requested",
          requiresAction: true,
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "customer",
          },
        }));
      }

      if (statusAfter === "payment_due" && workerId) {
        tasks.push(setUserNotification({
          uid: workerId,
          notificationId: notificationIdFor([
            "help_completion_confirmed",
            bookingId,
          ]),
          title: "Customer confirmed completion",
          message: `The customer confirmed ${service}. Payment can now be handled.`,
          type: "help_request_completion_confirmed",
          notificationCategory: "help_request",
          status: "payment_due",
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "worker",
          },
        }));
      }

      if (statusAfter === "completion_disputed" && workerId) {
        tasks.push(setUserNotification({
          uid: workerId,
          notificationId: notificationIdFor([
            "help_completion_disputed",
            bookingId,
          ]),
          title: "Help request disputed",
          message: `The customer reported an issue with ${service}.`,
          type: "help_request_completion_disputed",
          notificationCategory: "help_request",
          status: "completion_disputed",
          requiresAction: true,
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "worker",
          },
        }));
      }
    }

    if (paymentBefore !== paymentAfter) {
      if (paymentAfter === "cash_pending_confirmation" && workerId) {
        tasks.push(setUserNotification({
          uid: workerId,
          notificationId: notificationIdFor([
            "help_cash_pending",
            bookingId,
          ]),
          title: "Customer selected cash",
          message: `The customer selected cash for ${service}. Confirm only after receiving it.`,
          type: "help_request_cash_pending",
          notificationCategory: "help_request",
          status: statusAfter,
          requiresAction: true,
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "worker",
          },
        }));
      }

      if (paymentAfter === "customer_reported_paid" && workerId) {
        tasks.push(setUserNotification({
          uid: workerId,
          notificationId: notificationIdFor([
            "help_payment_reported",
            bookingId,
          ]),
          title: "Customer reported payment",
          message: `The customer reported UPI payment for ${service}. It is under review.`,
          type: "help_request_payment_reported",
          notificationCategory: "help_request",
          status: statusAfter,
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "worker",
          },
        }));
      }

      if (paymentAfter === "paid") {
        if (customerId) {
          tasks.push(setUserNotification({
            uid: customerId,
            notificationId: notificationIdFor([
              "help_payment_approved_customer",
              bookingId,
            ]),
            title: "Help request completed",
            message: `Payment for ${service} was confirmed. Your request is completed.`,
            type: "help_request_payment_approved",
            notificationCategory: "help_request",
            status: "completed",
            metadata: {
              helpRequestId,
              bookingId,
              userRole: "customer",
            },
          }));
        }
        if (workerId) {
          tasks.push(setUserNotification({
            uid: workerId,
            notificationId: notificationIdFor([
              "help_payment_approved_worker",
              bookingId,
            ]),
            title: "Payment confirmed",
            message: `Payment for ${service} was approved and marked completed.`,
            type: "help_request_payment_approved",
            notificationCategory: "help_request",
            status: "completed",
            metadata: {
              helpRequestId,
              bookingId,
              userRole: "worker",
            },
          }));
        }
      }

      if (paymentAfter === "payment_rejected" && customerId) {
        const reason = stringValue(after.paymentRejectionReason, "Please review payment details.");
        tasks.push(setUserNotification({
          uid: customerId,
          notificationId: notificationIdFor([
            "help_payment_rejected",
            bookingId,
          ]),
          title: "Payment needs attention",
          message: `Payment for ${service} was rejected: ${reason}`,
          type: "help_request_payment_rejected",
          notificationCategory: "help_request",
          status: "payment_rejected",
          requiresAction: true,
          metadata: {
            helpRequestId,
            bookingId,
            userRole: "customer",
          },
        }));
      }
    }

    await Promise.all(tasks);
    return null;
  });

exports.notifyOnDemandApproved = functions.firestore
  .document("demandSignals/{signalId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {signalId} = context.params;

    if (before.status === "approved" || after.status !== "approved") {
      return null;
    }

    const categoryName = textFrom(after, ["approvedCategory", "guessedCategory"], "New category");
    const searchPhrase = textFrom(after, ["lastSearchPhrase", "searchPhrase"], "your search");
    const customerIds = Array.isArray(after.customerIds) ? after.customerIds : [];
    const claimedWorkerIds = Array.isArray(after.claimedWorkerIds) ?
      after.claimedWorkerIds : [];
    const matchingWorkerIds = await workerIdsForCategory(categoryName);
    const workerIds = Array.from(new Set([
      ...claimedWorkerIds.map((id) => stringValue(id)),
      ...matchingWorkerIds,
    ])).filter((id) => id);

    const tasks = [];
    customerIds.forEach((customerId) => {
      tasks.push(setUserNotification({
        uid: stringValue(customerId),
        notificationId: notificationIdFor([
          "demand_category_approved_customer",
          signalId,
          customerId,
        ]),
        title: `${categoryName} is now available`,
        message: `Workable approved a new category based on your search for "${searchPhrase}".`,
        type: "demand_category_approved",
        notificationCategory: "demand_discovery",
        status: "approved",
        metadata: {
          demandSignalId: signalId,
          categoryName,
          searchPhrase,
        },
      }));
    });

    workerIds.forEach((workerId) => {
      tasks.push(setUserNotification({
        uid: stringValue(workerId),
        notificationId: notificationIdFor([
          "demand_category_approved_worker",
          signalId,
          workerId,
        ]),
        title: "New category approved",
        message: `${categoryName} is now an approved Workable category. Update your pricing and availability if you can accept this work.`,
        type: "worker_category_opportunity",
        notificationCategory: "worker_opportunity",
        status: "approved",
        requiresAction: true,
        metadata: {
          demandSignalId: signalId,
          categoryName,
          searchPhrase,
        },
      }));
    });

    await Promise.all(tasks);
    return null;
  });

exports.notifyOnVerificationReview = functions.firestore
  .document("adminVerificationQueue/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {requestId} = context.params;
    const statusBefore = stringValue(before.status);
    const statusAfter = stringValue(after.status);

    if (statusBefore === statusAfter ||
      !["verified", "rejected"].includes(statusAfter)) {
      return null;
    }

    const uid = stringValue(after.uid);
    const documentId = stringValue(after.documentType || after.documentId);
    if (!uid || !documentId) return null;

    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("users").doc(uid);
    const verificationRef = userRef
      .collection("identityVerification")
      .doc(documentId);
    const notificationId = notificationIdFor([
      "verification_review",
      requestId,
      statusAfter,
    ]);
    const rejectionReason = stringValue(
      after.rejectionReason,
      "Please reupload a clearer document."
    );
    const title = statusAfter === "verified" ?
      "Verification approved" :
      "Verification needs attention";
    const message = statusAfter === "verified" ?
      `${documentId} verification approved successfully.` :
      rejectionReason;

    const batch = db.batch();
    batch.set(verificationRef, {
      status: statusAfter,
      reviewedAt: now,
      ...(statusAfter === "verified"
        ? {
          verifiedAt: now,
          rejectionReason: admin.firestore.FieldValue.delete(),
        }
        : {rejectionReason}),
    }, {merge: true});

    if (statusAfter === "rejected") {
      const verificationSnapshot = await verificationRef.get();
      batch.set(userRef.collection("verificationNotificationHistory").doc(), {
        documentId,
        status: "rejected",
        version: 1,
        rejectionReason,
        documentSnapshot: verificationSnapshot.data() || {},
        createdAt: now,
        source: "cloud_function",
      });
    }

    batch.set(userRef.collection("notifications").doc(notificationId), {
      version: 1,
      title,
      message,
      body: message,
      type: "verification",
      documentId,
      status: statusAfter,
      requiresAction: statusAfter === "rejected",
      notificationCategory: "verification_workflow",
      category: "verification_workflow",
      metadata: {
        documentId,
        userRole: "customer",
      },
      isRead: false,
      read: false,
      createdAt: now,
      updatedAt: now,
      source: "cloud_function",
    }, {merge: true});

    await batch.commit();
    await syncWorkerVisibility(uid);
    return null;
  });

exports.notifyCustomerOnWorkStarted = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {bookingId} = context.params;

    const statusBefore = stringValue(before.status);
    const statusAfter = stringValue(after.status);
    if (statusBefore === "in_progress" || statusAfter !== "in_progress") {
      return null;
    }

    const customerId = stringValue(after.customerId);
    const workerId = stringValue(after.workerId);
    if (!customerId) return null;

    const workerName = textFrom(after, ["workerName"], "Your worker");
    const service = textFrom(after, ["service", "serviceType"], "service");
    const initiatedBy = stringValue(after.startWorkInitiatedBy, "worker");
    const distance = Number(after.startWorkDistanceMeters);
    const locationText = Number.isFinite(distance) ?
      ` Location verified within ${Math.round(distance)} m.` :
      "";
    const notificationId = notificationIdFor([
      "work_started",
      bookingId,
      customerId,
    ]);

    await setUserNotification({
      uid: customerId,
      notificationId,
      title: initiatedBy === "admin" ? "Work started by support" : "Work started",
      message: initiatedBy === "customer" ?
        `You confirmed ${workerName} arrived and started your ${service}.` :
        `${workerName} has started your ${service}.${locationText}`,
      type: "booking_update",
      notificationCategory: "booking_workflow",
      status: "in_progress",
      requiresAction: false,
      metadata: {
        bookingId,
        workerId,
        userRole: "customer",
        route: "customer_booking_detail",
      },
    });

    if (workerId && initiatedBy !== "worker") {
      await setUserNotification({
        uid: workerId,
        notificationId: notificationIdFor([
          "worker_work_started",
          bookingId,
          workerId,
          initiatedBy,
        ]),
        title: "Work started",
        message: initiatedBy === "admin" ?
          `Support started this ${service} after customer confirmation.` :
          `The customer confirmed your arrival and started this ${service}.`,
        type: "booking_update",
        notificationCategory: "booking_workflow",
        status: "in_progress",
        requiresAction: false,
        metadata: {
          bookingId,
          workerId,
          userRole: "worker",
          route: "worker_job_detail",
        },
      });
    }

    return null;
  });

exports.notifyCustomerToReviewBooking = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const {bookingId} = context.params;

    const statusBefore = stringValue(before.status);
    const statusAfter = stringValue(after.status);
    const paymentBefore = stringValue(before.paymentStatus);
    const paymentAfter = stringValue(after.paymentStatus);
    const becameCompleted =
      statusBefore !== "completed" && statusAfter === "completed";
    const becamePaid = paymentBefore !== "paid" && paymentAfter === "paid";
    if (!becameCompleted && !becamePaid) return null;

    const customerId = stringValue(after.customerId);
    const workerId = stringValue(after.workerId);
    if (!customerId || !workerId) return null;

    const workerName = stringValue(after.workerName, "your worker");
    const service = textFrom(after, ["service", "serviceType", "issue"], "service");
    const tasks = [];

    if (after.hasReview !== true) {
      tasks.push(setUserNotification({
        uid: customerId,
        notificationId: notificationIdFor([
          "review_request",
          bookingId,
          customerId,
        ]),
        title: "How was the service?",
        message: `Please rate ${workerName} for ${service}. Your review helps other customers choose trusted help.`,
        type: "review_request",
        notificationCategory: "review",
        status: "pending_review",
        requiresAction: true,
        metadata: {
          bookingId,
          workerId,
          workerName,
          service,
          userRole: "customer",
        },
      }));
    }

    if (paymentAfter === "paid") {
      const couponId = stringValue(after.couponId);
      if (couponId) {
        tasks.push(markCouponRedeemed({
          customerId,
          couponId,
          bookingId,
          transactionId: stringValue(after.paymentReference),
        }));
      }

      tasks.push(createRepeatServiceCoupon({
        bookingId,
        booking: after,
        customerId,
        workerId,
        service,
      }));

      tasks.push(unlockReferralRewardForCustomer({
        customerId,
        bookingId,
        booking: after,
      }));
    }

    tasks.push(syncWorkerAchievement(workerId, new Date()));

    return Promise.all(tasks);
  });

exports.trackReferralConversionOnUserUpdate = functions.firestore
  .document("users/{uid}")
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() || {} : null;
    if (!after) return null;

    const before = change.before.exists ? change.before.data() || {} : {};
    const beforeCode = normalizeReferralCode(before.referredByCode);
    const afterCode = normalizeReferralCode(after.referredByCode);
    if (!afterCode || beforeCode === afterCode) return null;

    return createReferralConversionForUser(context.params.uid, {
      ...after,
      referredByCode: afterCode,
    });
  });

exports.sendPushOnNotificationCreate = functions.firestore
  .document("users/{uid}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const {uid, notificationId} = context.params;
    const notification = snap.data() || {};
    return sendPushToUser(uid, notification, notificationId);
  });

// 🔔 Chat Message Notification
exports.sendMessageNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const {chatId, messageId} = context.params;
    const receiverId = message.receiverId;

    return createUserNotification({
      uid: receiverId,
      title: message.senderName || "New Message",
      message: message.text || "You received a message",
      type: "chat_message",
      notificationCategory: "chat",
      metadata: {
        chatId,
        messageId,
        chatWithId: message.senderId,
        chatWithName: message.senderName,
        userRole: message.receiverRole,
        bookingId: message.bookingId,
      },
    });
  });

// 📅 Booking Notification
exports.notifyWorkerOnBooking = functions.firestore
  .document("bookings/{bookingId}")
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const {bookingId} = context.params;
    const workerId = booking.workerId;

    return createUserNotification({
      uid: workerId,
      title: "New Booking",
      message: `You have a new booking for ${booking.service || "a service"}`,
      type: "booking_update",
      notificationCategory: "booking",
      requiresAction: true,
      metadata: {
        bookingId,
        customerId: booking.customerId,
        customerName: booking.customerName,
        service: booking.service || booking.serviceType,
      },
    });
  });

// 🌟 Review Notification
exports.notifyWorkerOnReview = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snap, context) => {
    const review = snap.data();
    const {reviewId} = context.params;
    const workerId = review.workerId;

    return createUserNotification({
      uid: workerId,
      title: "New Review Received",
      message: `You received a ${review.rating}-star review.`,
      type: "review_update",
      notificationCategory: "review",
      metadata: {
        reviewId,
        bookingId: review.bookingId,
        workerId,
        rating: review.rating,
      },
    });
  });

// 📊 Auto-calculate average rating and review count
exports.updateWorkerRating = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap, context) => {
    const newReview = snap.data();
    const workerId = newReview.workerId;

    if (!workerId || typeof newReview.rating !== 'number') {
      console.warn('Missing workerId or rating in review');
      return null;
    }

    const reviewsSnapshot = await db
      .collection('reviews')
      .where('workerId', '==', workerId)
      .get();

    const ratings = reviewsSnapshot.docs
      .map(doc => doc.data().rating)
      .filter(r => typeof r === 'number');

    if (ratings.length === 0) return null;

    const average =
      ratings.reduce((sum, r) => sum + r, 0) / ratings.length;

    const roundedAverage = Math.round(average * 10) / 10;

    // Update worker document securely
    await db
      .collection('workers')
      .doc(workerId)
      .update({
        averageRating: roundedAverage,
        reviewCount: ratings.length,
      });

    await syncWorkerAchievement(workerId, new Date());

    console.log(
      `Worker ${workerId} updated with avg: ${roundedAverage}, count: ${ratings.length}`
    );

    return null;
  });
