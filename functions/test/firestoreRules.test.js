// Tests firestore.rules against the Firebase Rules test API (no emulator needed, no data touched).
// Run from the project root:  node functions/test/firestoreRules.test.js
// Needs a logged-in Firebase CLI (uses its access token).
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const PROJECT = "give-and-take-4d7d2";
const P = "/databases/(default)/documents";
const rulesPath = process.argv[2] || path.join(__dirname, "..", "..", "firestore.rules");
const source = fs.readFileSync(rulesPath, "utf8");

const A = "userA", B = "userB", C = "userC", ADMIN = "adminUser", X = "bannedUser";
const userDoc = (over = {}) => ({ name: "A", email: "a@x.com", role: "user", status: "active", coins_balance: 1000,
  owner_rating_scores: 0, owner_rating_count: 0, wishlist: [], is_email_verified: false, ...over });
const listing = (owner, over = {}) => ({ owner_id: owner, status: "active", title: "item", estimated_coins: 50, ...over });
const offer = (over = {}) => ({ sender_id: A, target_user_id: B, target_listing_id: "LB", offered_listing_id: "LA",
  coin_offset: 0, status: "pending", last_offer_by: A, members: [A, B], ...over });
const tx = (over = {}) => ({ members: [A, B], status: "in_progress", offer_id: "O1", escrow_coins: 0,
  verification_codes: { [A]: "111111", [B]: "222222" }, ...over });

// docs that rules may get(): users (for isAdmin) and listings (for offer create)
const world = {
  [`${P}/users/${A}`]: userDoc(), [`${P}/users/${B}`]: userDoc(), [`${P}/users/${C}`]: userDoc(),
  [`${P}/users/${ADMIN}`]: userDoc({ role: "admin" }),
  [`${P}/listings/LA`]: listing(A), [`${P}/listings/LB`]: listing(B), [`${P}/listings/LC`]: listing(C),
  [`${P}/listings/LB_busy`]: listing(B, { status: "in_progress" }),
  // X is permanently banned (no banned_until)
  [`${P}/users/${X}`]: userDoc({ status: "banned", ban_reason: "spam" }),
  [`${P}/listings/LX`]: listing(X),
  [`${P}/chat_rooms/RX`]: { members: [X, B] },
  [`${P}/chat_rooms/RA`]: { members: [A, B] },
};
const mocks = [
  ...Object.entries(world).map(([p, data]) => ({ function: "get", args: [{ exactValue: p }], result: { value: { data } } })),
  ...Object.keys(world).map((p) => ({ function: "exists", args: [{ exactValue: p }], result: { value: true } })),
  { function: "exists", args: [{ exactValue: `${P}/listings/NOPE` }], result: { value: false } },
];

const cases = [];
const add = (name, expectation, uid, method, docPath, before, after) => {
  const request = { auth: uid ? { uid } : null, path: P + docPath, method };
  if (after !== undefined) request.resource = { data: after };
  const tc = { expectation, request, functionMocks: mocks };
  if (before !== undefined) tc.resource = { data: before };
  cases.push({ name, tc });
};
const ALLOW = "ALLOW", DENY = "DENY";

// ---------------------------------------------------------------- users
const u = userDoc();
add("users: register with system defaults", ALLOW, A, "create", `/users/${A}`, undefined, userDoc({ coins_balance: 1000.0, is_student: false }));
add("users: register with extra coins (WAL-06)", DENY, A, "create", `/users/${A}`, undefined, userDoc({ coins_balance: 999999 }));
add("users: register as admin (ADM-13)", DENY, A, "create", `/users/${A}`, undefined, userDoc({ role: "admin" }));
add("users: register with fake rating", DENY, A, "create", `/users/${A}`, undefined, userDoc({ owner_rating_scores: 5, owner_rating_count: 99 }));
add("users: create someone else's doc", DENY, A, "create", `/users/${B}`, undefined, userDoc());
add("users: edit profile fields (app: updateUser)", ALLOW, A, "update", `/users/${A}`, u, { ...u, name: "New", bio: "hi", tel: "08", profile_img_url: "x", faculty: "Eng", academic_year: "3", is_student: true, updated_at: 1 });
add("users: toggle wishlist (app)", ALLOW, A, "update", `/users/${A}`, u, { ...u, wishlist: ["LB"] });
add("users: save fcm token / location (app)", ALLOW, A, "update", `/users/${A}`, u, { ...u, fcm_token: "tok", location: { district: "x" }, updated_at: 1 });
add("users: sync is_email_verified (app)", ALLOW, A, "update", `/users/${A}`, u, { ...u, is_email_verified: true });
add("users: set own coins (WAL-05)", DENY, A, "update", `/users/${A}`, u, { ...u, coins_balance: 999999 });
add("users: set own rating", DENY, A, "update", `/users/${A}`, u, { ...u, owner_rating_scores: 5, owner_rating_count: 50 });
add("users: unban self (ADM-09)", DENY, A, "update", `/users/${A}`, userDoc({ status: "banned" }), userDoc({ status: "active" }));
add("users: make self admin (ADM-13)", DENY, A, "update", `/users/${A}`, u, { ...u, role: "admin" });
add("users: give self the verified badge", DENY, A, "update", `/users/${A}`, u, { ...u, is_verified: true });
add("users: edit another user's doc", DENY, A, "update", `/users/${B}`, u, { ...u, name: "hacked" });
add("users: delete own doc (reset coins/ban)", DENY, A, "delete", `/users/${A}`, u);
add("users: admin bans a user (admin web)", ALLOW, ADMIN, "update", `/users/${A}`, u, { ...u, status: "banned", updated_at: 1 });
add("users: admin changes coins (ADM-12)", DENY, ADMIN, "update", `/users/${A}`, u, { ...u, coins_balance: 5 });
add("users: read while signed in", ALLOW, A, "get", `/users/${B}`, u);
add("users: read while signed out", DENY, null, "get", `/users/${B}`, u);

// ---------------------------------------------------------------- listings
const l = listing(A);
add("listings: create own active listing (app)", ALLOW, A, "create", "/listings/new", undefined, l);
add("listings: create for someone else (POST-16)", DENY, A, "create", "/listings/new", undefined, listing(B));
add("listings: create already 'completed'", DENY, A, "create", "/listings/new", undefined, listing(A, { status: "completed" }));
add("listings: edit own details (app)", ALLOW, A, "update", "/listings/LA", l, { ...l, title: "new", estimated_coins: 80, updated_at: 1 });
add("listings: owner flips in_progress back to active", DENY, A, "update", "/listings/LA", listing(A, { status: "in_progress" }), listing(A, { status: "active" }));
add("listings: owner un-bans own listing (ADM-09)", DENY, A, "update", "/listings/LA", listing(A, { status: "banned" }), listing(A, { status: "active" }));
add("listings: owner hands listing to someone else", DENY, A, "update", "/listings/LA", l, { ...l, owner_id: B });
add("listings: edit someone else's listing (POST-17)", DENY, A, "update", "/listings/LB", listing(B), { ...listing(B), title: "x" });
add("listings: delete own active listing (app)", ALLOW, A, "delete", "/listings/LA", l);
const loc = {"latitude": 7.01, "longitude": 100.47, "district": "หาดใหญ่", "province": "สงขลา", "display_name": "หาดใหญ่, สงขลา"};
add("listings: create with pickup location (app)", ALLOW, A, "create", "/listings/new", undefined, { ...l, location: loc });
add("listings: create with junk location", DENY, A, "create", "/listings/new", undefined, { ...l, location: { latitude: "here", longitude: 1 } });
add("listings: create with out-of-range location", DENY, A, "create", "/listings/new", undefined, { ...l, location: { ...loc, latitude: 120 } });
add("listings: create with extra fields in location", DENY, A, "create", "/listings/new", undefined, { ...l, location: { ...loc, exact_address: "room 304" } });
add("listings: owner moves pickup location (app)", ALLOW, A, "update", "/listings/LA", { ...l, location: loc }, { ...l, location: { ...loc, latitude: 7.02 } });
add("listings: delete listing that is mid-trade (POST-15)", DENY, A, "delete", "/listings/LA", listing(A, { status: "in_progress" }));
add("listings: delete someone else's listing", DENY, A, "delete", "/listings/LB", listing(B));
add("listings: admin bans a listing (admin web)", ALLOW, ADMIN, "update", "/listings/LA", l, { ...l, status: "banned" });
add("listings: admin edits title (ADM-12)", DENY, ADMIN, "update", "/listings/LA", l, { ...l, title: "x" });

// ---------------------------------------------------------------- offers
const o = offer();
add("offers: A makes an offer (app)", ALLOW, A, "create", "/offers/O1", undefined, offer({ coin_offset: 50 }));
add("offers: offer in someone else's name (OFFER-17)", DENY, C, "create", "/offers/O1", undefined, o);
add("offers: offer on own listing (OFFER-16)", DENY, A, "create", "/offers/O1", undefined, offer({ target_user_id: A, target_listing_id: "LA" }));
add("offers: offering someone else's item (OFFER-16)", DENY, A, "create", "/offers/O1", undefined, offer({ offered_listing_id: "LC" }));
add("offers: target listing not active (OFFER-16)", DENY, A, "create", "/offers/O1", undefined, offer({ target_listing_id: "LB_busy" }));
add("offers: created already 'accepted'", DENY, A, "create", "/offers/O1", undefined, offer({ status: "accepted" }));
add("offers: created with the other side as last_offer_by", DENY, A, "create", "/offers/O1", undefined, offer({ last_offer_by: B }));
add("offers: B counters on B's turn (app)", ALLOW, B, "update", "/offers/O1", o, { ...o, coin_offset: -20, last_offer_by: B, updated_at: 1 });
add("offers: A counters back on A's turn (app)", ALLOW, A, "update", "/offers/O1", offer({ last_offer_by: B }), offer({ last_offer_by: A, coin_offset: 10, updated_at: 1 }));
add("offers: B rejects on B's turn (app)", ALLOW, B, "update", "/offers/O1", o, { ...o, status: "rejected", updated_at: 1 });
add("offers: A withdraws own pending offer (app: cancelOffer)", ALLOW, A, "delete", "/offers/O1", o);
add("offers: A changes terms out of turn (NEGO-10)", DENY, A, "update", "/offers/O1", o, { ...o, coin_offset: -500, updated_at: 1 });
add("offers: B counters but signs it as A (ACC-12 bypass)", DENY, B, "update", "/offers/O1", o, { ...o, coin_offset: 900, last_offer_by: A, updated_at: 1 });
add("offers: B sets status accepted directly (NEGO-10)", DENY, B, "update", "/offers/O1", o, { ...o, status: "accepted" });
add("offers: B sets status completed directly", DENY, B, "update", "/offers/O1", o, { ...o, status: "completed" });
add("offers: B swaps the listing in the offer", DENY, B, "update", "/offers/O1", o, { ...o, offered_listing_id: "LC", last_offer_by: B });
add("offers: change an accepted offer", DENY, B, "update", "/offers/O1", offer({ status: "accepted" }), offer({ status: "accepted", coin_offset: 5, last_offer_by: B }));
add("offers: delete an accepted offer", DENY, A, "delete", "/offers/O1", offer({ status: "accepted" }));
add("offers: outsider reads an offer", DENY, C, "get", "/offers/O1", o);
add("offers: outsider rejects an offer", DENY, C, "update", "/offers/O1", o, { ...o, status: "rejected" });
add("offers: party reads own offer (app)", ALLOW, B, "get", "/offers/O1", o);

// ---------------------------------------------------------------- transactions
const t = tx();
add("transactions: member reads own deal (app)", ALLOW, A, "get", "/transactions/T1", t);
add("transactions: outsider reads a deal", DENY, C, "get", "/transactions/T1", t);
add("transactions: admin reads a deal (dashboard)", ALLOW, ADMIN, "get", "/transactions/T1", t);
add("transactions: member marks deal completed (OTP-16)", DENY, A, "update", "/transactions/T1", t, { ...t, status: "completed" });
add("transactions: member creates fake completed deal (REV-09)", DENY, A, "create", "/transactions/T2", undefined, tx({ status: "completed" }));
add("transactions: member deletes a deal holding coins", DENY, A, "delete", "/transactions/T1", t);

// ---------------------------------------------------------------- reviews / wallet
const r = { reviewer_id: A, reviewee_id: B, transaction_id: "T1", rating: 5, comment: "" };
add("reviews: anyone signed in reads reviews (app)", ALLOW, C, "get", "/reviews/R1", r);
add("reviews: write a review directly (REV-09)", DENY, A, "create", "/reviews/R1", undefined, r);
add("reviews: edit a review", DENY, A, "update", "/reviews/R1", r, { ...r, rating: 1 });
const w = { user_id: A, amount: -50, type: "escrow_lock" };
add("wallet: owner reads own history (app)", ALLOW, A, "get", "/wallet_transactions/W1", w);
add("wallet: read someone else's history (WAL-08)", DENY, B, "get", "/wallet_transactions/W1", w);
add("wallet: write a history entry (WAL-07)", DENY, A, "create", "/wallet_transactions/W2", undefined, { ...w, amount: 9999 });

// ---------------------------------------------------------------- matching
const want = { owner_id: A, text: "หูฟังบลูทูธ", status: "active", created_at: 1, updated_at: 1 };
add("wants: add own want (app)", ALLOW, A, "create", "/wants/W1", undefined, want);
add("wants: add want for someone else", DENY, A, "create", "/wants/W1", undefined, { ...want, owner_id: B });
add("wants: add want with a forged embedding", DENY, A, "create", "/wants/W1", undefined, { ...want, embedding: [1, 2], embedding_hash: "x" });
add("wants: add empty want", DENY, A, "create", "/wants/W1", undefined, { ...want, text: "" });
add("wants: add over-long want", DENY, A, "create", "/wants/W1", undefined, { ...want, text: "x".repeat(121) });
add("wants: owner reads own want", ALLOW, A, "get", "/wants/W1", want);
add("wants: read someone else's want", DENY, B, "get", "/wants/W1", want);
add("wants: owner edits text (app)", ALLOW, A, "update", "/wants/W1", want, { ...want, text: "เสื่อโยคะ", updated_at: 2 });
add("wants: owner overwrites embedding", DENY, A, "update", "/wants/W1", want, { ...want, embedding: [1, 2] });
add("wants: owner deletes own want (app)", ALLOW, A, "delete", "/wants/W1", want);
add("wants: delete someone else's want", DENY, B, "delete", "/wants/W1", want);
add("users: turn matching off (app)", ALLOW, A, "update", `/users/${A}`, u, { ...u, match_enabled: false });
add("users: reset own rescan cooldown", DENY, A, "update", `/users/${A}`, { ...u, last_rescan_at: 5 }, { ...u, last_rescan_at: 0 });
const m = { members: [A, B], listing_ids: ["LA", "LB"], want_ids: ["W1", "W2"], score: 0.8, seen_by: [] };
add("matches: member reads match (app)", ALLOW, A, "get", "/matches/M1", m);
add("matches: outsider reads match", DENY, C, "get", "/matches/M1", m);
add("matches: member marks it seen (app)", ALLOW, A, "update", "/matches/M1", m, { ...m, seen_by: [A] });
add("matches: member marks it seen for the other side", DENY, A, "update", "/matches/M1", m, { ...m, seen_by: [B] });
add("matches: member unmarks the other side's seen", DENY, A, "update", "/matches/M1", { ...m, seen_by: [B] }, { ...m, seen_by: [A] });
add("matches: member changes the score", DENY, A, "update", "/matches/M1", m, { ...m, score: 1 });
add("matches: create a match directly", DENY, A, "create", "/matches/M2", undefined, m);
add("matches: delete a match", DENY, A, "delete", "/matches/M1", m);
add("listing_vectors: read a vector", DENY, A, "get", "/listing_vectors/LA", { owner_id: A, status: "active" });
add("listing_vectors: write a vector", DENY, A, "create", "/listing_vectors/LA", undefined, { owner_id: A, status: "active" });

// ---------------------------------------------------------------- bans
const xb = userDoc({ status: "banned", ban_reason: "spam" });
add("ban: banned user posts a listing", DENY, X, "create", "/listings/new", undefined, listing(X));
add("ban: banned user edits own listing", DENY, X, "update", "/listings/LX", listing(X), { ...listing(X), title: "x" });
add("ban: banned user deletes own listing", DENY, X, "delete", "/listings/LX", listing(X));
add("ban: banned user makes an offer", DENY, X, "create", "/offers/OX", undefined,
  offer({ sender_id: X, last_offer_by: X, offered_listing_id: "LX", members: [X, B] }));
add("ban: banned user sends a chat message", DENY, X, "create", "/chat_rooms/RX/messages/M1", undefined, { sender_id: X, text: "hi" });
add("ban: banned user still reads their chat", ALLOW, X, "get", "/chat_rooms/RX/messages/M1", { sender_id: B, text: "hi" });
add("ban: active user sends a chat message (app)", ALLOW, A, "create", "/chat_rooms/RA/messages/M1", undefined, { sender_id: A, text: "hi" });
add("ban: banned user opens a chat room", DENY, X, "create", "/chat_rooms/RN", undefined, { members: [X, C] });
add("ban: banned user adds a want", DENY, X, "create", "/wants/WX", undefined, { owner_id: X, text: "x", status: "active", created_at: 1, updated_at: 1 });
add("ban: banned user edits own profile", DENY, X, "update", `/users/${X}`, xb, { ...xb, name: "New name" });
add("ban: banned user's app saves push token (app)", ALLOW, X, "update", `/users/${X}`, xb, { ...xb, fcm_token: "t", updated_at: 2 });
add("ban: banned user lifts own ban", DENY, X, "update", `/users/${X}`, xb, { ...xb, status: "active" });
add("ban: banned user clears ban reason", DENY, X, "update", `/users/${X}`, xb, { ...u, status: "banned" });
add("ban: register with ban fields pre-set", DENY, A, "create", `/users/${A}`, undefined, userDoc({ ban_reason: "x" }));
add("ban: admin bans a user with reason (admin web)", ALLOW, ADMIN, "update", `/users/${A}`, u, { ...u, status: "banned", ban_reason: "โกง", banned_at: 1, updated_at: 1 });
add("ban: admin sets a ban reason on a listing (admin web)", ALLOW, ADMIN, "update", "/listings/LA", l, { ...l, status: "banned", ban_reason: "ของผิดกฎหมาย" });
add("ban: owner marks own listing hidden_by_user_ban", DENY, A, "update", "/listings/LA", { ...l, status: "banned" }, { ...l, status: "banned", hidden_by_user_ban: true });
add("ban: owner clears ban reason on own listing", DENY, A, "update", "/listings/LA", { ...l, status: "banned", ban_reason: "x" }, { ...l, status: "banned" });

// ---------------------------------------------------------------- reports
const rep = (over = {}) => ({ reporter_id: A, target_type: "listing", target_id: "LB", reason: "ของปลอม", detail: "", status: "open", created_at: 1, ...over });
add("reports: report someone's listing (app)", ALLOW, A, "create", `/reports/${A}_listing_LB`, undefined, rep());
add("reports: report own listing", DENY, A, "create", `/reports/${A}_listing_LA`, undefined, rep({ target_id: "LA" }));
add("reports: report a listing that doesn't exist", DENY, A, "create", `/reports/${A}_listing_NOPE`, undefined, rep({ target_id: "NOPE" }));
add("reports: report a user (app)", ALLOW, A, "create", `/reports/${A}_user_${B}`, undefined, rep({ target_type: "user", target_id: B }));
add("reports: report yourself", DENY, A, "create", `/reports/${A}_user_${A}`, undefined, rep({ target_type: "user", target_id: A }));
add("reports: report own chat (app)", ALLOW, A, "create", `/reports/${A}_chat_RA`, undefined, rep({ target_type: "chat", target_id: "RA" }));
add("reports: report a chat you're not in", DENY, C, "create", `/reports/${C}_chat_RA`, undefined, rep({ reporter_id: C, target_type: "chat", target_id: "RA" }));
add("reports: report in someone else's name", DENY, A, "create", `/reports/${B}_listing_LA`, undefined, rep({ reporter_id: B, target_id: "LA" }));
add("reports: doc id not matching target (dodge one-per-target)", DENY, A, "create", `/reports/${A}_listing_LB_2`, undefined, rep());
add("reports: forge evidence", DENY, A, "create", `/reports/${A}_listing_LB`, undefined, { ...rep(), snapshot: { title: "fake" } });
add("reports: create already resolved", DENY, A, "create", `/reports/${A}_listing_LB`, undefined, rep({ status: "resolved" }));
add("reports: overlong detail", DENY, A, "create", `/reports/${A}_listing_LB`, undefined, rep({ detail: "x".repeat(501) }));
add("reports: banned user reports", DENY, X, "create", `/reports/${X}_listing_LB`, undefined, rep({ reporter_id: X }));
add("reports: reporter checks own report (app)", ALLOW, A, "get", `/reports/${A}_listing_LB`, rep());
add("reports: read someone else's report", DENY, B, "get", `/reports/${A}_listing_LB`, rep());
add("reports: reporter edits report", DENY, A, "update", `/reports/${A}_listing_LB`, rep(), rep({ reason: "x" }));
add("reports: admin reads reports (admin web)", ALLOW, ADMIN, "get", `/reports/${A}_listing_LB`, rep());
add("reports: admin edits report directly", DENY, ADMIN, "update", `/reports/${A}_listing_LB`, rep(), rep({ status: "resolved" }));
add("admin_actions: admin reads log (admin web)", ALLOW, ADMIN, "get", "/admin_actions/a1", { admin_id: ADMIN });
add("admin_actions: user reads log", DENY, A, "get", "/admin_actions/a1", { admin_id: ADMIN });
add("admin_actions: admin writes log directly", DENY, ADMIN, "create", "/admin_actions/a2", undefined, { admin_id: ADMIN });

// ---------------------------------------------------------------- run
const token = () => {
  execSync("firebase projects:list", { stdio: "ignore" });   // refreshes the CLI token
  return JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config/configstore/firebase-tools.json"), "utf8")).tokens.access_token;
};
(async () => {
  const res = await fetch(`https://firebaserules.googleapis.com/v1/projects/${PROJECT}:test`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ source: { files: [{ name: "firestore.rules", content: source }] }, testSuite: { testCases: cases.map((c) => c.tc) } }),
  });
  const json = await res.json();
  if (!json.testResults) { console.log(JSON.stringify(json).slice(0, 1500)); process.exit(2); }
  let failed = 0;
  json.testResults.forEach((result, i) => {
    const ok = result.state === "SUCCESS";
    if (!ok) failed++;
    const detail = ok ? "" : "   <-- expected " + cases[i].tc.expectation + (result.debugMessages ? " | " + result.debugMessages.join(" ") : "");
    console.log((ok ? "PASS  " : "FAIL  ") + cases[i].tc.expectation.padEnd(5) + " " + cases[i].name + detail);
  });
  console.log(failed ? `${failed} of ${cases.length} FAILED` : `ALL ${cases.length} PASSED`);
  process.exit(failed ? 1 : 0);
})();
