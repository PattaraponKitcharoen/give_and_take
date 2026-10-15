// Reports from the app and the admin web's moderation actions.
//
// reports/{reporterId}_{type}_{targetId}  (one per reporter per target)
//   reporter_id, target_type ("listing" | "user" | "chat"), target_id,
//   reason, detail, status ("open" | "resolved" | "dismissed"), created_at
//   + filled in here: target_user_id, target_title, snapshot, resolution
//
// The app only writes the first block (firestore.rules). onReportCreated
// adds who is being reported and a copy of the evidence, so it survives the
// listing/profile being edited or deleted. For a chat that copy is the last
// CHAT_EVIDENCE messages: admins can't read chats otherwise.
//
// adminModerate is the only way the admin web changes bans: it applies the
// action, closes the related reports, logs it to admin_actions and notifies
// the people involved.
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const db = () => admin.firestore();
const FieldValue = () => admin.firestore.FieldValue;
const CHAT_EVIDENCE = 30;
const MAX_REASON = 200;

const millis = (t) => (t && typeof t.toMillis === "function" ? t.toMillis() : null);

async function sendPush(uid, title, body, data) {
  if (!uid) return;
  const ref = db().collection("users").doc(uid);
  const snap = await ref.get();
  const token = snap.exists && snap.data().fcm_token;
  if (!token) return;
  try {
    await admin.messaging().send({
      token, notification: { title, body }, data,
      android: { notification: { channelId: "give_and_take_channel" } },
    });
  } catch (e) {
    logger.error(`reports: push to ${uid} failed: ${e.message}`);
    if (e.code === "messaging/registration-token-not-registered" ||
        e.code === "messaging/invalid-registration-token") {
      await ref.update({ fcm_token: FieldValue().delete() });
    }
  }
}

/** Who is being reported and a copy of what was reported. */
async function evidenceFor(type, targetId, reporterId) {
  if (type === "listing") {
    const snap = await db().collection("listings").doc(targetId).get();
    if (!snap.exists) return null;
    const d = snap.data();
    return {
      target_user_id: d.owner_id || "",
      target_title: d.title || "",
      snapshot: {
        title: d.title || "", description: d.description || "", category: d.category || "",
        condition: d.condition || "", estimated_coins: d.estimated_coins || 0,
        thumbnail_url: d.thumbnail_url || "",
        images: (d.images || []).map((i) => (typeof i === "string" ? i : i && i.url)).filter(Boolean),
        owner_name: d.owner_name || "", status: d.status || "",
      },
    };
  }
  if (type === "user") {
    const snap = await db().collection("users").doc(targetId).get();
    if (!snap.exists) return null;
    const d = snap.data();
    return {
      target_user_id: targetId,
      target_title: d.name || "",
      snapshot: { name: d.name || "", bio: d.bio || "", profile_img_url: d.profile_img_url || "", email: d.email || "" },
    };
  }
  if (type === "chat") {
    const roomRef = db().collection("chat_rooms").doc(targetId);
    const room = await roomRef.get();
    if (!room.exists) return null;
    const members = room.data().members || [];
    const other = members.find((m) => m !== reporterId) || "";
    const msgs = await roomRef.collection("messages")
      .orderBy("timestamp", "desc").limit(CHAT_EVIDENCE).get();
    const names = {};
    for (const uid of members) {
      const u = await db().collection("users").doc(uid).get();
      names[uid] = u.exists ? u.data().name || "" : "";
    }
    return {
      target_user_id: other,
      target_title: `แชทระหว่าง ${names[reporterId] || "ผู้รายงาน"} กับ ${names[other] || "ผู้ใช้"}`,
      snapshot: {
        member_names: names,
        messages: msgs.docs.reverse().map((m) => {
          const d = m.data();
          return { sender_id: d.sender_id || "", type: d.type || "text", content: d.content || "", at: millis(d.timestamp) };
        }),
      },
    };
  }
  return null;
}

exports.onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const r = snap.data();
  const evidence = await evidenceFor(r.target_type, r.target_id, r.reporter_id);
  if (!evidence) {
    await snap.ref.update({ target_missing: true });
    return;
  }
  await snap.ref.update({ ...evidence, snapshot_at: FieldValue().serverTimestamp() });
});

/** Open reports about a target (and, for a user ban, about anything of theirs). */
async function openReportsFor({ reportType, reportTargetId, userId }) {
  const found = new Map();
  if (reportType && reportTargetId) {
    const q = await db().collection("reports")
      .where("target_type", "==", reportType).where("target_id", "==", reportTargetId)
      .where("status", "==", "open").get();
    q.docs.forEach((d) => found.set(d.id, d));
  }
  if (userId) {
    const q = await db().collection("reports")
      .where("target_user_id", "==", userId).where("status", "==", "open").get();
    q.docs.forEach((d) => found.set(d.id, d));
  }
  return [...found.values()];
}

const ACTIONS = ["dismiss", "ban_listing", "unban_listing", "ban_user", "unban_user", "verify_email"];

exports.adminModerate = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "กรุณาเข้าสู่ระบบ");
  const adminId = request.auth.uid;
  const me = await db().collection("users").doc(adminId).get();
  if (!me.exists || me.data().role !== "admin") {
    throw new HttpsError("permission-denied", "เฉพาะผู้ดูแลระบบ");
  }

  const d = request.data || {};
  const action = d.action;
  if (!ACTIONS.includes(action)) throw new HttpsError("invalid-argument", "action ไม่ถูกต้อง");
  const reason = typeof d.reason === "string" ? d.reason.trim().slice(0, MAX_REASON) : "";
  const note = typeof d.note === "string" ? d.note.trim().slice(0, 500) : "";
  const days = d.days === null || d.days === undefined ? null : Number(d.days);
  if (days !== null && !(Number.isInteger(days) && days > 0 && days <= 365)) {
    throw new HttpsError("invalid-argument", "จำนวนวันไม่ถูกต้อง");
  }
  if ((action === "ban_listing" || action === "ban_user") && !reason) {
    throw new HttpsError("invalid-argument", "ต้องระบุเหตุผล");
  }
  const listingId = typeof d.listingId === "string" ? d.listingId : "";
  const userId = typeof d.userId === "string" ? d.userId : "";
  const report = d.report && typeof d.report === "object" ? d.report : {};
  const reportType = typeof report.type === "string" ? report.type : "";
  const reportTargetId = typeof report.id === "string" ? report.id : "";

  const now = admin.firestore.Timestamp.now();
  let targetUserId = userId;

  if (action === "ban_listing" || action === "unban_listing") {
    if (!listingId) throw new HttpsError("invalid-argument", "ต้องระบุ listingId");
    const ref = db().collection("listings").doc(listingId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "ไม่พบประกาศ");
    const l = snap.data();
    targetUserId = l.owner_id || "";
    if (action === "ban_listing") {
      if (l.status === "in_progress") {
        throw new HttpsError("failed-precondition", "ประกาศนี้อยู่ระหว่างแลกเปลี่ยน ยกเลิกดีลก่อนจึงจะระงับได้");
      }
      await ref.update({
        status: "banned", ban_reason: reason,
        hidden_by_user_ban: FieldValue().delete(), updated_at: FieldValue().serverTimestamp(),
      });
      await sendPush(targetUserId, "ประกาศของคุณถูกระงับ",
        `"${l.title || "ประกาศ"}" ถูกระงับ: ${reason}`, { type: "listing_banned", listing_id: listingId });
    } else {
      if (l.status !== "banned") throw new HttpsError("failed-precondition", "ประกาศนี้ไม่ได้ถูกระงับ");
      await ref.update({
        status: "active", ban_reason: FieldValue().delete(),
        hidden_by_user_ban: FieldValue().delete(), updated_at: FieldValue().serverTimestamp(),
      });
    }
  }

  if (action === "ban_user" || action === "unban_user") {
    if (!userId) throw new HttpsError("invalid-argument", "ต้องระบุ userId");
    if (userId === adminId) throw new HttpsError("invalid-argument", "ระงับบัญชีตัวเองไม่ได้");
    const ref = db().collection("users").doc(userId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "ไม่พบผู้ใช้");
    if (action === "ban_user") {
      if (snap.data().role === "admin") throw new HttpsError("failed-precondition", "ระงับบัญชีผู้ดูแลระบบไม่ได้");
      const until = days === null ? null : admin.firestore.Timestamp.fromMillis(now.toMillis() + days * 864e5);
      // onUserBanChanged hides their listings and, if permanent, disables login.
      await ref.update({
        status: "banned", ban_reason: reason, banned_at: now,
        banned_until: until || FieldValue().delete(), updated_at: FieldValue().serverTimestamp(),
      });
      await sendPush(userId, "บัญชีของคุณถูกระงับ",
        `${days === null ? "ระงับถาวร" : `ระงับ ${days} วัน`}: ${reason}`, { type: "account_banned" });
    } else {
      await ref.update({
        status: "active", ban_reason: FieldValue().delete(), banned_at: FieldValue().delete(),
        banned_until: FieldValue().delete(), updated_at: FieldValue().serverTimestamp(),
      });
    }
  }

  // Mark the user's email as verified in Firebase Auth (what the app checks),
  // for testing or for someone who can't receive the verification mail.
  if (action === "verify_email") {
    if (!userId) throw new HttpsError("invalid-argument", "ต้องระบุ userId");
    let authUser;
    try {
      authUser = await admin.auth().getUser(userId);
    } catch (e) {
      throw new HttpsError("not-found", "ไม่พบบัญชีผู้ใช้");
    }
    if (!authUser.emailVerified) {
      await admin.auth().updateUser(userId, { emailVerified: true });
    }
    await db().collection("users").doc(userId).update({ is_email_verified: true });
  }

  // Close the reports this action answers: the report's own target, plus
  // every open report about the user when banning them.
  let closed = [];
  if (action === "dismiss" || action === "ban_listing" || action === "ban_user") {
    closed = await openReportsFor({
      reportType, reportTargetId,
      userId: action === "ban_user" ? userId : "",
    });
    if (action === "dismiss" && closed.length === 0 && !(reportType && reportTargetId)) {
      throw new HttpsError("invalid-argument", "ต้องระบุรายงานที่จะยกเลิก");
    }
    const status = action === "dismiss" ? "dismissed" : "resolved";
    for (let i = 0; i < closed.length; i += 400) {
      const batch = db().batch();
      closed.slice(i, i + 400).forEach((r) => batch.update(r.ref, {
        status, resolution: { action, reason, note, by: adminId, at: now },
      }));
      await batch.commit();
    }
    // Reporters hear that it was looked at, not what happened to the other side.
    const reporters = new Set(closed.map((r) => r.data().reporter_id).filter(Boolean));
    await Promise.all([...reporters].map((uid) => sendPush(uid, "เราตรวจสอบรายงานของคุณแล้ว",
      "ขอบคุณที่ช่วยให้ Give & Take ปลอดภัยขึ้น", { type: "report_reviewed" })));
  }

  await db().collection("admin_actions").add({
    admin_id: adminId, action, reason, note, days,
    listing_id: listingId || null, target_user_id: targetUserId || null,
    report_target: reportType ? { type: reportType, id: reportTargetId } : null,
    reports_closed: closed.map((r) => r.id),
    created_at: now,
  });
  return { ok: true, reportsClosed: closed.length };
});

exports._internal = { evidenceFor, CHAT_EVIDENCE };
