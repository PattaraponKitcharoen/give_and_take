// Offline test of want-based matching (functions/matching.js) against an in-memory fake Firestore
// with vector search, and a fake Gemini embedder (no emulator, no network, no API key).
// Run from the project root:  node functions/test/matching.offline.test.js
const Module = require("module");
const path = require("path");
class HttpsError extends Error { constructor(code, msg) { super(msg); this.code = code; } }

const DIM = 768;
// Fake embedder: each concept word owns one dimension, so texts about the same
// thing are identical vectors and unrelated ones are orthogonal.
const CONCEPTS = ["หูฟัง", "โยคะ", "หนังสือ", "โคมไฟ", "กล้อง"];
const vecFor = (text) => {
  const v = new Array(DIM).fill(0);
  CONCEPTS.forEach((c, i) => { if (text.includes(c)) v[i] = 1; });
  v[DIM - 1] = 0.01; // never all-zero
  return v;
};
let embedCalls = [];
class FakeGenAI {
  constructor() {
    this.models = { embedContent: async (req) => { embedCalls.push(req); return { embeddings: [{ values: vecFor(req.contents) }] }; } };
  }
}

let store = {};
let pushes = [];
const cos = (a, b) => { let d = 0, x = 0, y = 0; for (let i = 0; i < a.length; i++) { d += a[i] * b[i]; x += a[i] ** 2; y += b[i] ** 2; } return d / Math.sqrt(x * y); };
const snapOf = (p, extra = {}) => ({
  id: p.split("/").pop(), ref: ref(p), exists: p in store,
  data: () => (p in store ? { ...store[p], ...extra } : undefined),
  get: (f) => ({ ...store[p], ...extra })[f],
});
const ref = (p) => ({
  path: p, id: p.split("/").pop(),
  get: async () => snapOf(p),
  set: async (d) => { store[p] = { ...d }; },
  update: async (d) => {
    if (!(p in store)) throw new Error("missing " + p);
    const next = { ...store[p], ...d };
    for (const k of Object.keys(d)) if (d[k] === "DEL") delete next[k];
    store[p] = next;
  },
  create: async (d) => { if (p in store) { const e = new Error("exists"); e.code = 6; throw e; } store[p] = { ...d }; },
  delete: async () => { delete store[p]; },
});
const query = (p, filters = []) => {
  const run = () => Object.keys(store)
    .filter((k) => k.startsWith(p + "/") && k.split("/").length === p.split("/").length + 1)
    .filter((k) => filters.every(([f, op, v]) => (op === "==" ? store[k][f] === v : (store[k][f] || []).includes(v))));
  return {
    where: (f, op, v) => query(p, [...filters, [f, op, v]]),
    get: async () => { const docs = run().map((k) => snapOf(k)); return { empty: docs.length === 0, size: docs.length, docs }; },
    findNearest: ({ vectorField, queryVector, limit, distanceResultField }) => ({
      get: async () => {
        const docs = run().filter((k) => Array.isArray(store[k][vectorField]))
          .map((k) => ({ k, dist: 1 - cos(store[k][vectorField], queryVector) }))
          .sort((a, b) => a.dist - b.dist).slice(0, limit)
          .map(({ k, dist }) => snapOf(k, { [distanceResultField]: dist }));
        return { empty: docs.length === 0, docs };
      },
    }),
  };
};
const col = (p) => ({ doc: (id) => ref(p + "/" + id), where: (...a) => query(p).where(...a), get: () => query(p).get() });
let clock = 1_000_000_000_000;
Date.now = () => clock; // rescan cooldown reads the time
const db = {
  collection: (n) => col(n),
  runTransaction: async (fn) => {
    const ops = [];
    const out = await fn({ get: (r) => r.get(), update: (r, d) => ops.push(() => r.update(d)) });
    for (const o of ops) await o();
    return out;
  },
  batch: () => { const ops = []; return { delete: (r) => ops.push(() => delete store[r.path]), commit: async () => ops.forEach((o) => o()) }; },
};
const adminMock = {
  initializeApp() {},
  firestore: Object.assign(() => db, { FieldValue: { serverTimestamp: () => "TS", delete: () => "DEL", vector: (v) => v },
    Timestamp: { now: () => { const t = clock; return { toMillis: () => t }; } } }),
  messaging: () => ({ send: async (m) => { pushes.push(m); } }),
};
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-functions/v2/https") return { onCall: (a, b) => b || a, HttpsError };
  if (req === "firebase-functions/v2/firestore") return { onDocumentWritten: (_o, f) => f, onDocumentUpdated: (_o, f) => f };
  if (req === "firebase-functions/v2/scheduler") return { onSchedule: (_o, f) => f };
  if (req === "firebase-functions/params") return { defineSecret: () => ({ value: () => "test-key" }) };
  if (req === "firebase-functions/logger") return { error() {}, warn() {}, info() {} };
  if (req === "@google/genai") return { GoogleGenAI: FakeGenAI };
  return orig.call(this, req, ...a);
};
const m = require(path.join(__dirname, "..", "matching.js"));

// Fire a trigger the way Firestore would after a write to `p`.
const written = async (fn, p, params) => fn({
  params,
  data: { after: { exists: p in store, data: () => store[p], ref: ref(p) } },
});
const putListing = async (id, d) => { store[`listings/${id}`] = { status: "active", estimated_coins: 100, ...d }; await written(m.onListingWrittenForMatching, `listings/${id}`, { listingId: id }); };
const putWant = async (id, d) => { store[`wants/${id}`] = { status: "active", ...d }; await written(m.onWantWrittenForMatching, `wants/${id}`, { wantId: id }); };
const dropWant = async (id) => { delete store[`wants/${id}`]; await written(m.onWantWrittenForMatching, `wants/${id}`, { wantId: id }); };
const matches = () => Object.keys(store).filter((k) => k.startsWith("matches/"));

let fail = 0;
const check = (name, ok, detail) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + (ok ? "" : "   <-- " + detail)); };

(async () => {
  const world = async () => {
    store = { "users/A": { name: "A", fcm_token: "tA" }, "users/B": { name: "B", fcm_token: "tB" }, "users/C": { name: "C", fcm_token: "tC" } };
    pushes = []; embedCalls = [];
    await putListing("LA", { owner_id: "A", title: "เสื่อโยคะ หนา 6mm", estimated_coins: 300 });
    await putListing("LB", { owner_id: "B", title: "หูฟังบลูทูธ JBL", estimated_coins: 350 });
    await putListing("LC", { owner_id: "C", title: "หูฟัง Sony", estimated_coins: 400 });
    await putWant("WB", { owner_id: "B", text: "เสื่อโยคะ" });
    await putWant("WC", { owner_id: "C", text: "หนังสือเตรียมสอบ" });
  };

  await world();
  check("MAT-01 listing vector stored apart from the listing",
    Array.isArray(store["listing_vectors/LA"]?.embedding) && store["listings/LA"].embedding === undefined && store["listing_vectors/LA"].owner_id === "A",
    JSON.stringify(Object.keys(store["listing_vectors/LA"] || {})));
  check("MAT-02 listings embedded as documents, wants as queries",
    embedCalls.filter((c) => c.config.taskType === "RETRIEVAL_DOCUMENT").length === 3 &&
    embedCalls.filter((c) => c.config.taskType === "RETRIEVAL_QUERY").length === 2 &&
    embedCalls.every((c) => c.config.outputDimensionality === DIM), JSON.stringify(embedCalls.map((c) => c.config)));
  check("MAT-03 no match while nobody wants what the other has", matches().length === 0, matches().join());

  await putWant("WA", { owner_id: "A", text: "หูฟังไร้สาย" });
  const id = "LA__LB";
  const doc = store["matches/" + id];
  check("MAT-04 two-way match A<->B created (C only one-way, skipped)",
    matches().length === 1 && !!doc && doc.members.includes("A") && doc.members.includes("B"), matches().join());
  check("MAT-05 each side says what it gives, gets and which want matched",
    doc && doc.sides.A.give_listing_id === "LA" && doc.sides.A.get_listing_id === "LB" && doc.sides.A.want_id === "WA" &&
    doc.sides.B.give_listing_id === "LB" && doc.sides.B.get_listing_id === "LA" && doc.sides.B.want_text === "เสื่อโยคะ" &&
    doc.seen_by.length === 0, JSON.stringify(doc && doc.sides));
  check("MAT-06 both users pushed once", pushes.map((p) => p.token).sort().join() === "tA,tB" &&
    pushes.every((p) => p.data.type === "new_match" && p.data.match_id === id), JSON.stringify(pushes.map((p) => p.token)));

  const calls = embedCalls.length;
  await written(m.onWantWrittenForMatching, "wants/WA", { wantId: "WA" }); // echo of its own embedding write
  check("MAT-07 trigger echo does not re-embed", embedCalls.length === calls, embedCalls.length - calls);
  store["listings/LA"].estimated_coins = 320;
  await written(m.onListingWrittenForMatching, "listings/LA", { listingId: "LA" });
  check("MAT-08 editing only the price keeps the vector, updates coins",
    embedCalls.length === calls && store["listing_vectors/LA"].estimated_coins === 320, embedCalls.length - calls);

  pushes = [];
  store["matches/" + id].seen_by = ["A"];
  const before09 = embedCalls.length;
  const r09 = await m.rescanMatches({ auth: { uid: "A" }, data: {} });
  check("MAT-09 rescan finds the same match again without a second push, resetting seen, or calling Gemini",
    !r09.throttled && matches().length === 1 && pushes.length === 0 && store["matches/" + id].seen_by[0] === "A" && embedCalls.length === before09,
    JSON.stringify(r09));
  clock += 10 * 60 * 1000;
  const r09b = await m.rescanMatches({ auth: { uid: "A" }, data: {} });
  check("MAT-09b second rescan within the hour is refused with minutes to wait",
    r09b.throttled === true && r09b.retry_after_minutes === 50, JSON.stringify(r09b));
  clock += 51 * 60 * 1000;
  const r09c = await m.rescanMatches({ auth: { uid: "A" }, data: {} });
  check("MAT-09c rescan allowed again after an hour", r09c.throttled === false, JSON.stringify(r09c));

  store["listings/LB"].status = "in_progress";
  await written(m.onListingWrittenForMatching, "listings/LB", { listingId: "LB" });
  check("MAT-10 listing going into a deal removes its matches", matches().length === 0, matches().join());
  pushes = [];
  store["listings/LB"].status = "active";
  await written(m.onListingWrittenForMatching, "listings/LB", { listingId: "LB" });
  check("MAT-11 deal cancelled -> listing active again -> match comes back", matches().length === 1 && pushes.length === 2, matches().join());

  await dropWant("WB");
  check("MAT-12 deleting a want removes its matches", matches().length === 0, matches().join());

  await world();
  store["users/B"].match_enabled = false;
  await putWant("WA", { owner_id: "A", text: "หูฟังไร้สาย" });
  check("MAT-13 user who turned matching off is not matched", matches().length === 0, matches().join());

  await world();
  await putWant("WA", { owner_id: "A", text: "หูฟังไร้สาย" });
  store["wants/WA"].text = "โคมไฟตั้งโต๊ะ";
  await written(m.onWantWrittenForMatching, "wants/WA", { wantId: "WA" });
  check("MAT-14 changing a want's text drops matches the old text found", matches().length === 0, matches().join());

  await world();
  store["listings/LD"] = { owner_id: "C", status: "active", title: "หนังสือเตรียมสอบ TOEIC", estimated_coins: 150 }; // predates matching: no vector
  store["users/A"].fcm_token = undefined;
  await putWant("WA2", { owner_id: "A", text: "หนังสือ" });
  check("MAT-15 a listing without a vector is invisible before backfill", matches().length === 0, matches().join());
  await putWant("WC", { owner_id: "C", text: "เสื่อโยคะ" });
  const rs = await m.rescanMatches({ auth: { uid: "A" }, data: {} });
  check("MAT-16 rescan no longer embeds old listings", !store["listing_vectors/LD"] && rs.created === 0, JSON.stringify(rs));
  store["match_meta/backfill"] = { status: "requested" };
  const fire = () => written(m.onBackfillRequested, "match_meta/backfill", {});
  await fire();
  const bf = store["match_meta/backfill"];
  check("MAT-16b backfill trigger embeds every listing missing a vector and records the result",
    bf.status === "done" && bf.embedded === 1 && bf.failed === 0 && !!store["listing_vectors/LD"], JSON.stringify(bf));
  const callsAfter = embedCalls.length;
  await fire(); // echo of its own "done" write
  check("MAT-16c backfill does not re-run on its own status write", embedCalls.length === callsAfter, embedCalls.length - callsAfter);
  clock += 2 * 60 * 60 * 1000;
  const r = await m.rescanMatches({ auth: { uid: "A" }, data: {} });
  check("MAT-16d after backfill, a rescan matches the old listing", r.created === 1 && !!store["matches/LA__LD"], JSON.stringify(r));
  check("MAT-17 user without a push token is skipped, the other still pushed",
    pushes.filter((p) => p.data.match_id === "LA__LD").map((p) => p.token).join() === "tC", JSON.stringify(pushes.map((p) => p.token)));

  for (let i = 0; i < 11; i++) store[`wants/X${i}`] = { owner_id: "B", status: "active", text: "กล้อง" };
  const before = embedCalls.length;
  await written(m.onWantWrittenForMatching, "wants/X10", { wantId: "X10" });
  check("MAT-18 more than 10 wants: extra want not embedded", embedCalls.length === before, embedCalls.length - before);

  let code;
  try { await m.rescanMatches({ auth: null, data: {} }); } catch (e) { code = e.code; }
  check("MAT-19 rescan needs sign-in", code === "unauthenticated", code);
  store["users/A"].status = "banned";
  code = undefined;
  try { await m.rescanMatches({ auth: { uid: "A" }, data: {} }); } catch (e) { code = e.code; }
  check("MAT-20 banned user can't rescan", code === "permission-denied", code);

  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
