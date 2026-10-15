// Offline test of account bans (functions/moderation.js) against an in-memory fake Firestore and Auth.
// Run from the project root:  node functions/test/moderation.offline.test.js
const Module = require("module");
const path = require("path");
class HttpsError extends Error { constructor(code, msg) { super(msg); this.code = code; } }

let store = {};
let authCalls = [];
const ts = (ms) => ({ toMillis: () => ms, ms });
const ref = (p) => ({
  path: p, id: p.split("/").pop(),
  get: async () => ({ exists: p in store, data: () => store[p] }),
});
const cmp = (a, op, b) => {
  const v = (x) => (x && x.ms !== undefined ? x.ms : x);
  if (op === "==") return a === b;
  if (op === "<=") return a !== undefined && v(a) <= v(b);
  throw new Error("op " + op);
};
const query = (p, filters = []) => ({
  where: (f, op, v) => query(p, [...filters, [f, op, v]]),
  get: async () => {
    const docs = Object.keys(store)
      .filter((k) => k.startsWith(p + "/") && k.split("/").length === 2)
      .filter((k) => filters.every(([f, op, v]) => cmp(store[k][f], op, v)))
      .map((k) => ({ id: k.split("/")[1], ref: ref(k), data: () => store[k] }));
    return { size: docs.length, empty: !docs.length, docs };
  },
});
const db = {
  collection: (n) => ({ doc: (id) => ref(n + "/" + id), where: (...a) => query(n).where(...a) }),
  batch: () => {
    const ops = [];
    return {
      update: (r, d) => ops.push(() => {
        const next = { ...store[r.path], ...d };
        for (const k of Object.keys(d)) if (d[k] === "DEL") delete next[k];
        store[r.path] = next;
      }),
      commit: async () => ops.forEach((o) => o()),
    };
  },
};
let NOW = 1_800_000_000_000;
const adminMock = {
  initializeApp() {},
  firestore: Object.assign(() => db, {
    FieldValue: { serverTimestamp: () => "TS", delete: () => "DEL" },
    Timestamp: { now: () => ts(NOW) },
  }),
  auth: () => ({
    updateUser: async (uid, d) => authCalls.push(["update", uid, d.disabled]),
    revokeRefreshTokens: async (uid) => authCalls.push(["revoke", uid]),
  }),
};
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-functions/v2/firestore") return { onDocumentUpdated: (_p, f) => f };
  if (req === "firebase-functions/v2/scheduler") return { onSchedule: (_o, f) => f };
  if (req === "firebase-functions/v2/https") return { HttpsError };
  if (req === "firebase-functions/logger") return { error() {}, warn() {}, info() {} };
  return orig.call(this, req, ...a);
};
const m = require(path.join(__dirname, "..", "moderation.js"));

// Simulate an admin edit of users/{uid} and fire the trigger.
const editUser = async (uid, change) => {
  const before = { ...store[`users/${uid}`] };
  const after = { ...before, ...change };
  for (const k of Object.keys(change)) if (change[k] === undefined) delete after[k];
  store[`users/${uid}`] = after;
  await m.onUserBanChanged({ params: { uid }, data: { before: { data: () => before }, after: { data: () => after } } });
};
const status = (id) => store[`listings/${id}`].status;

let fail = 0;
const check = (name, ok, detail) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + (ok ? "" : "   <-- " + detail)); };

(async () => {
  const seed = () => {
    store = {
      "users/U": { status: "active" },
      "listings/L1": { owner_id: "U", status: "active" },
      "listings/L2": { owner_id: "U", status: "active" },
      "listings/L3": { owner_id: "U", status: "in_progress" },
      "listings/L4": { owner_id: "U", status: "banned", ban_reason: "admin banned this one" },
      "listings/L5": { owner_id: "U", status: "completed" },
      "listings/OTHER": { owner_id: "V", status: "active" },
    };
    authCalls = [];
  };

  seed();
  await editUser("U", { status: "banned", ban_reason: "spam", banned_at: ts(NOW), banned_until: ts(NOW + 7 * 864e5) });
  check("MOD-01 temp ban hides only active listings, marked as hidden by the ban",
    status("L1") === "banned" && status("L2") === "banned" && store["listings/L1"].hidden_by_user_ban === true &&
    status("L3") === "in_progress" && status("L5") === "completed" && status("OTHER") === "active" &&
    store["listings/L4"].hidden_by_user_ban === undefined, JSON.stringify(store));
  check("MOD-02 temp ban keeps login", authCalls.length === 0, JSON.stringify(authCalls));

  await editUser("U", { status: "active", ban_reason: undefined, banned_at: undefined, banned_until: undefined });
  check("MOD-03 unban restores the hidden listings, not the one an admin banned separately",
    status("L1") === "active" && status("L2") === "active" && store["listings/L1"].hidden_by_user_ban === undefined &&
    status("L4") === "banned", JSON.stringify(store));

  seed();
  await editUser("U", { status: "banned", ban_reason: "fraud", banned_at: ts(NOW) });
  check("MOD-04 permanent ban disables login and signs out devices",
    JSON.stringify(authCalls) === JSON.stringify([["update", "U", true], ["revoke", "U"]]), JSON.stringify(authCalls));
  authCalls = [];
  await editUser("U", { banned_until: ts(NOW + 864e5) });
  check("MOD-05 permanent -> temporary turns login back on, listings stay hidden",
    JSON.stringify(authCalls) === JSON.stringify([["update", "U", false]]) && status("L1") === "banned", JSON.stringify(authCalls));
  authCalls = [];
  await editUser("U", { status: "active", ban_reason: undefined, banned_at: undefined, banned_until: undefined });
  check("MOD-06 unban from temporary: no auth change needed, listings back", authCalls.length === 0 && status("L1") === "active", JSON.stringify(authCalls));

  seed();
  store["users/A"] = { status: "banned", banned_until: ts(NOW - 1000) };
  store["users/B"] = { status: "banned", banned_until: ts(NOW + 1000) };
  store["users/C"] = { status: "banned", ban_reason: "forever" };
  const lifted = await m._internal.liftExpired(ts(NOW));
  check("MOD-07 hourly job lifts only expired temporary bans and clears the ban fields",
    lifted === 1 && store["users/A"].status === "active" && store["users/A"].banned_until === undefined &&
    store["users/B"].status === "banned" && store["users/C"].status === "banned", JSON.stringify(store));

  check("MOD-08 isBannedData: permanent, future, expired, active",
    m.isBannedData({ status: "banned" }, NOW) && m.isBannedData({ status: "banned", banned_until: ts(NOW + 1) }, NOW) &&
    !m.isBannedData({ status: "banned", banned_until: ts(NOW - 1) }, NOW) && !m.isBannedData({ status: "active" }, NOW), "");

  let code;
  store["users/Z"] = { status: "banned" };
  try { await m.assertNotBanned("Z"); } catch (e) { code = e.code; }
  check("MOD-09 assertNotBanned refuses a banned caller", code === "permission-denied", code);

  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
