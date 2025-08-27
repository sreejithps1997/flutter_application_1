const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// 🔔 Chat Message Notification
exports.sendMessageNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const receiverId = message.receiverId;

    const userDoc = await db.collection("users").doc(receiverId).get();
    const userData = userDoc.data();
    const fcmToken = userData && userData.fcmToken;
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: message.senderName || "New Message",
        body: message.text || "You received a message",
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
  });

// 📅 Booking Notification
exports.notifyWorkerOnBooking = functions.firestore
  .document("bookings/{bookingId}")
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const workerId = booking.workerId;

    const userDoc = await db.collection("users").doc(workerId).get();
    const userData = userDoc.data();
    const fcmToken = userData && userData.fcmToken;
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: "New Booking",
        body: `You have a new booking for ${booking.service || "a service"}`,
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
  });

// 🌟 Review Notification
exports.notifyWorkerOnReview = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snap, context) => {
    const review = snap.data();
    const workerId = review.workerId;

    const userDoc = await db.collection("users").doc(workerId).get();
    const userData = userDoc.data();
    const fcmToken = userData && userData.fcmToken;
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: "New Review Received",
        body: `You received a ${review.rating}-star review.`,
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
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

    console.log(
      `Worker ${workerId} updated with avg: ${roundedAverage}, count: ${ratings.length}`
    );

    return null;
  });

