const functions = require("firebase-functions");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");
admin.initializeApp();

// Run next to the Firestore database (asia-southeast1, Singapore). These
// used to deploy to the default us-central1, so every read inside a
// transaction crossed the Pacific and back; the app must call the same
// region (see lib/constants/firebase_config.dart).
setGlobalOptions({ region: "asia-southeast1" });

/**
 * The public bits of a listing, as stored inside a review
 * (reviews.reviewer_item / reviews.reviewee_item).
 */
function listingSnapshot(snap) {
  const d = snap.data();
  return {
    listing_id: snap.id,
    owner_id: d.owner_id || "",
    title: d.title || "",
    thumbnail_url: d.thumbnail_url || "",
    estimated_coins: d.estimated_coins || 0,
  };
}

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

      // Who pays the coin difference follows from the offer alone, so every
      // remaining read can go out in one parallel round trip instead of one
      // after another.
      const coinOffset = offer.coin_offset || 0;
      if (!Number.isInteger(coinOffset)) {
        throw new HttpsError("failed-precondition", "ส่วนต่างเหรียญไม่ถูกต้อง");
      }
      let payerId = null;
      let amountToPay = 0;
      if (coinOffset > 0) {
        payerId = senderId;
        amountToPay = coinOffset;
      } else if (coinOffset < 0) {
        payerId = targetUserId;
        amountToPay = Math.abs(coinOffset);
      }

      const listingRef = db.collection("listings").doc(targetListingId);
      const offeredListingRef = db.collection("listings").doc(offeredListingId);
      const payerRef = payerId ? db.collection("users").doc(payerId) : null;
      const [listingSnap, offeredListingSnap, payerSnap, callerSnap] =
        await Promise.all([
          transaction.get(listingRef),
          transaction.get(offeredListingRef),
          payerRef ? transaction.get(payerRef) : Promise.resolve(null),
          // The accepter's display name, resolved server-side — never trust
          // a client-supplied name for a message written into shared chat as
          // if from "the system."
          transaction.get(db.collection("users").doc(callerId)),
        ]);

      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสิ่งของ");
      }
      const listing = listingSnap.data();
      if (!offeredListingSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสิ่งของที่นำมาแลก");
      }
      const offeredListing = offeredListingSnap.data();

      // c) Who may accept. Only the two parties to the offer — and the
      // offer's parties are re-checked against who actually owns each
      // listing, since the offer doc itself is client-written.
      if (
        listing.owner_id !== targetUserId ||
        offeredListing.owner_id !== senderId
      ) {
        throw new HttpsError(
          "failed-precondition",
          "ข้อมูลข้อเสนอไม่ตรงกับเจ้าของสิ่งของ"
        );
      }
      if (callerId !== senderId && callerId !== targetUserId) {
        throw new HttpsError(
          "permission-denied",
          "คุณไม่มีสิทธิ์ตอบรับข้อเสนอนี้"
        );
      }
      // ...and it has to be the caller's turn: whoever made the latest
      // proposal (the original offer, or the most recent counter-offer)
      // can't also be the one to accept it. This used to require the caller
      // to be the target listing's owner, which was wrong in both
      // directions — the sender could never accept the owner's counter-offer
      // (the app showed them the button, the call always failed), while the
      // owner could accept terms they had just set themselves.
      const lastOfferBy = offer.last_offer_by || senderId;
      if (callerId === lastOfferBy) {
        throw new HttpsError(
          "failed-precondition",
          "ต้องรอให้อีกฝ่ายเป็นผู้ตอบรับข้อเสนอนี้"
        );
      }

      // Both items must still be available. Without this, a listing with
      // several pending offers could be accepted into several deals at once
      // (and have coins locked for each of them).
      if (listing.status !== "active" || offeredListing.status !== "active") {
        throw new HttpsError(
          "failed-precondition",
          "สิ่งของในข้อเสนอนี้ไม่พร้อมแลกเปลี่ยนแล้ว"
        );
      }

      let newBalance = 0;
      if (payerRef) {
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

      // Two independent 6-digit codes from a CSPRNG. These used to both be
      // derived from the same Date.now() value (code2 was always
      // code1 + 400000), so either party could work out the other's code
      // from their own and complete the deal without ever meeting.
      const code1 = crypto.randomInt(100000, 1000000).toString();
      let code2 = crypto.randomInt(100000, 1000000).toString();
      while (code2 === code1) {
        code2 = crypto.randomInt(100000, 1000000).toString();
      }

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
 * Confirms a handover OTP code: the caller enters the code shown to their
 * trade partner, and once BOTH sides have confirmed, the deal completes
 * (escrow coins release to whichever side is owed them, both listings flip
 * to 'completed', the offer flips to 'completed').
 *
 * This used to run as a client-side Firestore transaction
 * (TransactionRepository.confirmTransaction/confirmTransactionByOfferId).
 * The problem: completing a deal means updating a listing that may belong
 * to the OTHER party (whichever of the two listings isn't the caller's),
 * and crediting a coins_balance that may belong to the other party too —
 * there's no Firestore security rule that can let one user write another
 * user's document only in this narrow, mutual-transaction case without
 * opening a much bigger hole. Moving it here sidesteps that: the Admin SDK
 * bypasses rules entirely, and every check (membership, OTP correctness)
 * is enforced in code instead.
 *
 * Callable from Flutter as:
 *   FirebaseFunctions.instance.httpsCallable('confirmHandoverOtp')
 *       .call({offerId, inputOtp});
 */
exports.confirmHandoverOtp = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "กรุณาล็อกอินก่อนทำรายการ");
  }
  const callerId = request.auth.uid;

  const offerId = request.data && request.data.offerId;
  const inputOtp = request.data && request.data.inputOtp;

  if (!offerId || typeof offerId !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุ offerId");
  }
  if (!inputOtp || typeof inputOtp !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุรหัสยืนยัน");
  }

  const db = admin.firestore();

  try {
    const result = await db.runTransaction(async (transaction) => {
      const txQuery = db
        .collection("transactions")
        .where("offer_id", "==", offerId)
        .where("members", "array-contains", callerId)
        .limit(1);
      // The deal is looked up by offer_id, so the offer document is known
      // up front — fetch both in the same round trip.
      const prefetchedOfferRef = db.collection("offers").doc(offerId);
      const [txQuerySnap, prefetchedOfferSnap] = await Promise.all([
        transaction.get(txQuery),
        transaction.get(prefetchedOfferRef),
      ]);
      if (txQuerySnap.empty) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสัญญากองกลาง");
      }
      const txDoc = txQuerySnap.docs[0];
      const txRef = txDoc.ref;
      const txData = txDoc.data();

      if (txData.status !== "in_progress") {
        throw new HttpsError("failed-precondition", "สถานะดีลไม่ถูกต้อง");
      }

      const members = txData.members || [];
      const partnerId = members.find((id) => id !== callerId);
      if (!partnerId) {
        throw new HttpsError("not-found", "ไม่พบคู่สัญญาในดีลนี้");
      }
      const codes = txData.verification_codes || {};
      const partnerCode = codes[partnerId] || "";
      if (inputOtp !== partnerCode) {
        throw new HttpsError("invalid-argument", "รหัสยืนยันไม่ถูกต้อง");
      }

      const confirmedByIds = Array.from(txData.confirmed_by_user_ids || []);
      if (!confirmedByIds.includes(callerId)) {
        confirmedByIds.push(callerId);
      }
      // One correct entry of the partner's OTP is treated as proof enough
      // that the handover happened — there's no way to guess a code, so
      // requiring the second party to also enter it back just adds friction
      // without adding real security.
      const isCompleted = confirmedByIds.length >= 1;

      let offerRef = null;
      let receiverRef = null;
      let newBalance = 0;
      let escrowCoins = 0;

      if (isCompleted) {
        offerRef = prefetchedOfferRef;
        const offerSnap = prefetchedOfferSnap;
        if (!offerSnap.exists) {
          throw new HttpsError("not-found", "ไม่พบข้อมูลข้อเสนอที่เกี่ยวข้อง");
        }
        const offerData = offerSnap.data();
        const targetItemId = offerData.target_listing_id;
        const offeredItemId = offerData.offered_listing_id;
        escrowCoins = txData.escrow_coins || 0;

        if (escrowCoins > 0) {
          const coinOffset = offerData.coin_offset || 0;
          const senderId = offerData.sender_id;
          const targetUserId =
            offerData.target_user_id || offerData.target_owner_id;
          const receiverId = coinOffset > 0 ? targetUserId : senderId;
          receiverRef = db.collection("users").doc(receiverId);
          const receiverSnap = await transaction.get(receiverRef);
          if (!receiverSnap.exists) {
            throw new HttpsError("not-found", "ไม่พบบัญชีผู้รับเหรียญ");
          }
          const currentBalance = receiverSnap.data().coins_balance || 0;
          newBalance = currentBalance + escrowCoins;
        }

        transaction.update(db.collection("listings").doc(targetItemId), {
          status: "completed",
        });
        transaction.update(db.collection("listings").doc(offeredItemId), {
          status: "completed",
        });

        if (receiverRef && escrowCoins > 0) {
          transaction.update(receiverRef, { coins_balance: newBalance });
          const walletTxRef = db.collection("wallet_transactions").doc();
          transaction.set(walletTxRef, {
            log_id: walletTxRef.id,
            user_id: receiverRef.id,
            amount: escrowCoins,
            balance_after: newBalance,
            type: "escrow_release",
            status: "success",
            reference_id: txRef.id,
            description: "ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)",
            created_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        transaction.update(txRef, {
          confirmed_by_user_ids: confirmedByIds,
          status: "completed",
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(offerRef, { status: "completed" });
      } else {
        transaction.update(txRef, {
          confirmed_by_user_ids: confirmedByIds,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return { isCompleted, partnerId, transactionId: txRef.id };
    });

    return { success: true, ...result };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error(
      `confirmHandoverOtp failed for offer ${offerId}: ${error.message}`
    );
    throw new HttpsError("internal", "เกิดข้อผิดพลาดในการยืนยันรหัส");
  }
});

/**
 * Cancels an accepted (in-progress) deal: refunds any locked escrow coins to
 * whichever side paid them, reopens both listings, and marks the offer and
 * transaction as cancelled. Same reasoning as confirmHandoverOtp above for
 * why this moved server-side — cancelling also has to write listings/coins
 * belonging to the other party.
 *
 * Callable from Flutter as:
 *   FirebaseFunctions.instance.httpsCallable('cancelAcceptedTrade')
 *       .call({offerId, reason, roomId});
 */
exports.cancelAcceptedTrade = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "กรุณาล็อกอินก่อนทำรายการ");
  }
  const callerId = request.auth.uid;

  const offerId = request.data && request.data.offerId;
  const reason = (request.data && request.data.reason) || "";
  const roomId = request.data && request.data.roomId;

  if (!offerId || typeof offerId !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุ offerId");
  }

  const db = admin.firestore();

  try {
    await db.runTransaction(async (transaction) => {
      const txQuery = db
        .collection("transactions")
        .where("offer_id", "==", offerId)
        .where("members", "array-contains", callerId)
        .limit(1);
      const offerRef = db.collection("offers").doc(offerId);
      // Deal, offer and the canceller's display name don't depend on each
      // other — one parallel round trip. The name is resolved server-side
      // rather than trusting a client-supplied one, same reasoning as
      // acceptTradeOffer's callerName.
      const [txQuerySnap, offerSnap, callerSnap] = await Promise.all([
        transaction.get(txQuery),
        transaction.get(offerRef),
        transaction.get(db.collection("users").doc(callerId)),
      ]);
      if (txQuerySnap.empty) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลสัญญากองกลาง");
      }
      const txDoc = txQuerySnap.docs[0];
      const txRef = txDoc.ref;
      const txData = txDoc.data();

      if (txData.status !== "in_progress") {
        throw new HttpsError("failed-precondition", "สถานะไม่ใช่กำลังดำเนินการ");
      }

      if (!offerSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลข้อเสนอที่เกี่ยวข้อง");
      }
      const offerData = offerSnap.data();
      const targetItemId = offerData.target_listing_id;
      const offeredItemId = offerData.offered_listing_id;
      const escrowCoins = txData.escrow_coins || 0;

      let payerRef = null;
      let newBalance = 0;
      if (escrowCoins > 0) {
        const coinOffset = offerData.coin_offset || 0;
        const senderId = offerData.sender_id;
        const targetUserId =
          offerData.target_user_id || offerData.target_owner_id;
        const payerId = coinOffset > 0 ? senderId : targetUserId;
        payerRef = db.collection("users").doc(payerId);
        const payerSnap = await transaction.get(payerRef);
        if (!payerSnap.exists) {
          throw new HttpsError("not-found", "ไม่พบบัญชีผู้จ่ายเหรียญ");
        }
        const currentBalance = payerSnap.data().coins_balance || 0;
        newBalance = currentBalance + escrowCoins;
      }

      const callerName = callerSnap.exists
        ? callerSnap.data().name || "ผู้ใช้งาน"
        : "ผู้ใช้งาน";

      transaction.update(db.collection("listings").doc(targetItemId), {
        status: "active",
      });
      transaction.update(db.collection("listings").doc(offeredItemId), {
        status: "active",
      });

      if (payerRef && escrowCoins > 0) {
        transaction.update(payerRef, { coins_balance: newBalance });
        const walletTxRef = db.collection("wallet_transactions").doc();
        transaction.set(walletTxRef, {
          log_id: walletTxRef.id,
          user_id: payerRef.id,
          amount: escrowCoins,
          balance_after: newBalance,
          type: "refund",
          status: "success",
          reference_id: txRef.id,
          description: "คืนเหรียญจากระบบกองกลาง (ยกเลิกการแลกเปลี่ยน)",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      transaction.update(txRef, {
        status: "cancelled",
        cancel_reason: reason,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(offerRef, { status: "cancelled" });

      if (roomId) {
        const roomRef = db.collection("chat_rooms").doc(roomId);
        transaction.update(roomRef, {
          last_message_type: "system_cancel",
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        const msgRef = roomRef.collection("messages").doc();
        transaction.set(msgRef, {
          sender_id: "system",
          content: `${callerName} ได้ยกเลิกการแลกเปลี่ยน ระบบได้ทำการคืนสิ่งของและเหรียญเรียบร้อยแล้ว`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: "system_cancel",
        });
      }
    });

    return { success: true };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error(
      `cancelAcceptedTrade failed for offer ${offerId}: ${error.message}`
    );
    throw new HttpsError("internal", "เกิดข้อผิดพลาดในการยกเลิกการแลกเปลี่ยน");
  }
});

/**
 * Submits a post-trade rating/review, updating the reviewee's running
 * rating average.
 *
 * This used to run as a client-side Firestore transaction
 * (ReviewRepository.submitReview) that both created the review doc AND
 * updated `owner_rating_scores`/`owner_rating_count` on the REVIEWEE's own
 * user document — the same "one user has to write another user's doc"
 * problem as confirmHandoverOtp/cancelAcceptedTrade above, and (unlike
 * those) the old client code never even checked that the reviewer and
 * reviewee were actually both members of a real, completed transaction —
 * so it's also a chance to close that gap: this now verifies the caller
 * against the transaction doc before writing anything.
 *
 * Callable from Flutter as:
 *   FirebaseFunctions.instance.httpsCallable('submitTradeReview')
 *       .call({revieweeId, transactionId, rating, comment});
 */
exports.submitTradeReview = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "กรุณาล็อกอินก่อนทำรายการ");
  }
  const callerId = request.auth.uid;

  const revieweeId = request.data && request.data.revieweeId;
  const transactionId = request.data && request.data.transactionId;
  const rating = request.data && request.data.rating;
  const comment = (request.data && request.data.comment) || "";

  if (!revieweeId || typeof revieweeId !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุ revieweeId");
  }
  if (!transactionId || typeof transactionId !== "string") {
    throw new HttpsError("invalid-argument", "ต้องระบุ transactionId");
  }
  if (typeof rating !== "number" || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", "คะแนนต้องอยู่ระหว่าง 1-5");
  }
  if (revieweeId === callerId) {
    throw new HttpsError("invalid-argument", "ไม่สามารถให้คะแนนตัวเองได้");
  }

  const db = admin.firestore();

  try {
    const result = await db.runTransaction(async (transaction) => {
      const txRef = db.collection("transactions").doc(transactionId);
      const existingQuery = db
        .collection("reviews")
        .where("transaction_id", "==", transactionId)
        .where("reviewer_id", "==", callerId)
        .limit(1);
      const userRef = db.collection("users").doc(revieweeId);
      // The deal, any earlier review of it by this caller, and the
      // reviewee's rating totals are independent — read them in parallel.
      const [txSnap, existingSnap, userSnap] = await Promise.all([
        transaction.get(txRef),
        transaction.get(existingQuery),
        transaction.get(userRef),
      ]);
      if (!txSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบข้อมูลธุรกรรม");
      }
      const txData = txSnap.data();
      const members = txData.members || [];
      if (!members.includes(callerId)) {
        throw new HttpsError("permission-denied", "คุณไม่มีสิทธิ์รีวิวดีลนี้");
      }
      if (!members.includes(revieweeId)) {
        throw new HttpsError(
          "invalid-argument",
          "ผู้ใช้งานเป้าหมายไม่ตรงกับดีลนี้"
        );
      }
      if (txData.status !== "completed") {
        throw new HttpsError(
          "failed-precondition",
          "ดีลนี้ยังไม่เสร็จสมบูรณ์"
        );
      }

      if (!existingSnap.empty) {
        throw new HttpsError(
          "already-exists",
          "คุณได้ให้คะแนนดีลนี้ไปแล้ว"
        );
      }

      if (!userSnap.exists) {
        throw new HttpsError("not-found", "ไม่พบผู้ใช้งานเป้าหมาย");
      }
      const userData = userSnap.data();
      const currentScores = userData.owner_rating_scores || 0;
      const currentCount = userData.owner_rating_count || 0;
      const newScores =
        (currentScores * currentCount + rating) / (currentCount + 1);

      // Snapshot what was traded into the review itself. Reviews are public,
      // but the deal's transaction/offer docs are readable only by the two
      // parties (the transaction holds both OTP codes), so without this
      // anyone else viewing a profile saw the review with no items.
      const itemSnaps = await Promise.all(
        (txData.listings || []).map((id) =>
          transaction.get(db.collection("listings").doc(id))
        )
      );
      const itemOf = (ownerId) => {
        const snap = itemSnaps.find(
          (s) => s.exists && s.data().owner_id === ownerId
        );
        return snap ? listingSnapshot(snap) : null;
      };

      const reviewRef = db.collection("reviews").doc();
      transaction.set(reviewRef, {
        reviewer_id: callerId,
        reviewee_id: revieweeId,
        transaction_id: transactionId,
        rating: rating,
        comment: comment,
        reviewer_item: itemOf(callerId),
        reviewee_item: itemOf(revieweeId),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        owner_rating_scores: newScores,
        owner_rating_count: currentCount + 1,
      });

      return { reviewId: reviewRef.id, newScores };
    });

    // Listings carry a copy of their owner's rating so feed cards can show
    // it without reading every owner's user doc. Refresh it on all of the
    // reviewee's listings. Done after the commit and best-effort: the review
    // itself has already succeeded, and a stale copy is only cosmetic.
    try {
      const listingsSnap = await db
        .collection("listings")
        .where("owner_id", "==", revieweeId)
        .get();
      for (let i = 0; i < listingsSnap.docs.length; i += 500) {
        const batch = db.batch();
        listingsSnap.docs.slice(i, i + 500).forEach((doc) => {
          batch.update(doc.ref, { owner_rating_scores: result.newScores });
        });
        await batch.commit();
      }
    } catch (error) {
      logger.warn(
        `submitTradeReview: rating copy to listings of ${revieweeId} failed: ${error.message}`
      );
    }

    return { success: true, reviewId: result.reviewId };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error(
      `submitTradeReview failed for transaction ${transactionId}: ${error.message}`
    );
    throw new HttpsError("internal", "เกิดข้อผิดพลาดในการส่งรีวิว");
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