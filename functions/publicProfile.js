// Public profiles: what other users may see about someone.
//
// users/{uid} holds private data too (email, phone, push token, location,
// faculty, coins, bans) and only its owner and admins can read it
// (firestore.rules). Screens showing *someone else* read
// public_profiles/{uid} instead, which this trigger keeps in step with the
// user doc. Writes are skipped when none of the public fields changed, so
// the frequent token/location updates cost nothing extra.
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
// Modular import: the emulator's firebase-admin wrapper drops the
// admin.firestore.FieldValue/Timestamp statics.
const { FieldValue } = require("firebase-admin/firestore");

const db = () => admin.firestore();

/** The public part of a user doc (null when there's no user doc). */
function publicFields(u) {
  if (!u) return null;
  const rating = Number(u.owner_rating_scores ?? u.rating ?? 0) || 0;
  return {
    name: typeof u.name === "string" ? u.name : "",
    profile_img_url: typeof u.profile_img_url === "string" ? u.profile_img_url : "",
    bio: typeof u.bio === "string" ? u.bio : "",
    owner_rating_scores: rating,
    owner_rating_count: Number(u.owner_rating_count || 0) || 0,
    is_student: u.is_student === true,
    // Only "deleted" is public; whether someone is banned is not.
    status: u.status === "deleted" ? "deleted" : "active",
  };
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

async function syncPublicProfile(uid, before, after) {
  const ref = db().collection("public_profiles").doc(uid);
  const next = publicFields(after);
  if (!next) {
    await ref.delete();
    return "deleted";
  }
  if (before && same(publicFields(before), next)) return "unchanged";
  await ref.set({ ...next, updated_at: FieldValue.serverTimestamp() });
  return "written";
}

exports.onUserWrittenSyncPublic = onDocumentWritten("users/{uid}", (event) => {
  const data = (s) => (s && s.exists ? s.data() : null);
  return syncPublicProfile(event.params.uid, data(event.data && event.data.before), data(event.data && event.data.after));
});

exports._internal = { publicFields, syncPublicProfile };
