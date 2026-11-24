// One-off: creates public_profiles/{uid} for users that existed before the
// onUserWrittenSyncPublic trigger (which keeps them in step from then on).
// Run it after deploying the functions and BEFORE deploying the rules that
// make users/{uid} private, so other people's names and photos never go
// missing in the app.
// Uses the Firebase CLI's login (project owner), so it bypasses security
// rules — run deliberately.
//
//   node functions/scripts/backfillPublicProfiles.js           # dry run
//   node functions/scripts/backfillPublicProfiles.js --apply   # writes
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");
const { publicFields } = require("../publicProfile")._internal;

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
// REST value -> plain JS, for the scalar fields publicFields reads.
const plain = (v) => {
  if (!v) return undefined;
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  return undefined;
};
const rest = (v) =>
  typeof v === "boolean" ? { booleanValue: v } :
  typeof v === "number" ? (Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v }) :
  { stringValue: String(v) };

(async () => {
  const users = await listAll("users");
  let n = 0;
  for (const doc of users) {
    const uid = doc.name.split("/").pop();
    const u = {};
    for (const [k, v] of Object.entries(doc.fields || {})) u[k] = plain(v);
    const pub = publicFields(u);
    const fields = Object.fromEntries(Object.entries(pub).map(([k, v]) => [k, rest(v)]));
    fields.updated_at = { timestampValue: new Date().toISOString() };
    n++;
    if (APPLY) {
      await api(`${BASE}/public_profiles/${uid}`, { method: "PATCH", body: JSON.stringify({ fields }) });
    }
    console.log(`${APPLY ? "wrote" : "would write"} public_profiles/${uid}: ${pub.name || "(no name)"}${pub.status === "deleted" ? " [deleted]" : ""}`);
  }
  console.log(`${n} users${APPLY ? "" : " (dry run; add --apply to write)"}`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
