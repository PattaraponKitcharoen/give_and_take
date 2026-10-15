// One-off, for distance sorting:
//  1. Rounds every users.location to the ~1 km grid (0.01°). User docs are
//     readable by any signed-in user, so exact positions must not stay there.
//  2. Gives listings without a pickup point (posted before it existed) their
//     owner's rounded location. Owners with no saved location are skipped;
//     those listings sort last until the owner edits them.
// Uses the Firebase CLI's login (project owner), so it bypasses security
// rules — run deliberately.
//
//   node functions/scripts/backfillLocations.js           # dry run: prints what would change
//   node functions/scripts/backfillLocations.js --apply   # writes
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
// Same rounding as PlaceLocation.coarse in the app.
const snap = (v) => Number((Math.round(v / 0.01) * 0.01).toFixed(2));

/** Firestore map value for a coarse location, or null if unusable. */
function coarse(locField) {
  const m = locField && locField.mapValue && locField.mapValue.fields;
  if (!m) return null;
  const lat = Number(val(m.latitude));
  const lng = Number(val(m.longitude));
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  const district = val(m.district) || "";
  const province = val(m.province) || "";
  const display = [district, province].filter(Boolean).join(", ");
  return {
    lat: snap(lat), lng: snap(lng), exact: lat !== snap(lat) || lng !== snap(lng),
    value: { mapValue: { fields: {
      latitude: { doubleValue: snap(lat) },
      longitude: { doubleValue: snap(lng) },
      district: { stringValue: district },
      province: { stringValue: province },
      display_name: { stringValue: display },
    } } },
  };
}
const patch = (doc, field, value) => api(`${BASE}/${doc}?updateMask.fieldPaths=${field}`,
  { method: "PATCH", body: JSON.stringify({ fields: { [field]: value } }) });

(async () => {
  const users = await listAll("users");
  const locOf = {};
  let roundedUsers = 0;
  for (const u of users) {
    const id = u.name.split("/").pop();
    const c = coarse(u.fields.location);
    if (!c) continue;
    locOf[id] = c;
    if (!c.exact) continue;
    console.log(`${APPLY ? "write " : "would "} users/${id}: round location to ${c.lat}, ${c.lng}`);
    if (APPLY) await patch(`users/${id}`, "location", c.value);
    roundedUsers++;
  }

  const listings = await listAll("listings");
  let filled = 0, noOwnerLocation = 0;
  for (const l of listings) {
    const id = l.name.split("/").pop();
    if (l.fields.location) continue;
    const c = locOf[val(l.fields.owner_id)];
    if (!c) { noOwnerLocation++; continue; }
    console.log(`${APPLY ? "write " : "would "} listings/${id} (${val(l.fields.title)}): location ${c.lat}, ${c.lng}`);
    if (APPLY) await patch(`listings/${id}`, "location", c.value);
    filled++;
  }
  console.log(`${roundedUsers} user locations ${APPLY ? "rounded" : "to round"}, ` +
    `${filled} listings ${APPLY ? "filled" : "to fill"}, ${noOwnerLocation} skipped (owner has no saved location)` +
    (APPLY ? "" : " — dry run, rerun with --apply"));
})();
