const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Accepts a trade offer: locks any escrow coins, opens the handover
 * transaction (with its OTP verification codes), and marks the offer and
 * both listings as in-progress — all atomically, and now enforced
 * server-side instead of trusted to the client.
 *
 * Callable from Flutter as:
 *   FirebaseFunctions.instance.httpsCallable('acceptTradeOffer')
 *       .call({offerId, listingId, roomId});
 *
 * `listingId` is only cross-checked against the offer's own
 * `target_listing_id` (belt-and-suspenders — a mismatch usually means a
 * stale client); every ID actually used to decide what gets mutated is
 * read from the offer document itself, never taken as-is from the caller.
 * `roomId` is optional — pass it to also post the "offer accepted" system
 * message into that chat room's timeline, same as the old client-side flow.
 */
exports.acceptTradeOffer = onCall(async (request) => {
  // a) Must be signed in.
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "กรุณาล็อกอินก่อนทำรายการ");
  }
  const callerId = request.auth.uid;

  const offerId = request.data && request.data.offerId;
  const listingId = request.data && request.data.listingId;
  const roomId = request.data && request.data.roomId;

  if (!offerId || typeof offerId !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุ offerId");
  }

  const db = admin.firestore();

  try {
    const result = await db.runTransaction(async (transaction) => {
      // --- Reads (all of them, before any write — Firestore transactions
      // require every read to happen before the first write) ---

      // b) Fetch the offer.
      const offerRef = db.collection("offers").doc(offerId);
      const offerSnap = await transaction.get(offerRef);
      if (!offerSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลข้อเสนอ");
      }
      const offer = offerSnap.data();

      if (offer.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "ข้อเสนอนี้ถูกดำเนินการไปแล้ว"
        );
      }

      const senderId = offer.sender_id;
      const targetUserId = offer.target_user_id;
      const targetListingId = offer.target_listing_id;
      const offeredListingId = offer.offered_listing_id;

      if (listingId && listingId !== targetListingId) {
        throw new HttpsError(
          "invalid-argument",
          "listingId ไม่ตรงกับข้อเสนอนี้"
        );
      }

      // ...and the associated (target) listing.
      const listingRef = db.collection("listings").doc(targetListingId);
      const listingSnap = await transaction.get(listingRef);
      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสิ่งของ");
      }
      const listing = listingSnap.data();

      // c) The caller must be the listing's actual owner — this is the
      // security fix: previously any signed-in user could call the
      // client-side equivalent of this on someone else's offer.
      if (listing.owner_id !== callerId) {
        throw new HttpsError(
          "permission-denied",
          "คุณไม่มีสิทธิ์ตอบรับข้อเสนอนี้"
        );
      }

      const offeredListingRef = db.collection("listings").doc(offeredListingId);
      const offeredListingSnap = await transaction.get(offeredListingRef);
      if (!offeredListingSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสิ่งของที่นำมาแลก");
      }

      const coinOffset = offer.coin_offset || 0;
      let payerId = null;
      let amountToPay = 0;
      if (coinOffset > 0) {
        payerId = senderId;
        amountToPay = coinOffset;
      } else if (coinOffset < 0) {
        payerId = targetUserId;
        amountToPay = Math.abs(coinOffset);
      }

      let payerRef = null;
      let newBalance = 0;
      if (payerId && amountToPay > 0) {
        payerRef = db.collection("users").doc(payerId);
        const payerSnap = await transaction.get(payerRef);
        if (!payerSnap.exists) {
          throw new HttpsError("not-found", "ไม่พบข้อมูลผู้ใช้งาน");
        }
        const currentBalance = payerSnap.data().coins_balance || 0;
        if (currentBalance < amountToPay) {
          throw new HttpsError(
            "failed-precondition",
            "ยอดเหรียญของฝั่งที่ต้องจ่ายไม่เพียงพอ"
          );
        }
        newBalance = currentBalance - amountToPay;
      }

      // The accepter's display name, resolved server-side — never trust a
      // client-supplied name for a message written into shared chat as if
      // from "the system."
      const callerSnap = await transaction.get(
        db.collection("users").doc(callerId)
      );
      const callerName = callerSnap.exists
        ? callerSnap.data().name || "ผู้ใช้งาน"
        : "ผู้ใช้งาน";

      // --- Writes ---

      if (payerRef) {
        transaction.update(payerRef, { coins_balance: newBalance });
        const walletTxRef = db.collection("wallet_transactions").doc();
        transaction.set(walletTxRef, {
          log_id: walletTxRef.id,
          user_id: payerId,
          amount: -amountToPay,
          balance_after: newBalance,
          type: "escrow_lock",
          status: "success",
          reference_id: offerId,
          description: "หักเหรียญเข้ากองกลางสำหรับข้อเสนอแลกเปลี่ยน",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const code1 = (100000 + (Date.now() % 400000)).toString();
      const code2 = (500000 + (Date.now() % 400000)).toString();

      const mainTxRef = db.collection("transactions").doc();
      transaction.set(mainTxRef, {
        transaction_id: mainTxRef.id,
        offer_id: offerId,
        listings: [offeredListingId, targetListingId],
        members: [senderId, targetUserId],
        escrow_coins: amountToPay,
        status: "in_progress",
        cancel_reason: "",
        verification_codes: { [senderId]: code1, [targetUserId]: code2 },
        confirmed_by_user_ids: [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // d) Atomically flip the offer and both listings to their
      // in-progress state (this app's existing "locked" equivalent — see
      // TransactionRepository, which moves listings to 'completed' only
      // once both sides confirm the handover with their OTP code).
      transaction.update(offerRef, { status: "accepted" });
      transaction.update(listingRef, { status: "in_progress" });
      transaction.update(offeredListingRef, { status: "in_progress" });

      if (roomId) {
        const roomRef = db.collection("chat_rooms").doc(roomId);
        transaction.update(roomRef, {
          last_message_type: "system_accept",
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        const msgRef = roomRef.collection("messages").doc();
        transaction.set(msgRef, {
          sender_id: "system",
          content: `${callerName} ได้ตกลงรับข้อเสนอแลกเปลี่ยนแล้ว`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: "system_accept",
        });
      }

      return { transactionId: mainTxRef.id };
    });

    return { success: true, transactionId: result.transactionId };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error(`acceptTradeOffer failed for offer ${offerId}: ${error.message}`);
    throw new HttpsError("internal", "เกิดข้อผิดพลาดในการรับข้อเสนอ");
  }
});

/**
 * Notifies a listing's owner whenever someone makes a new offer on it.
 *
 * Firestore trigger: offers/{offerId} onCreate.
 *
 * The offer doc already denormalizes `target_user_id` (copied from the
 * listing's `owner_id` at offer-creation time by the Flutter client), so
 * that alone could tell us who to notify without a second read. This still
 * resolves the owner via the listing doc instead, which is the more
 * defensive choice: it stays correct even if that denormalized field is
 * ever dropped, or if listing ownership can change independently of the
 * offer later on.
 */
exports.onNewOfferCreated = onDocumentCreated(
  "offers/{offerId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("onNewOfferCreated: event had no document snapshot.");
      return;
    }

    const offerId = event.params.offerId;
    const offer = snap.data();

    const listingId = offer.target_listing_id;
    const senderId = offer.sender_id;

    if (!listingId || !senderId) {
      logger.warn(
        `onNewOfferCreated: offer ${offerId} is missing target_listing_id/sender_id, skipping.`
      );
      return;
    }

    const db = admin.firestore();

    // 1. Fetch the listing to find its owner — the person to notify.
    const listingSnap = await db.collection("listings").doc(listingId).get();
    if (!listingSnap.exists) {
      logger.warn(
        `onNewOfferCreated: listing ${listingId} not found for offer ${offerId}, skipping.`
      );
      return;
    }
    const listing = listingSnap.data();
    const ownerId = listing.owner_id;
    if (!ownerId) {
      logger.warn(
        `onNewOfferCreated: listing ${listingId} has no owner_id, skipping.`
      );
      return;
    }

    // Shouldn't normally happen — the app already blocks offering on your
    // own listing — but cheap to guard against notifying yourself.
    if (ownerId === senderId) return;

    // 2. Fetch the owner's doc for their push token.
    const ownerSnap = await db.collection("users").doc(ownerId).get();
    if (!ownerSnap.exists) {
      logger.warn(`onNewOfferCreated: owner ${ownerId} not found, skipping.`);
      return;
    }
    const owner = ownerSnap.data();
    const fcmToken = owner.fcm_token;
    if (!fcmToken) {
      logger.info(
        `onNewOfferCreated: owner ${ownerId} has no fcm_token saved, skipping.`
      );
      return;
    }

    // Best-effort personalization — a missing sender name/listing title
    // only makes the notification text blander, never breaks the send.
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = senderSnap.exists
      ? senderSnap.data().name || "ผู้ใช้งาน"
      : "ผู้ใช้งาน";
    const listingTitle = listing.title || "สิ่งของของคุณ";

    const message = {
      token: fcmToken,
      notification: {
        title: "มีข้อเสนอใหม่! 🎉",
        body: `${senderName} ยื่นข้อเสนอแลกเปลี่ยนสำหรับ "${listingTitle}" ของคุณ`,
      },
      data: {
        type: "new_offer",
        offer_id: offerId,
        listing_id: listingId,
      },
      // Matches the Android notification channel already registered
      // client-side in NotificationService, so foreground/background
      // rendering behaves consistently.
      android: {
        notification: { channelId: "give_and_take_channel" },
      },
    };

    // 3. Send it. A dead token (uninstalled app, revoked, etc.) fails
    // forever otherwise — clear it instead of leaving future offers to
    // keep retrying a send that will never succeed.
    try {
      await admin.messaging().send(message);
      logger.info(
        `onNewOfferCreated: notified owner ${ownerId} of offer ${offerId}.`
      );
    } catch (error) {
      logger.error(
        `onNewOfferCreated: failed to notify owner ${ownerId} for offer ${offerId}: ${error.message}`
      );
      if (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
      ) {
        await db
          .collection("users")
          .doc(ownerId)
          .update({ fcm_token: admin.firestore.FieldValue.delete() });
        logger.info(
          `onNewOfferCreated: cleared stale fcm_token for user ${ownerId}.`
        );
      }
    }
  }
);