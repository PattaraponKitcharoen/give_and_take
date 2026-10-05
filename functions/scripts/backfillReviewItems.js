// One-off: add reviewer_item / reviewee_item to reviews written before
// submitTradeReview started storing them. Uses the Firebase CLI's login
// (project owner), so it bypasses security rules — run deliberately.
//
//   node functions/scripts/backfillReviewItems.js           # dry run: prints what would change
//   node functions/scripts/backfillReviewItems.js --apply   # writes
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const BASE = "https://firestore.googleapis.com/v1/projects/give-and-take-4d7d2/databases/(default)/documents";
const APPLY = process.argv.includes("--apply");

execSync("firebase projects:list", { stdio: "ignore" }); // refresh CLI token
const token = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config/configstore/firebase-tools.json"), "utf8")).tokens.access_token;
const api = async (url, opts = {}) => {
  const res = await fetch(url, { ...opts, headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } });
  if (res.status === 404) return null;
  const json = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(json));
  return json;
};
const val = (f) => (f ? Object.values(f)[0] : undefined);
// Same shape as listingSnapshot() in functions/index.js.
const snapshot = (doc) => ({
  mapValue: { fields: {
    listing_id: { stringValue: doc.name.split("/").pop() },
    owner_id: { stringValue: val(doc.fields.owner_id) || "" },
    title: { stringValue: val(doc.fields.title) || "" },
    thumbnail_url: { stringValue: val(doc.fields.thumbnail_url) || "" },
    estimated_coins: { integerValue: String(Number(val(doc.fields.estimated_coins) || 0)) },
  } },
});

(async () => {
  const reviews = (await api(`${BASE}/reviews?pageSize=300`)).documents || [];
  let changed = 0;
  for (const r of reviews) {
    const id = r.name.split("/").pop();
    const f = r.fields;
    if (f.reviewee_item || f.reviewer_item) { console.log(`skip   ${id} (already has items)`); continue; }
    const tx = await api(`${BASE}/transactions/${val(f.transaction_id)}`);
    if (!tx) { console.log(`skip   ${id} (transaction missing)`); continue; }
    const ids = (tx.fields.listings && tx.fields.listings.arrayValue.values || []).map(val);
    const docs = (await Promise.all(ids.map((l) => api(`${BASE}/listings/${l}`)))).filter(Boolean);
    const of = (uid) => docs.find((d) => val(d.fields.owner_id) === uid);
    const reviewer = of(val(f.reviewer_id)), reviewee = of(val(f.reviewee_id));
    const fields = {
      reviewer_item: reviewer ? snapshot(reviewer) : { nullValue: null },
      reviewee_item: reviewee ? snapshot(reviewee) : { nullValue: null },
    };
    console.log(`${APPLY ? "write " : "would "} ${id}: reviewer_item=${reviewer ? val(reviewer.fields.title) : "null"}  reviewee_item=${reviewee ? val(reviewee.fields.title) : "null"}`);
    if (APPLY) {
      await api(`${BASE}/reviews/${id}?updateMask.fieldPaths=reviewer_item&updateMask.fieldPaths=reviewee_item`,
        { method: "PATCH", body: JSON.stringify({ fields }) });
    }
    changed++;
  }
  console.log(`${reviews.length} reviews, ${changed} ${APPLY ? "updated" : "to update (dry run — rerun with --apply)"}`);
})();
