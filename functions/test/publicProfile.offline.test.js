// Offline test of the public profile mirror (functions/publicProfile.js) against an in-memory fake Firestore.
// Run from the project root:  node functions/test/publicProfile.offline.test.js
const Module = require("module");
const path = require("path");

let store = {};
let writes = 0;
const ref = (p) => ({
  path: p,
  set: async (d) => { writes++; store[p] = d; },
  delete: async () => { writes++; delete store[p]; },
});
const db = { collection: (n) => ({ doc: (id) => ref(`${n}/${id}`) }) };
const adminMock = { initializeApp() {}, firestore: Object.assign(() => db, { FieldValue: { serverTimestamp: () => "TS" } }) };
const orig = Module._load;
Module._load = function (req, ...a) {
  if (req === "firebase-admin") return adminMock;
  if (req === "firebase-admin/firestore") return adminMock.firestore;
  if (req === "firebase-functions/v2/firestore") return { onDocumentWritten: (_p, f) => f };
  return orig.call(this, req, ...a);
};
const m = require(path.join(__dirname, "..", "publicProfile.js"));

const snap = (d) => (d ? { exists: true, data: () => d } : { exists: false, data: () => undefined });
const write = (uid, before, after) => m.onUserWrittenSyncPublic({ params: { uid }, data: { before: snap(before), after: snap(after) } });

let fail = 0;
const check = (name, ok, detail) => { if (!ok) fail++; console.log((ok ? "PASS" : "FAIL") + "  " + name + (ok ? "" : "   <-- " + detail)); };

const alice = {
  name: "Alice", email: "alice@test.dev", tel: "0812345678", bio: "hi", profile_img_url: "p.jpg",
  fcm_token: "tok", location: { latitude: 7.01, longitude: 100.47 }, faculty: "Eng", academic_year: "3",
  coins_balance: 700, role: "user", status: "active", is_student: true,
  owner_rating_scores: 4.5, owner_rating_count: 2, ban_reason: "x", wishlist: ["L1"],
};

(async () => {
  store = {}; writes = 0;
  await write("A", null, alice);
  const pub = store["public_profiles/A"];
  check("PUB-01 a new user gets a public profile", pub && pub.name === "Alice" && pub.profile_img_url === "p.jpg" && pub.bio === "hi", JSON.stringify(pub));
  check("PUB-02 it carries rating, count and student status",
    pub.owner_rating_scores === 4.5 && pub.owner_rating_count === 2 && pub.is_student === true && pub.updated_at === "TS", JSON.stringify(pub));
  const leaked = ["email", "tel", "fcm_token", "location", "faculty", "academic_year", "coins_balance", "role", "ban_reason", "wishlist"]
    .filter((k) => k in pub);
  check("PUB-03 none of the private fields are copied", leaked.length === 0, leaked.join(","));

  writes = 0;
  await write("A", alice, { ...alice, fcm_token: "new", location: { latitude: 7.02, longitude: 100.48 }, coins_balance: 500 });
  check("PUB-04 private-only changes (token, location, coins) write nothing", writes === 0, `writes=${writes}`);

  await write("A", alice, { ...alice, name: "Alice B", profile_img_url: "q.jpg" });
  check("PUB-05 a name or photo change is copied", store["public_profiles/A"].name === "Alice B" && store["public_profiles/A"].profile_img_url === "q.jpg", "");

  await write("A", alice, { ...alice, status: "banned", ban_reason: "spam" });
  check("PUB-06 a ban is not made public", store["public_profiles/A"].status === "active" && !("ban_reason" in store["public_profiles/A"]), JSON.stringify(store["public_profiles/A"]));

  await write("A", alice, { name: "ผู้ใช้ที่ลบบัญชีแล้ว", status: "deleted", owner_rating_scores: 4.5, owner_rating_count: 2 });
  const del = store["public_profiles/A"];
  check("PUB-07 an account-deletion tombstone shows as deleted, empty photo and bio",
    del.status === "deleted" && del.name === "ผู้ใช้ที่ลบบัญชีแล้ว" && del.profile_img_url === "" && del.bio === "", JSON.stringify(del));

  await write("A", alice, null);
  check("PUB-08 removing the user doc removes the public profile", !("public_profiles/A" in store), "");

  await write("B", null, { name: "Old", rating: 3 });
  check("PUB-09 old docs with only `rating` still get a rating", store["public_profiles/B"].owner_rating_scores === 3 && store["public_profiles/B"].is_student === false, JSON.stringify(store["public_profiles/B"]));

  console.log(fail ? fail + " FAILED" : "ALL PASSED");
  process.exit(fail ? 1 : 0);
})();
