// One-off: embed listings posted before matching existed, so they can be
// matched. Writes match_meta/backfill = {status: "requested"}; the
// onBackfillRequested Cloud Function does the work (it holds the Gemini key)
// and writes the result back to the same doc, which this script waits for.
// Uses the Firebase CLI's login (project owner), so it bypasses security
// rules — run deliberately.
//
//   node functions/scripts/backfillListingVectors.js
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const DOC = "https://firestore.googleapis.com/v1/projects/give-and-take-4d7d2/databases/(default)/documents/match_meta/backfill";

execSync("firebase projects:list", { stdio: "ignore" }); // refresh CLI token
const token = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config/configstore/firebase-tools.json"), "utf8")).tokens.access_token;
const api = async (url, opts = {}) => {
  const res = await fetch(url, { ...opts, headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } });
  const json = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(json));
  return json;
};
const val = (f) => (f ? Object.values(f)[0] : undefined);

(async () => {
  await api(DOC, {
    method: "PATCH",
    body: JSON.stringify({ fields: { status: { stringValue: "requested" }, requested_at: { timestampValue: new Date().toISOString() } } }),
  });
  console.log("requested — waiting for the Cloud Function…");
  for (let i = 0; i < 120; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const doc = await api(DOC);
    const status = val(doc.fields.status);
    if (status === "done") {
      console.log(`done: embedded ${val(doc.fields.embedded)}, failed ${val(doc.fields.failed)}`);
      return;
    }
    process.stdout.write(`  ${status}\n`);
  }
  console.log("still not done after 10 minutes — check: firebase functions:log --only onBackfillRequested");
})();
