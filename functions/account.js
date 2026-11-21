// Account deletion (App Store / Play Store requirement).
//
// deleteAccount (callable): the signed-in user deletes their own account.
//   - Needs a fresh sign-in (auth_time within RECENT_LOGIN_SECONDS): the app
//     re-authenticates first, so a borrowed unlocked phone isn't enough.
//   - Refused while a trade is in progress (coins held in escrow): finish
//     or cancel it first, so the other side never loses out.
//   - Removes who they are and what's still on offer: personal fields,
//     listings that weren't traded (with their photos), wants, matches,
//     pending offers, the profile photo and the Auth account.
//   - Keeps the history the other side relies on: chats, reviews, traded
//     listings, transactions and wallet logs. users/{uid} stays as a
//     tombstone (status "deleted", name DELETED_NAME) so those still show
//     a name instead of breaking.
//
// deleted_accounts/{sha256(email)} remembers a deleted email (hashed, never
// the address itself) and any ban still running. onUserProfileCreated
// checks it when that email signs up again: the new account starts with 0
// coins instead of the sign-up 1,000, and an unfinished ban carries over.
const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
// Modular import: the emulator's firebase-admin wrapper drops the
// admin.firestore.FieldValue/Timestamp statics.
const { FieldValue } = require("firebase-admin/firestore");
const { isBannedData } = require("./moderation");

const db = () => admin.firestore();
const RECENT_LOGIN_SECONDS = 5 * 60;
const DELETED_NAME = "ผู้ใช้ที่ลบบัญชีแล้ว";
const BAN_FIELDS = ["ban_reason", "banned_until", "banned_at"];

/** Hash of a normalised email; null when there's no email. */
function emailHash(email) {
  const e = (email || "").trim().toLowerCase();
  return e ? crypto.createHash("sha256").update(e).digest("hex") : null;
}

/** Storage path from a Firebase download URL, or null for anything else. */
function storagePathOf(url) {
  const m = /\/o\/([^?]+)/.exec(url || "");
  return m && /firebasestorage\.googleapis\.com/.test(url) ? decodeURIComponent(m[1]) : null;
}

async function deleteFiles(urls) {
  const paths = [...new Set(urls.map(storagePathOf).filter(Boolean))];
  await Promise.all(paths.map(async (p) => {
    try {
      await admin.storage().bucket().file(p).delete({ ignoreNotFound: true });
    } catch (e) {
      logger.warn(`account: could not delete ${p}: ${e.message}`);
    }
  }));
}

async function deleteInChunks(refs) {
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db().batch();
    refs.slice(i, i + 400).forEach((r) => batch.delete(r));
    await batch.commit();
  }
}

/** Same as withdrawing a pending offer in the app, with a system message. */
async function cancelPendingOffer(offerDoc) {
  const batch = db().batch();
  batch.delete(offerDoc.ref);
  const rooms = await db().collection("chat_rooms")
    .where("active_offer_id", "==", offerDoc.id).get();
  for (const room of rooms.docs) {
    batch.update(room.ref, { last_message_type: "system_cancel", updated_at: FieldValue.serverTimestamp() });
    batch.set(room.ref.collection("messages").doc(), {
      sender_id: "system",
      content: "อีกฝ่ายลบบัญชีแล้ว ข้อเสนอนี้ถูกยกเลิก",
      timestamp: FieldValue.serverTimestamp(),
      type: "system_cancel",
    });
  }
  await batch.commit();
}

async function deleteAccountData(uid) {
  const userRef = db().collection("users").doc(uid);
  const user = (await userRef.get()).data() || {};
  let email = user.email;
  try {
    email = (await admin.auth().getUser(uid)).email || email;
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  // 1. Remember the email (hashed) and a ban that's still running.
  const hash = emailHash(email);
  if (hash) {
    const record = { deleted_at: FieldValue.serverTimestamp() };
    if (isBannedData(user)) {
      for (const f of BAN_FIELDS) record[f] = user[f] === undefined ? null : user[f];
    } else {
      for (const f of BAN_FIELDS) record[f] = FieldValue.delete();
    }
    await db().collection("deleted_accounts").doc(hash).set(record, { merge: true });
  }

  // 2. Listings: traded ones stay (other people's history) without the
  //    owner's name or photo; everything else goes, photos included.
  //    Deleting a listing also clears its vector and matches (matching.js).
  const files = [user.profile_img_url];
  const listings = await db().collection("listings").where("owner_id", "==", uid).get();
  const remove = [];
  for (const d of listings.docs) {
    const l = d.data();
    if (l.status === "completed" || l.status === "in_progress") {
      await d.ref.update({ owner_name: DELETED_NAME, owner_profile_img: "" });
    } else {
      remove.push(d.ref);
      files.push(l.thumbnail_url, ...(Array.isArray(l.images) ? l.images : []));
    }
  }
  await deleteInChunks(remove);

  // 3. Wants and matches.
  const wants = await db().collection("wants").where("owner_id", "==", uid).get();
  const matches = await db().collection("matches").where("members", "array-contains", uid).get();
  await deleteInChunks([...wants.docs, ...matches.docs].map((d) => d.ref));

  // 4. Pending offers, sent or received.
  const [sent, received] = await Promise.all([
    db().collection("offers").where("sender_id", "==", uid).where("status", "==", "pending").get(),
    db().collection("offers").where("target_user_id", "==", uid).where("status", "==", "pending").get(),
  ]);
  for (const o of [...sent.docs, ...received.docs]) await cancelPendingOffer(o);

  // 5. The tombstone: only what history needs to keep rendering.
  await userRef.set({
    name: DELETED_NAME,
    role: "user",
    status: "deleted",
    coins_balance: 0,
    owner_rating_scores: user.owner_rating_scores || 0,
    owner_rating_count: user.owner_rating_count || 0,
    created_at: user.created_at || null,
    deleted_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  });

  await deleteFiles(files);
  return { listingsDeleted: remove.length, offersCancelled: sent.size + received.size };
}

exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "กรุณาเข้าสู่ระบบ");
  const authTime = request.auth.token && request.auth.token.auth_time;
  if (!authTime || Date.now() / 1000 - authTime > RECENT_LOGIN_SECONDS) {
    throw new HttpsError("failed-precondition", "requires-recent-login");
  }

  const deals = await db().collection("transactions").where("members", "array-contains", uid).get();
  const active = deals.docs.filter((d) => d.data().status === "in_progress").length;
  if (active > 0) {
    throw new HttpsError("failed-precondition", "active-trades", { count: active });
  }

  const result = await deleteAccountData(uid);
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }
  logger.info(`account: deleted ${uid}`, result);
  return { ok: true };
});

/** A deleted email signing up again: no second 1,000 coins, ban carries over. */
exports.onUserProfileCreated = onDocumentCreated("users/{uid}", async (event) => {
  const uid = event.params.uid;
  let email;
  try {
    email = (await admin.auth().getUser(uid)).email;
  } catch (e) {
    logger.warn(`account: no auth user for new profile ${uid}: ${e.message}`);
    return;
  }
  const hash = emailHash(email);
  if (!hash) return;
  const prior = await db().collection("deleted_accounts").doc(hash).get();
  if (!prior.exists) return;

  const update = { coins_balance: 0, updated_at: FieldValue.serverTimestamp() };
  const p = prior.data();
  const ban = { status: "banned", ban_reason: p.ban_reason, banned_until: p.banned_until };
  if (p.ban_reason && isBannedData(ban)) {
    Object.assign(update, { status: "banned", ban_reason: p.ban_reason,
      banned_until: p.banned_until || null, banned_at: p.banned_at || FieldValue.serverTimestamp() });
  }
  await event.data.ref.update(update);
  logger.info(`account: ${uid} signed up with a deleted email; coins reset${update.status ? ", ban restored" : ""}`);
});

exports._internal = { emailHash, storagePathOf, deleteAccountData, RECENT_LOGIN_SECONDS, DELETED_NAME };
