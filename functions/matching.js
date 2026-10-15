// Want-based matching ("แลกตามความต้องการ").
//
// Users type what they want (wants/{id}). Every want and every active
// listing gets a Gemini text embedding, and a two-way match is recorded in
// matches/{id} when A's listing fits one of B's wants AND one of B's
// listings fits one of A's wants. Both users get a push for a new match.
//
// Listing vectors live in their own server-only collection
// (listing_vectors/{listingId}) instead of on the listing itself: the Home
// feed streams every listing, and a 768-number vector on each one would
// make that stream several times heavier for nothing.
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { GoogleGenAI } = require("@google/genai");
const { assertNotBanned } = require("./moderation");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const EMBED_MODEL = "gemini-embedding-001";
const DIMENSIONS = 768; // must match firestore.indexes.json
// Cosine similarity a want and a listing need to count as "the same thing".
// A first guess for gemini-embedding-001 on short Thai text; tune it once
// there is real data (higher = fewer, stricter matches).
const MIN_SIMILARITY = 0.72;
const SEARCH_LIMIT = 20; // nearest neighbours fetched per vector search
const MAX_WANTS = 10; // per user; the app enforces the same limit
const RESCAN_COOLDOWN_MS = 60 * 60 * 1000; // manual rescan: once an hour per user

const db = () => admin.firestore();

/** What gets embedded for a listing. Changing it re-embeds every listing. */
function listingText(d) {
  return [
    d.title || "",
    d.category ? `หมวด: ${d.category}` : "",
    d.condition ? `สภาพ: ${d.condition}` : "",
    (d.description || "").slice(0, 500),
  ].filter(Boolean).join("\n");
}

const hashOf = (text) =>
  crypto.createHash("sha1").update(`${EMBED_MODEL}|${DIMENSIONS}|${text}`).digest("hex");

/** One embedding, unit-length so dot product == cosine similarity. */
async function embed(text, taskType) {
  const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
  const res = await ai.models.embedContent({
    model: EMBED_MODEL,
    contents: text,
    config: { taskType, outputDimensionality: DIMENSIONS },
  });
  const values = res.embeddings && res.embeddings[0] && res.embeddings[0].values;
  if (!values || values.length !== DIMENSIONS) {
    throw new Error(`embedding came back with ${values ? values.length : 0} values`);
  }
  const norm = Math.sqrt(values.reduce((s, v) => s + v * v, 0)) || 1;
  return values.map((v) => v / norm);
}

const toArray = (v) => (Array.isArray(v) ? v : v && typeof v.toArray === "function" ? v.toArray() : null);

function cosine(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na && nb ? dot / Math.sqrt(na * nb) : 0;
}

async function matchEnabled(uid) {
  const snap = await db().collection("users").doc(uid).get();
  return snap.exists && snap.data().match_enabled !== false;
}

/** A user's active wants that already have an embedding. */
async function activeWants(uid) {
  const snap = await db().collection("wants")
    .where("owner_id", "==", uid).where("status", "==", "active").get();
  return snap.docs
    .map((d) => ({ id: d.id, text: d.data().text || "", vec: toArray(d.data().embedding) }))
    .filter((w) => w.vec)
    .slice(0, MAX_WANTS);
}

/** A user's active listings that already have a vector. */
async function activeListingVectors(uid) {
  const snap = await db().collection("listing_vectors")
    .where("owner_id", "==", uid).where("status", "==", "active").get();
  return snap.docs
    .map((d) => ({ id: d.id, coins: d.data().estimated_coins || 0, vec: toArray(d.data().embedding) }))
    .filter((l) => l.vec);
}

/** Best (want, listing) pair across two lists, or null under the bar. */
function bestPair(wants, listings) {
  let best = null;
  for (const w of wants) {
    for (const l of listings) {
      const sim = cosine(w.vec, l.vec);
      if (sim >= MIN_SIMILARITY && (!best || sim > best.sim)) best = { want: w, listing: l, sim };
    }
  }
  return best;
}

async function nearest(collection, vec, ownerToSkip) {
  const snap = await db().collection(collection)
    .where("status", "==", "active")
    .findNearest({
      vectorField: "embedding",
      queryVector: vec,
      limit: SEARCH_LIMIT,
      distanceMeasure: "COSINE",
      distanceResultField: "vector_distance",
    })
    .get();
  return snap.docs
    .map((d) => ({ id: d.id, data: d.data(), sim: 1 - (d.get("vector_distance") || 0) }))
    .filter((r) => r.data.owner_id && r.data.owner_id !== ownerToSkip && r.sim >= MIN_SIMILARITY);
}

/** Keeps only the best hit per owner. */
function bestPerOwner(hits) {
  const byOwner = new Map();
  for (const h of hits) {
    const cur = byOwner.get(h.data.owner_id);
    if (!cur || h.sim > cur.sim) byOwner.set(h.data.owner_id, h);
  }
  return byOwner;
}

/**
 * Records a two-way match. `a` and `b` are each one side:
 *   { uid, give: {id, coins}, want: {id, text}, sim }
 * where a.want is satisfied by b.give and vice versa.
 */
async function saveMatch(a, b) {
  const id = [a.give.id, b.give.id].sort().join("__");
  const coinGap = Math.abs(a.give.coins - b.give.coins) / Math.max(a.give.coins, b.give.coins, 1);
  const score = (a.sim + b.sim) / 2 - 0.1 * Math.min(1, coinGap);
  const side = (me, other) => ({
    give_listing_id: me.give.id,
    get_listing_id: other.give.id,
    want_id: me.want.id,
    want_text: me.want.text,
  });
  const data = {
    members: [a.uid, b.uid],
    listing_ids: [a.give.id, b.give.id],
    want_ids: [a.want.id, b.want.id],
    sides: { [a.uid]: side(a, b), [b.uid]: side(b, a) },
    score: Math.round(score * 1000) / 1000,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  const ref = db().collection("matches").doc(id);
  try {
    await ref.create({ ...data, seen_by: [], created_at: admin.firestore.FieldValue.serverTimestamp() });
  } catch (e) {
    if (e.code !== 6 && e.code !== "already-exists") throw e;
    await ref.update(data); // already known: refresh, keep who has seen it
    return false;
  }
  await Promise.all([notify(a.uid, a.want.text, id), notify(b.uid, b.want.text, id)]);
  logger.info(`matching: new match ${id} between ${a.uid} and ${b.uid}`);
  return true;
}

async function notify(uid, myWant, matchId) {
  const ref = db().collection("users").doc(uid);
  const snap = await ref.get();
  const token = snap.exists && snap.data().fcm_token;
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: {
        title: "เจอคู่แลกแล้ว!",
        body: `มีคนมี "${myWant}" ที่คุณอยากได้ และเขาก็อยากได้ของของคุณ`,
      },
      data: { type: "new_match", match_id: matchId },
      android: { notification: { channelId: "give_and_take_channel" } },
    });
  } catch (error) {
    logger.error(`matching: push to ${uid} failed: ${error.message}`);
    if (error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token") {
      await ref.update({ fcm_token: admin.firestore.FieldValue.delete() });
    }
  }
}

/** A want of `uid` found nothing new before; look for owners who have it. */
async function matchForWant(uid, want) {
  if (!(await matchEnabled(uid))) return 0;
  const myListings = await activeListingVectors(uid);
  if (myListings.length === 0) return 0;
  let created = 0;
  for (const [owner, hit] of bestPerOwner(await nearest("listing_vectors", want.vec, uid))) {
    if (!(await matchEnabled(owner))) continue;
    // Do they want anything I have?
    const pair = bestPair(await activeWants(owner), myListings);
    if (!pair) continue;
    if (await saveMatch(
      { uid, give: pair.listing, want, sim: hit.sim },
      { uid: owner, give: { id: hit.id, coins: hit.data.estimated_coins || 0 }, want: pair.want, sim: pair.sim },
    )) created++;
  }
  return created;
}

/** A listing of `uid` became matchable; look for people who want it. */
async function matchForListing(uid, listing) {
  if (!(await matchEnabled(uid))) return 0;
  const myWants = await activeWants(uid);
  if (myWants.length === 0) return 0;
  let created = 0;
  for (const [owner, hit] of bestPerOwner(await nearest("wants", listing.vec, uid))) {
    if (!(await matchEnabled(owner))) continue;
    // Do they have anything I want?
    const pair = bestPair(myWants, await activeListingVectors(owner));
    if (!pair) continue;
    if (await saveMatch(
      { uid, give: listing, want: pair.want, sim: pair.sim },
      { uid: owner, give: pair.listing, want: { id: hit.id, text: hit.data.text || "" }, sim: hit.sim },
    )) created++;
  }
  return created;
}

async function deleteMatchesWhere(field, value) {
  const snap = await db().collection("matches").where(field, "array-contains", value).get();
  if (snap.empty) return;
  const batch = db().batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

/** Embeds a listing if its text changed; returns {vec, changed} or null. */
async function syncListingVector(listingId, d) {
  const ref = db().collection("listing_vectors").doc(listingId);
  const text = listingText(d);
  const hash = hashOf(text);
  const cur = await ref.get();
  const status = d.status || "";
  const coins = d.estimated_coins || 0;
  if (cur.exists && cur.data().hash === hash) {
    const was = cur.data();
    if (was.status !== status || was.estimated_coins !== coins) {
      await ref.update({ status, estimated_coins: coins, updated_at: admin.firestore.FieldValue.serverTimestamp() });
    }
    return { vec: toArray(was.embedding), changed: was.status !== "active" && status === "active" };
  }
  const vec = await embed(text, "RETRIEVAL_DOCUMENT");
  await ref.set({
    owner_id: d.owner_id || "",
    status,
    estimated_coins: coins,
    embedding: admin.firestore.FieldValue.vector(vec),
    hash,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { vec, changed: true };
}

exports.onListingWrittenForMatching = onDocumentWritten(
  { document: "listings/{listingId}", secrets: [geminiApiKey] },
  async (event) => {
    const listingId = event.params.listingId;
    const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
    if (!after) {
      await db().collection("listing_vectors").doc(listingId).delete();
      await deleteMatchesWhere("listing_ids", listingId);
      return;
    }
    if (after.status !== "active") {
      // Traded, in a deal, or banned: no longer on offer.
      await deleteMatchesWhere("listing_ids", listingId);
    }
    const synced = await syncListingVector(listingId, after);
    if (after.status === "active" && synced.changed && after.owner_id) {
      await matchForListing(after.owner_id, {
        id: listingId, coins: after.estimated_coins || 0, vec: synced.vec,
      });
    }
  }
);

exports.onWantWrittenForMatching = onDocumentWritten(
  { document: "wants/{wantId}", secrets: [geminiApiKey] },
  async (event) => {
    const wantId = event.params.wantId;
    const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
    if (!after || after.status !== "active") {
      await deleteMatchesWhere("want_ids", wantId);
      return;
    }
    const text = (after.text || "").trim();
    const hash = hashOf(text);
    // Our own embedding write below re-fires this trigger; stop there.
    if (!text || after.embedding_hash === hash) return;

    const count = await db().collection("wants")
      .where("owner_id", "==", after.owner_id).where("status", "==", "active").get();
    if (count.size > MAX_WANTS) {
      logger.warn(`matching: ${after.owner_id} has more than ${MAX_WANTS} wants, skipping ${wantId}`);
      return;
    }

    const vec = await embed(text, "RETRIEVAL_QUERY");
    await event.data.after.ref.update({
      embedding: admin.firestore.FieldValue.vector(vec),
      embedding_hash: hash,
    });
    // The text changed, so matches found for the old text no longer hold.
    await deleteMatchesWhere("want_ids", wantId);
    await matchForWant(after.owner_id, { id: wantId, text, vec });
  }
);

/**
 * One-off: embeds every active listing that has no vector yet (listings
 * posted before matching existed, or whose embedding failed). Started by
 * writing match_meta/backfill with status "requested" — see
 * functions/scripts/backfillListingVectors.js — and records the result on
 * the same doc, so it never runs as part of a user's request.
 */
exports.onBackfillRequested = onDocumentWritten(
  { document: "match_meta/backfill", secrets: [geminiApiKey], timeoutSeconds: 540 },
  async (event) => {
    const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
    // Our own status updates below re-fire this trigger; only act on a request.
    if (!after || after.status !== "requested") return;
    const ref = event.data.after.ref;
    await ref.update({ status: "running", started_at: admin.firestore.FieldValue.serverTimestamp() });

    const [listings, vectors] = await Promise.all([
      db().collection("listings").where("status", "==", "active").get(),
      db().collection("listing_vectors").get(),
    ]);
    const have = new Set(vectors.docs.map((d) => d.id));
    const missing = listings.docs.filter((d) => !have.has(d.id));
    let embedded = 0, failed = 0;
    for (const d of missing) {
      try {
        await syncListingVector(d.id, d.data());
        embedded++;
      } catch (e) {
        failed++;
        logger.error(`matching: backfill of ${d.id} failed: ${e.message}`);
      }
    }
    await ref.update({
      status: "done", embedded, failed,
      finished_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`matching: backfill embedded ${embedded}, failed ${failed}`);
  }
);

/**
 * Re-runs matching for the caller's wants, from pull-to-refresh or turning
 * matching back on. The triggers already match every new listing and want,
 * so this only catches what they missed (e.g. while matching was off).
 * Limited to once per RESCAN_COOLDOWN_MS per user: each run costs a vector
 * search per want plus reads of every candidate owner's wants/listings.
 * Uses stored embeddings only — no Gemini calls.
 */
exports.rescanMatches = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "กรุณาเข้าสู่ระบบ");
    const uid = request.auth.uid;
    await assertNotBanned(uid);
    const userRef = db().collection("users").doc(uid);

    // Claim the slot in a transaction so two quick calls can't both run.
    const waitMs = await db().runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const last = snap.exists && snap.data().last_rescan_at;
      const lastMs = last && typeof last.toMillis === "function" ? last.toMillis() : 0;
      const left = lastMs + RESCAN_COOLDOWN_MS - Date.now();
      if (left > 0) return left;
      tx.update(userRef, { last_rescan_at: admin.firestore.Timestamp.now() });
      return 0;
    });
    if (waitMs > 0) {
      return { created: 0, throttled: true, retry_after_minutes: Math.ceil(waitMs / 60000) };
    }

    let created = 0;
    for (const want of await activeWants(uid)) created += await matchForWant(uid, want);
    return { created, throttled: false };
  }
);

// Exposed for the offline test.
exports._internal = { listingText, hashOf, cosine, bestPair, MIN_SIMILARITY, RESCAN_COOLDOWN_MS };
