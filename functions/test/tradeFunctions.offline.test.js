// Offline test of the trade Cloud Functions (accept / confirm OTP / cancel / review) against an in-memory fake Firestore (no emulator, no network).
// Run from the project root:  node functions/test/tradeFunctions.offline.test.js
const Module = require("module");
const path = require("path");
class HttpsError extends Error { constructor(code, msg) { super(msg); this.code = code; } }
let store = {};
let auto = 0;
const ref = (p) => ({
  path: p, id: p.split("/").pop(),
  collection: (n) => col(p + "/" + n),
});
const query = (p, filters = []) => ({
  isQuery: true,
  where: (f, op, v) => query(p, [...filters, [f, op, v]]),
  limit: () => query(p, filters),
  get: async () => { const docs = query(p, filters).run(); return { empty: docs.length === 0, docs }; },
  run: () => Object.keys(store)
    .filter((k) => k.startsWith(p + "/") && k.split("/").length === p.split("/").length + 1)
    .filter((k) => filters.every(([f, op, v]) => (op === "==" ? store[k][f] === v : (store[k][f] || []).includes(v))))
    .map((k) => ({ ref: ref(k), data: () => store[k] })),
});
const col = (p) => ({ doc: (id) => ref(p + "/" + (id || "auto" + (++auto))), where: (...a) => query(p).where(...a) });
const db = {
  collection: (n) => col(n),
  batch: () => {
    const writes = [];
    return {
      update: (r, d) => writes.push(() => { store[r.path] = { ...store[r.path], ...d }; }),
      commit: async () => writes.forEach((w) => w()),
    };
  },
  runTransaction: async (fn) => {
    const writes = [];
    const tx = {
      get: async (r) => {
        if (r.isQuery) { const docs = r.run(); return { empty: docs.length === 0, docs }; }
        return { exists: r.path in store, data: () => store[r.path], ref: r, id: r.id };
      },
      set: (r, d) => writes.push(() => { store[r.path] = { ...d }; }),
      update: (r, d) => writes.push(() => { if (!(r.path in store)) throw new Error("missing " + r.path); store[r.path] = { ...store[r.path], ...d }; }),
    };
    const out = await fn(tx);
    writes.forEach((w) => w());
    return out;
  },
};
const adminMock = { initializeApp() {}, firestore: Object.assign(() => db, { FieldValue: { serverTimestamp: () => "TS", delete: () => "DEL" } }), messaging: () => ({}) };
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-functions") return {};
  if (req === "firebase-functions/v2") return { setGlobalOptions() {} };
  if (req === "firebase-functions/v2/https") return { onCall: (f) => f, HttpsError };
  if (req === "firebase-functions/v2/firestore") return { onDocumentCreated: (_p, f) => f };
  if (req === "firebase-functions/logger") return { error() {}, warn() {}, info() {} };
  return orig.call(this, req, ...a);
};
const fns = require(path.resolve(process.argv[2] || path.join(__dirname, "..", "index.js")));
const seed = (over = {}) => {
  store = {
    "users/A": { name: "A", coins_balance: 100 }, "users/B": { name: "B", coins_balance: 100 }, "users/C": { name: "C", coins_balance: 100 },
    "listings/LA": { owner_id: "A", status: "active" }, "listings/LB": { owner_id: "B", status: "active" },
    "offers/O1": { sender_id: "A", target_user_id: "B", target_listing_id: "LB", offered_listing_id: "LA", coin_offset: 0, status: "pending", last_offer_by: "A" },
    "chat_rooms/R1": {},
  };
  for (const [k, v] of Object.entries(over)) store[k] = { ...store[k], ...v };
};
const call = async (uid, data = { offerId: "O1", roomId: "R1" }) => {
  try { await fns.acceptTradeOffer({ auth: uid ? { uid } : null, data }); return "OK"; } catch (e) { return e.code; }
};
let fail = 0;
const t = async (name, expect, setup, uid, check) => {
  setup();
  const got = await call(uid);
  const extra = got === "OK" && check ? check() : true;
  const ok = got === expect && extra;
  if (!ok) fail++;
  console.log((ok ? "PASS" : "FAIL") + "  " + name + "  -> " + got + (extra ? "" : " (state check failed)"));
};
(async () => {
  await t("ACC-01 owner accepts sender's offer", "OK", () => seed(), "B", () => store["offers/O1"].status === "accepted" && store["listings/LA"].status === "in_progress" && store["listings/LB"].status === "in_progress");
  await t("ACC-02 sender accepts owner's counter-offer", "OK", () => seed({ "offers/O1": { last_offer_by: "B", coin_offset: -20 } }), "A", () => store["users/B"].coins_balance === 80 && store["users/A"].coins_balance === 100);
  await t("ACC-03 escrow: sender pays", "OK", () => seed({ "offers/O1": { coin_offset: 50 } }), "B", () => store["users/A"].coins_balance === 50 && store["users/B"].coins_balance === 100);
  await t("ACC-05 payer has too few coins", "failed-precondition", () => seed({ "offers/O1": { coin_offset: 500 } }), "B");
  await t("ACC-07 accept twice", "failed-precondition", () => seed({ "offers/O1": { status: "accepted" } }), "B");
  await t("ACC-08 target listing already in a deal", "failed-precondition", () => seed({ "listings/LB": { status: "in_progress" } }), "B");
  await t("ACC-09 offered listing already in a deal", "failed-precondition", () => seed({ "listings/LA": { status: "in_progress" } }), "B");
  await t("ACC-11 outsider accepts", "permission-denied", () => seed(), "C");
  await t("ACC-12 owner accepts own counter-offer", "failed-precondition", () => seed({ "offers/O1": { last_offer_by: "B", coin_offset: 90 } }), "B");
  await t("ACC-12b sender accepts own original offer", "failed-precondition", () => seed(), "A");
  await t("ACC-13 not signed in", "unauthenticated", () => seed(), null);
  await t("offer names wrong owner of target listing", "failed-precondition", () => seed({ "listings/LB": { owner_id: "C" } }), "B");
  await t("offer uses someone else's item", "failed-precondition", () => seed({ "listings/LA": { owner_id: "C" } }), "B");
  await t("legacy offer without last_offer_by: owner accepts", "OK", () => { seed(); delete store["offers/O1"].last_offer_by; }, "B");
  // ---------------------------------------------------------------- confirm / cancel / review
  const deal = (offset) => {
    seed({ "offers/O1": { coin_offset: offset } });
    return call("B");
  };
  const fn = async (name, uid, data) => {
    try { await fns[name]({ auth: uid ? { uid } : null, data }); return "OK"; } catch (e) { return e.code; }
  };
  const txOf = () => Object.entries(store).find(([k]) => k.startsWith("transactions/"));
  const check = (name, ok, got) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + "  -> " + got); };
  let got;

  await deal(50);
  got = await fn("confirmHandoverOtp", "A", { offerId: "O1", inputOtp: "000000" });
  check("OTP-06 wrong code rejected", got === "invalid-argument" && txOf()[1].status === "in_progress", got);
  got = await fn("confirmHandoverOtp", "A", { offerId: "O1", inputOtp: txOf()[1].verification_codes.A });
  check("OTP-07 own code rejected", got === "invalid-argument", got);
  got = await fn("confirmHandoverOtp", "C", { offerId: "O1", inputOtp: txOf()[1].verification_codes.B });
  check("OTP-15 outsider rejected", got === "not-found", got);
  got = await fn("confirmHandoverOtp", "A", { offerId: "O1", inputOtp: txOf()[1].verification_codes.B });
  check("OTP-03/04 correct code completes deal, payee gets coins",
    got === "OK" && txOf()[1].status === "completed" && store["offers/O1"].status === "completed" &&
    store["listings/LA"].status === "completed" && store["listings/LB"].status === "completed" &&
    store["users/A"].coins_balance === 50 && store["users/B"].coins_balance === 150, got);
  got = await fn("confirmHandoverOtp", "B", { offerId: "O1", inputOtp: txOf()[1].verification_codes.A });
  check("OTP-11 confirming twice pays once", got === "failed-precondition" && store["users/B"].coins_balance === 150, got);

  const txId = txOf()[0].split("/")[1];
  got = await fn("submitTradeReview", "A", { revieweeId: "B", transactionId: txId, rating: 4, comment: "ok" });
  check("REV-01 review after completed deal", got === "OK" && store["users/B"].owner_rating_count === 1 && store["users/B"].owner_rating_scores === 4, got);
  const rev = Object.entries(store).find(([k]) => k.startsWith("reviews/"))[1];
  check("REV-12 review carries both traded items (public, no deal docs needed)",
    rev.reviewer_item && rev.reviewer_item.listing_id === "LA" && rev.reviewee_item && rev.reviewee_item.listing_id === "LB" &&
    rev.reviewee_item.owner_id === "B" && "title" in rev.reviewee_item && "thumbnail_url" in rev.reviewee_item,
    JSON.stringify([rev.reviewer_item && rev.reviewer_item.listing_id, rev.reviewee_item && rev.reviewee_item.listing_id]));
  check("REV-13 rating copied onto every listing of the reviewee only",
    store["listings/LB"].owner_rating_scores === 4 && store["listings/LA"].owner_rating_scores === undefined,
    JSON.stringify([store["listings/LB"].owner_rating_scores, store["listings/LA"].owner_rating_scores]));
  got = await fn("submitTradeReview", "A", { revieweeId: "B", transactionId: txId, rating: 5 });
  check("REV-06 second review rejected", got === "already-exists" && store["users/B"].owner_rating_count === 1, got);
  got = await fn("submitTradeReview", "C", { revieweeId: "B", transactionId: txId, rating: 5 });
  check("REV-08 outsider review rejected", got === "permission-denied", got);

  await deal(-30);
  got = await fn("submitTradeReview", "A", { revieweeId: "B", transactionId: txOf()[0].split("/")[1], rating: 5 });
  check("REV-08 review before deal completes rejected", got === "failed-precondition", got);
  got = await fn("cancelAcceptedTrade", "C", { offerId: "O1", reason: "x" });
  check("CAN-09 outsider cancel rejected", got === "not-found", got);
  got = await fn("cancelAcceptedTrade", "A", { offerId: "O1", reason: "changed mind", roomId: "R1" });
  check("CAN-03 cancel refunds the payer and reopens both items",
    got === "OK" && store["users/B"].coins_balance === 100 && txOf()[1].status === "cancelled" &&
    store["offers/O1"].status === "cancelled" && store["listings/LA"].status === "active" && store["listings/LB"].status === "active", got);
  got = await fn("cancelAcceptedTrade", "B", { offerId: "O1", reason: "again" });
  check("CAN-04 cancelling twice refunds once", got === "failed-precondition" && store["users/B"].coins_balance === 100, got);

  // OTP codes: independent, 6 digits, different
  const diffs = new Set(); let bad = 0;
  for (let i = 0; i < 300; i++) {
    seed(); await call("B");
    const tx = Object.entries(store).find(([k]) => k.startsWith("transactions/"))[1];
    const [a, b] = [tx.verification_codes.A, tx.verification_codes.B];
    if (!/^\d{6}$/.test(a) || !/^\d{6}$/.test(b) || a === b) bad++;
    diffs.add(Number(b) - Number(a));
  }
  const otpOk = bad === 0 && diffs.size > 250 && !(diffs.size === 1 && diffs.has(400000));
  if (!otpOk) fail++;
  console.log((otpOk ? "PASS" : "FAIL") + "  OTP-02 codes independent: " + diffs.size + " distinct differences in 300 deals, malformed=" + bad);
  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
