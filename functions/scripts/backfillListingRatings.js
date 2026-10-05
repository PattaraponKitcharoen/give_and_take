// One-off: copy each owner's current rating (users.owner_rating_scores) onto
// their listings' owner_rating_scores. Listings posted before
// submitTradeReview started keeping that copy fresh are stuck at 0 ("New").
// Uses the Firebase CLI's login (project owner), so it bypasses security
// rules — run deliberately.
//
//   node functions/scripts/backfillListingRatings.js           # dry run: prints what would change
//   node functions/scripts/backfillListingRatings.js --apply   # writes
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
  const json = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(json));
  return json;
};
const val = (f) => (f ? Object.values(f)[0] : undefined);
const listAll = async (collection) => {
  const docs = [];
  let pageToken = "";
  do {
    const page = await api(`${BASE}/${collection}?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ""}`);
    docs.push(...(page.documents || []));
    pageToken = page.nextPageToken || "";
  } while (pageToken);
  return docs;
};

(async () => {
  const users = await listAll("users");
  const ratingOf = Object.fromEntries(users.map((u) => [u.name.split("/").pop(), Number(val(u.fields.owner_rating_scores) || 0)]));
  const listings = await listAll("listings");
  let changed = 0;
  for (const l of listings) {
    const id = l.name.split("/").pop();
    const owner = val(l.fields.owner_id);
    const want = ratingOf[owner] || 0;
    const have = Number(val(l.fields.owner_rating_scores) || 0);
    if (Math.abs(want - have) < 1e-9) continue;
    console.log(`${APPLY ? "write " : "would "} ${id} (${val(l.fields.title)}): ${have} -> ${want}`);
    if (APPLY) {
      await api(`${BASE}/listings/${id}?updateMask.fieldPaths=owner_rating_scores`,
        { method: "PATCH", body: JSON.stringify({ fields: { owner_rating_scores: { doubleValue: want } } }) });
    }
    changed++;
  }
  console.log(`${listings.length} listings, ${changed} ${APPLY ? "updated" : "to update (dry run — rerun with --apply)"}`);
})();
