// Offline test of account deletion (functions/account.js) against an in-memory fake Firestore.
// Run from the project root:  node functions/test/account.offline.test.js
const Module = require("module");
const path = require("path");
class HttpsError extends Error { constructor(code, msg, details) { super(msg); this.code = code; this.details = details; } }

let store = {};
let auto = 0;
let authUsers = {};
let deletedFiles = [];
const ts = (ms) => ({ toMillis: () => ms });
const strip = (d) => { const o = { ...d }; for (const k of Object.keys(o)) if (o[k] === "DEL") delete o[k]; return o; };
const applyUpdate = (p, d) => {
  if (!(p in store)) throw new Error("missing " + p);
  store[p] = strip({ ...store[p], ...d });
};
const applySet = (p, d, opt) => { store[p] = strip(opt && opt.merge ? { ...(store[p] || {}), ...d } : d); };
const snapOf = (p) => ({ id: p.split("/").pop(), ref: ref(p), exists: p in store, data: () => store[p] });
const ref = (p) => ({
  path: p, id: p.split("/").pop(),
  get: async () => snapOf(p),
  update: async (d) => applyUpdate(p, d),
  set: async (d, opt) => applySet(p, d, opt),
  collection: (n) => col(p + "/" + n),
});
const matches = (doc, [f, op, v]) => (op === "array-contains" ? (doc[f] || []).includes(v) : doc[f] === v);
const query = (p, filters = []) => ({
  where: (f, op, v) => query(p, [...filters, [f, op, v]]),
  get: async () => {
    const docs = Object.keys(store)
      .filter((k) => k.startsWith(p + "/") && k.split("/").length === p.split("/").length + 1)
      .filter((k) => filters.every((f) => matches(store[k], f)))
      .map(snapOf);
    return { size: docs.length, empty: !docs.length, docs };
  },
});
const col = (p) => ({
  doc: (id) => ref(p + "/" + (id || `auto${++auto}`)),
  where: (...a) => query(p).where(...a),
});
const db = {
  collection: (n) => col(n),
  batch: () => {
    const ops = [];
    return {
      update: (r, d) => ops.push(() => applyUpdate(r.path, d)),
      set: (r, d, opt) => ops.push(() => applySet(r.path, d, opt)),
      delete: (r) => ops.push(() => { delete store[r.path]; }),
      commit: async () => ops.forEach((o) => o()),
    };
  },
};
const NOW = Date.now();
const notFound = () => Object.assign(new Error("no user"), { code: "auth/user-not-found" });
const adminMock = {
  initializeApp() {},
  firestore: Object.assign(() => db, {
    FieldValue: { serverTimestamp: () => "TS", delete: () => "DEL" },
    Timestamp: { now: () => ts(NOW) },
  }),
  auth: () => ({
    getUser: async (uid) => { if (!authUsers[uid]) throw notFound(); return authUsers[uid]; },
    deleteUser: async (uid) => { if (!authUsers[uid]) throw notFound(); delete authUsers[uid]; },
  }),
  storage: () => ({ bucket: () => ({ file: (p) => ({ delete: async () => deletedFiles.push(p) }) }) }),
};
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-admin/firestore") return adminMock.firestore;
  if (req === "firebase-functions/v2/firestore") return { onDocumentCreated: (_p, f) => f, onDocumentUpdated: (_p, f) => f };
  if (req === "firebase-functions/v2/scheduler") return { onSchedule: (_o, f) => f };
  if (req === "firebase-functions/v2/https") return { onCall: (a, b) => b || a, HttpsError };
  if (req === "firebase-functions/logger") return { error() {}, warn() {}, info() {} };
  return orig.call(this, req, ...a);
};
const m = require(path.join(__dirname, "..", "account.js"));
const { emailHash, storagePathOf, DELETED_NAME } = m._internal;

const nowS = () => Math.floor(Date.now() / 1000);
const del = async (uid, authTime = nowS()) => {
  try { return await m.deleteAccount({ auth: uid ? { uid, token: { auth_time: authTime } } : null, data: {} }); } catch (e) { return { code: e.code, message: e.message, details: e.details }; }
};
const signUp = async (uid, email) => {
  authUsers[uid] = { uid, email };
  store[`users/${uid}`] = { name: "New", status: "active", coins_balance: 1000 };
  await m.onUserProfileCreated({ params: { uid }, data: snapOf(`users/${uid}`) });
};
const url = (p) => `https://firebasestorage.googleapis.com/v0/b/demo.appspot.com/o/${encodeURIComponent(p)}?alt=media&token=t`;

function seed() {
  auto = 0;
  deletedFiles = [];
  authUsers = { A: { uid: "A", email: "Alice@Test.dev" }, B: { uid: "B", email: "bob@test.dev" } };
  store = {
    "users/A": { name: "Alice", email: "alice@test.dev", tel: "081", bio: "hi", status: "active", coins_balance: 700,
      profile_img_url: url("profile_images/a.jpg"), fcm_token: "tok", owner_rating_scores: 4.5, owner_rating_count: 2, created_at: ts(1) },
    "users/B": { name: "Bob", status: "active", coins_balance: 1000 },
    "listings/LA": { owner_id: "A", status: "active", title: "mat", thumbnail_url: url("listing_images/la.jpg"), images: [url("listing_images/la.jpg"), url("listing_images/la2.jpg")] },
    "listings/LA_done": { owner_id: "A", status: "completed", title: "old", owner_name: "Alice", owner_profile_img: "p" },
    "listings/LA_banned": { owner_id: "A", status: "banned", title: "x" },
    "listings/LB": { owner_id: "B", status: "active", title: "headphones" },
    "wants/W1": { owner_id: "A", text: "หูฟัง", status: "active" },
    "wants/W2": { owner_id: "B", text: "เสื่อ", status: "active" },
    "matches/M1": { members: ["A", "B"] },
    "matches/M2": { members: ["B", "C"] },
    "offers/O1": { sender_id: "A", target_user_id: "B", status: "pending" },
    "offers/O2": { sender_id: "B", target_user_id: "A", status: "pending" },
    "offers/O3": { sender_id: "A", target_user_id: "B", status: "completed" },
    "chat_rooms/R1": { members: ["A", "B"], active_offer_id: "O1" },
    "chat_rooms/R3": { members: ["A", "B"], active_offer_id: "O3" },
    "transactions/T1": { members: ["A", "B"], status: "completed" },
    "reviews/V1": { reviewer_id: "A", reviewee_id: "B", rating: 5 },
    "wallet_transactions/X1": { user_id: "A", amount: -300 },
  };
}

let fail = 0;
const check = (name, ok, detail) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + (ok ? "" : "   <-- " + detail)); };

(async () => {
  check("ACC-01 email hash ignores case and spaces", emailHash(" Alice@Test.dev ") === emailHash("alice@test.dev") && emailHash("") === null, "");
  check("ACC-02 storage path from a download URL", storagePathOf(url("listing_images/a b.jpg")) === "listing_images/a b.jpg" && storagePathOf("https://example.com/x.jpg") === null, "");

  seed();
  check("ACC-03 signed out: refused", (await del(null)).code === "unauthenticated", "");
  let out = await del("A", nowS() - 3600);
  check("ACC-04 sign-in older than 5 minutes: refused, nothing touched",
    out.code === "failed-precondition" && out.message === "requires-recent-login" && store["users/A"].name === "Alice" && authUsers.A, JSON.stringify(out));

  store["transactions/T2"] = { members: ["A", "B"], status: "in_progress" };
  out = await del("A");
  check("ACC-05 a trade in progress blocks deletion (with the count)",
    out.code === "failed-precondition" && out.message === "active-trades" && out.details.count === 1 && store["listings/LA"], JSON.stringify(out));
  delete store["transactions/T2"];

  out = await del("A");
  const u = store["users/A"];
  check("ACC-06 deletes the Auth account", out.ok === true && !authUsers.A, JSON.stringify(out));
  check("ACC-07 user doc becomes a tombstone without personal data",
    u.status === "deleted" && u.name === DELETED_NAME && u.coins_balance === 0 && u.email === undefined && u.tel === undefined &&
      u.bio === undefined && u.fcm_token === undefined && u.profile_img_url === undefined && u.deleted_at === "TS", JSON.stringify(u));
  check("ACC-08 keeps the rating history", u.owner_rating_scores === 4.5 && u.owner_rating_count === 2, JSON.stringify(u));
  check("ACC-09 untraded listings are deleted, traded ones anonymised",
    !store["listings/LA"] && !store["listings/LA_banned"] && store["listings/LA_done"].owner_name === DELETED_NAME &&
      store["listings/LA_done"].owner_profile_img === "" && store["listings/LB"], "");
  check("ACC-10 photos of deleted listings and the profile photo are removed",
    ["profile_images/a.jpg", "listing_images/la.jpg", "listing_images/la2.jpg"].every((p) => deletedFiles.includes(p)) && deletedFiles.length === 3,
    JSON.stringify(deletedFiles));
  check("ACC-11 own wants and matches go, others' stay",
    !store["wants/W1"] && store["wants/W2"] && !store["matches/M1"] && store["matches/M2"], "");
  const sys = Object.entries(store).filter(([k]) => k.startsWith("chat_rooms/R1/messages/")).map(([, v]) => v);
  check("ACC-12 pending offers (sent and received) are cancelled with a chat notice",
    !store["offers/O1"] && !store["offers/O2"] && store["offers/O3"] && sys.length === 1 && sys[0].type === "system_cancel" &&
      store["chat_rooms/R1"].last_message_type === "system_cancel", JSON.stringify(sys));
  check("ACC-13 chats, reviews, trades and wallet logs are kept",
    store["chat_rooms/R1"] && store["chat_rooms/R3"] && store["reviews/V1"] && store["transactions/T1"] && store["wallet_transactions/X1"], "");
  const rec = store[`deleted_accounts/${emailHash("alice@test.dev")}`];
  check("ACC-14 remembers the email as a hash only",
    rec && rec.deleted_at === "TS" && !JSON.stringify(store).includes("alice@test.dev"), JSON.stringify(rec));

  await signUp("A2", "ALICE@test.dev");
  check("ACC-15 signing up again with that email: 0 coins, not banned",
    store["users/A2"].coins_balance === 0 && store["users/A2"].status === "active", JSON.stringify(store["users/A2"]));
  await signUp("N", "new@test.dev");
  check("ACC-16 a new email keeps the sign-up 1,000 coins", store["users/N"].coins_balance === 1000, JSON.stringify(store["users/N"]));

  seed();
  store["users/A"] = { ...store["users/A"], status: "banned", ban_reason: "spam", banned_until: ts(NOW + 86400e3), banned_at: ts(NOW) };
  check("ACC-17 a banned user can still delete", (await del("A")).ok === true, "");
  await signUp("A3", "alice@test.dev");
  check("ACC-18 the running ban carries over to the new account",
    store["users/A3"].status === "banned" && store["users/A3"].ban_reason === "spam" && store["users/A3"].banned_until.toMillis() === NOW + 86400e3,
    JSON.stringify(store["users/A3"]));

  seed();
  store["users/A"] = { ...store["users/A"], status: "banned", ban_reason: "spam", banned_until: ts(NOW - 1000) };
  await del("A");
  await signUp("A4", "alice@test.dev");
  check("ACC-19 an expired ban doesn't carry over", store["users/A4"].status === "active" && store["users/A4"].coins_balance === 0, JSON.stringify(store["users/A4"]));

  seed();
  out = await del("A");
  out = await del("A");
  check("ACC-20 deleting again (retry after a partial failure) is harmless", out.ok === true || out.code === "failed-precondition", JSON.stringify(out));

  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
