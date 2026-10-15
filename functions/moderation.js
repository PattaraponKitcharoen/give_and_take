// Account bans (set from the admin web on users/{uid}):
//   status: "banned", ban_reason, banned_at, banned_until (null = permanent)
//
// - Firestore rules block every write by a banned user (isBanned() in
//   firestore.rules); assertNotBanned() does the same for callables.
// - onUserBanChanged hides the user's active listings while banned and puts
//   back exactly those when the ban ends. A permanent ban also disables the
//   Firebase Auth account; a temporary one keeps login so the app can show
//   the reason and end date.
// - liftExpiredBans ends temporary bans once banned_until has passed.
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const db = () => admin.firestore();
const BAN_FIELDS = ["ban_reason", "banned_until", "banned_at"];

const millis = (t) => (t && typeof t.toMillis === "function" ? t.toMillis() : null);

/** Same test as isBanned() in firestore.rules. */
function isBannedData(u, nowMs = Date.now()) {
  if (!u || u.status !== "banned") return false;
  const until = millis(u.banned_until);
  return until === null || until > nowMs;
}

/** For callables: refuse a banned caller. */
async function assertNotBanned(uid) {
  const snap = await db().collection("users").doc(uid).get();
  if (snap.exists && isBannedData(snap.data())) {
    throw new HttpsError("permission-denied", "บัญชีของคุณถูกระงับการใช้งาน");
  }
}

async function commitInChunks(refs, data) {
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db().batch();
    refs.slice(i, i + 400).forEach((r) => batch.update(r, data));
    await batch.commit();
  }
}

exports.onUserBanChanged = onDocumentUpdated("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const wasBanned = before.status === "banned";
  const nowBanned = after.status === "banned";
  const permanent = nowBanned && !after.banned_until;
  const wasPermanent = wasBanned && !before.banned_until;
  if (wasBanned === nowBanned && permanent === wasPermanent) return;

  if (nowBanned && !wasBanned) {
    // Hide what they have on offer. Listings in a deal stay as they are so
    // the other side can still finish or cancel; ones an admin banned on
    // their own are untouched and stay banned after the user's ban ends.
    const active = await db().collection("listings")
      .where("owner_id", "==", uid).where("status", "==", "active").get();
    await commitInChunks(active.docs.map((d) => d.ref), {
      status: "banned",
      hidden_by_user_ban: true,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`moderation: ${uid} banned, hid ${active.size} listings`);
  }

  if (wasBanned && !nowBanned) {
    const hidden = await db().collection("listings")
      .where("owner_id", "==", uid).where("hidden_by_user_ban", "==", true).get();
    await commitInChunks(hidden.docs.map((d) => d.ref), {
      status: "active",
      hidden_by_user_ban: admin.firestore.FieldValue.delete(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`moderation: ${uid} unbanned, restored ${hidden.size} listings`);
  }

  // Login: off for a permanent ban, back on otherwise.
  if (permanent !== wasPermanent) {
    try {
      await admin.auth().updateUser(uid, { disabled: permanent });
      if (permanent) await admin.auth().revokeRefreshTokens(uid);
    } catch (e) {
      logger.error(`moderation: could not ${permanent ? "disable" : "enable"} auth for ${uid}: ${e.message}`);
    }
  }
});

/** Ends temporary bans whose banned_until has passed. */
async function liftExpired(now = admin.firestore.Timestamp.now()) {
  const due = await db().collection("users")
    .where("status", "==", "banned").where("banned_until", "<=", now).get();
  const clear = { status: "active", updated_at: admin.firestore.FieldValue.serverTimestamp() };
  for (const f of BAN_FIELDS) clear[f] = admin.firestore.FieldValue.delete();
  await commitInChunks(due.docs.map((d) => d.ref), clear);
  if (due.size) logger.info(`moderation: lifted ${due.size} expired bans`);
  return due.size;
}

exports.liftExpiredBans = onSchedule(
  { schedule: "every 60 minutes", timeZone: "Asia/Bangkok" },
  () => liftExpired()
);

exports.isBannedData = isBannedData;
exports.assertNotBanned = assertNotBanned;
exports._internal = { liftExpired };
