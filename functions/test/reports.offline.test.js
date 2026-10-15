// Offline test of reports + admin moderation (functions/reports.js) against an in-memory fake Firestore.
// Run from the project root:  node functions/test/reports.offline.test.js
const Module = require("module");
const path = require("path");
class HttpsError extends Error { constructor(code, msg) { super(msg); this.code = code; } }

let store = {};
let pushes = [];
let auto = 0;
const ts = (ms) => ({ toMillis: () => ms });
const applyUpdate = (p, d) => {
  if (!(p in store)) throw new Error("missing " + p);
  const next = { ...store[p], ...d };
  for (const k of Object.keys(d)) if (d[k] === "DEL") delete next[k];
  store[p] = next;
};
const snapOf = (p) => ({ id: p.split("/").pop(), ref: ref(p), exists: p in store, data: () => store[p] });
const ref = (p) => ({
  path: p, id: p.split("/").pop(),
  get: async () => snapOf(p),
  update: async (d) => applyUpdate(p, d),
  collection: (n) => col(p + "/" + n),
});
const query = (p, filters = [], order = null, lim = Infinity) => ({
  where: (f, op, v) => query(p, [...filters, [f, op, v]], order, lim),
  orderBy: (f, dir) => query(p, filters, [f, dir], lim),
  limit: (n) => query(p, filters, order, n),
  get: async () => {
    let keys = Object.keys(store)
      .filter((k) => k.startsWith(p + "/") && k.split("/").length === p.split("/").length + 1)
      .filter((k) => filters.every(([f, , v]) => store[k][f] === v));
    if (order) {
      const [f, dir] = order;
      keys.sort((a, b) => (store[a][f].toMillis() - store[b][f].toMillis()) * (dir === "desc" ? -1 : 1));
    }
    const docs = keys.slice(0, lim).map(snapOf);
    return { size: docs.length, empty: !docs.length, docs };
  },
});
const col = (p) => ({
  doc: (id) => ref(p + "/" + id),
  where: (...a) => query(p).where(...a),
  orderBy: (...a) => query(p).orderBy(...a),
  add: async (d) => { const k = `${p}/auto${++auto}`; store[k] = d; return ref(k); },
});
const db = {
  collection: (n) => col(n),
  batch: () => { const ops = []; return { update: (r, d) => ops.push(() => applyUpdate(r.path, d)), commit: async () => ops.forEach((o) => o()) }; },
};
const NOW = 1_800_000_000_000;
const adminMock = {
  initializeApp() {},
  firestore: Object.assign(() => db, {
    FieldValue: { serverTimestamp: () => "TS", delete: () => "DEL" },
    Timestamp: { now: () => ts(NOW), fromMillis: (ms) => ts(ms) },
  }),
  messaging: () => ({ send: async (m) => pushes.push(m) }),
  auth: () => ({
    getUser: async (uid) => { if (!authUsers[uid]) throw new Error("no user"); return authUsers[uid]; },
    updateUser: async (uid, d) => { authUsers[uid] = { ...authUsers[uid], ...d }; },
  }),
};
let authUsers = {};
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-functions/v2/firestore") return { onDocumentCreated: (_p, f) => f };
  if (req === "firebase-functions/v2/https") return { onCall: (a, b) => b || a, HttpsError };
  if (req === "firebase-functions/logger") return { error() {}, warn() {}, info() {} };
  return orig.call(this, req, ...a);
};
const m = require(path.join(__dirname, "..", "reports.js"));

const created = (id) => m.onReportCreated({ params: { reportId: id }, data: snapOf(`reports/${id}`) });
const moderate = async (uid, data) => {
  try { return await m.adminModerate({ auth: uid ? { uid } : null, data }); } catch (e) { return { code: e.code }; }
};
let fail = 0;
const check = (name, ok, detail) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + (ok ? "" : "   <-- " + detail)); };

(async () => {
  const seed = () => {
    store = {
      "users/ADMIN": { role: "admin", name: "Admin" },
      "users/A": { name: "Alice", fcm_token: "tA" },
      "users/B": { name: "Bob", fcm_token: "tB", bio: "hi" },
      "users/C": { name: "Cat", fcm_token: "tC" },
      "listings/LB": { owner_id: "B", status: "active", title: "iPhone ปลอม", description: "แท้ 100%", images: [{ url: "u1" }] },
      "listings/LB_busy": { owner_id: "B", status: "in_progress", title: "busy" },
      "chat_rooms/R": { members: ["A", "B"] },
    };
    for (let i = 0; i < 35; i++) {
      store[`chat_rooms/R/messages/m${i}`] = { sender_id: i % 2 ? "A" : "B", content: `msg ${i}`, type: "text", timestamp: ts(NOW + i) };
    }
    pushes = [];
  };
  const report = (id, d) => { store[`reports/${id}`] = { status: "open", reason: "x", detail: "", created_at: ts(NOW), ...d }; return created(id); };

  seed();
  await report("A_listing_LB", { reporter_id: "A", target_type: "listing", target_id: "LB", reason: "ของปลอม" });
  let r = store["reports/A_listing_LB"];
  check("REP-01 listing report gets owner + evidence copy",
    r.target_user_id === "B" && r.target_title === "iPhone ปลอม" && r.snapshot.description === "แท้ 100%" && r.snapshot.images[0] === "u1", JSON.stringify(r));

  await report("A_chat_R", { reporter_id: "A", target_type: "chat", target_id: "R", reason: "คุกคาม" });
  r = store["reports/A_chat_R"];
  const msgs = r.snapshot.messages;
  check("REP-02 chat report keeps the last 30 messages, oldest first, and names the other member",
    r.target_user_id === "B" && msgs.length === 30 && msgs[0].content === "msg 5" && msgs[29].content === "msg 34" &&
    r.snapshot.member_names.B === "Bob", `${r.target_user_id} ${msgs.length} ${msgs[0] && msgs[0].content}`);

  await report("C_user_B", { reporter_id: "C", target_type: "user", target_id: "B", reason: "โกง" });
  check("REP-03 user report copies the profile", store["reports/C_user_B"].snapshot.name === "Bob" && store["reports/C_user_B"].target_user_id === "B", "");

  await report("A_listing_GONE", { reporter_id: "A", target_type: "listing", target_id: "GONE" });
  check("REP-04 report on a deleted target is flagged", store["reports/A_listing_GONE"].target_missing === true, "");

  check("REP-05 non-admin can't moderate", (await moderate("A", { action: "dismiss", report: { type: "listing", id: "LB" } })).code === "permission-denied", "");
  check("REP-06 ban needs a reason", (await moderate("ADMIN", { action: "ban_listing", listingId: "LB" })).code === "invalid-argument", "");
  check("REP-07 can't ban a listing that's mid-deal", (await moderate("ADMIN", { action: "ban_listing", listingId: "LB_busy", reason: "x" })).code === "failed-precondition", "");

  pushes = [];
  let out = await moderate("ADMIN", { action: "ban_listing", listingId: "LB", reason: "ของปลอม", report: { type: "listing", id: "LB" } });
  check("REP-08 ban listing: banned with reason, its report resolved, others untouched",
    out.ok && store["listings/LB"].status === "banned" && store["listings/LB"].ban_reason === "ของปลอม" &&
    store["reports/A_listing_LB"].status === "resolved" && store["reports/A_listing_LB"].resolution.action === "ban_listing" &&
    store["reports/A_chat_R"].status === "open", JSON.stringify(out));
  check("REP-09 owner told why, reporter told it was reviewed",
    pushes.some((p) => p.token === "tB" && p.notification.body.includes("ของปลอม")) &&
    pushes.some((p) => p.token === "tA" && p.data.type === "report_reviewed"), JSON.stringify(pushes.map((p) => p.token)));
  const log = Object.entries(store).find(([k, v]) => k.startsWith("admin_actions/") && v.action === "ban_listing");
  check("REP-10 action logged with the reports it closed", log && log[1].reports_closed.includes("A_listing_LB") && log[1].admin_id === "ADMIN", "");

  out = await moderate("ADMIN", { action: "unban_listing", listingId: "LB" });
  check("REP-11 unban listing clears status and reason", store["listings/LB"].status === "active" && store["listings/LB"].ban_reason === undefined, JSON.stringify(out));

  pushes = [];
  out = await moderate("ADMIN", { action: "ban_user", userId: "B", reason: "คุกคาม", days: 7, report: { type: "chat", id: "R" } });
  const b = store["users/B"];
  check("REP-12 7-day ban sets status, reason and end time",
    b.status === "banned" && b.ban_reason === "คุกคาม" && b.banned_until.toMillis() === NOW + 7 * 864e5, JSON.stringify(b));
  check("REP-13 banning a user closes every open report about them",
    store["reports/A_chat_R"].status === "resolved" && store["reports/C_user_B"].status === "resolved" && out.reportsClosed === 2, JSON.stringify(out));
  check("REP-14 banned user and both reporters notified",
    ["tA", "tB", "tC"].every((t) => pushes.some((p) => p.token === t)), JSON.stringify(pushes.map((p) => p.token)));

  out = await moderate("ADMIN", { action: "ban_user", userId: "A", reason: "x", days: null });
  check("REP-15 permanent ban has no end time", store["users/A"].status === "banned" && store["users/A"].banned_until === undefined, JSON.stringify(store["users/A"]));
  out = await moderate("ADMIN", { action: "unban_user", userId: "A" });
  check("REP-16 unban clears every ban field",
    store["users/A"].status === "active" && store["users/A"].ban_reason === undefined && store["users/A"].banned_at === undefined, JSON.stringify(store["users/A"]));
  check("REP-17 admin can't be banned, nor ban themselves",
    (await moderate("ADMIN", { action: "ban_user", userId: "ADMIN", reason: "x" })).code === "invalid-argument", "");
  check("REP-18 bad duration rejected", (await moderate("ADMIN", { action: "ban_user", userId: "C", reason: "x", days: 0 })).code === "invalid-argument", "");

  seed();
  await report("A_user_C", { reporter_id: "A", target_type: "user", target_id: "C" });
  out = await moderate("ADMIN", { action: "dismiss", report: { type: "user", id: "C" }, note: "ไม่พบความผิด" });
  check("REP-19 dismiss closes the report without touching the user",
    store["reports/A_user_C"].status === "dismissed" && store["users/C"].status === undefined && out.reportsClosed === 1, JSON.stringify(out));

  seed();
  authUsers = { C: { emailVerified: false } };
  out = await moderate("ADMIN", { action: "verify_email", userId: "C" });
  const vlog = Object.values(store).find((v) => v.action === "verify_email");
  check("REP-20 verify_email marks Auth + user doc verified and logs it",
    out.ok && authUsers.C.emailVerified === true && store["users/C"].is_email_verified === true && vlog && vlog.target_user_id === "C",
    JSON.stringify(out));
  check("REP-21 verify_email for an unknown account fails", (await moderate("ADMIN", { action: "verify_email", userId: "NOPE" })).code === "not-found", "");
  check("REP-22 only admins can verify emails", (await moderate("A", { action: "verify_email", userId: "C" })).code === "permission-denied", "");

  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
