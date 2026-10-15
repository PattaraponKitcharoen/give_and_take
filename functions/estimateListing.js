const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { GoogleGenAI } = require("@google/genai");
const { assertNotBanned } = require("./moderation");

// Set with: firebase functions:secrets:set GEMINI_API_KEY
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Tried in order. On the free tier the newest Flash models (3.8, 3.7) often
// hang for minutes at busy times, while 3.6 answered in ~4 s with the same
// accuracy on our test photos; 3.5 is the fallback.
const MODELS = ["gemini-3.6-flash", "gemini-3.5-flash"];
// Per-model wait, so both attempts fit in the function's 120 s timeout.
const MODEL_TIMEOUT_MS = 45 * 1000;
const MAX_IMAGES = 6;
// Base64 length per image. The app already shrinks photos to <=1600px at
// 80% quality, so a real photo is well under this.
const MAX_IMAGE_B64 = 4 * 1024 * 1024;
const MIME_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];

// Must match the choices in lib/screens/add_post_screen.dart.
const CATEGORIES = [
  "อุปกรณ์ไอที & แก็ดเจ็ต",
  "แฟชั่น & เครื่องแต่งกาย",
  "เกม & ของเล่น",
  "ของใช้ในบ้าน & เฟอร์นิเจอร์",
  "หนังสือ & เครื่องเขียน",
  "กีฬา & กิจกรรมกลางแจ้ง",
  "สุขภาพ & ความงาม",
  "ดนตรี & ศิลปะ",
  "อุปกรณ์สัตว์เลี้ยง",
  "ยานพาหนะ & อะไหล่",
  "อื่นๆ (Miscellaneous)",
];
const CONDITIONS = ["มือหนึ่ง", "มือสองสภาพนางฟ้า", "มือสองสภาพดี", "มือสองเสียหายเล็กน้อย"];
const CONFIDENCE = ["low", "medium", "high"];

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string", description: "ชื่อสิ่งของสั้น ๆ ระบุแบรนด์/รุ่นถ้าเห็นในรูป" },
    description: { type: "string", description: "คำอธิบาย 2-4 ประโยค: คืออะไร สเปกที่เห็น สภาพและตำหนิที่เห็นในรูป" },
    category: { type: "string", enum: CATEGORIES },
    condition: { type: "string", enum: CONDITIONS },
    coins_min: { type: "integer" },
    coins_max: { type: "integer" },
    coins_suggested: { type: "integer" },
    reason: { type: "string", description: "เหตุผลของมูลค่าที่ประเมิน 1-2 ประโยค" },
    confidence: { type: "string", enum: CONFIDENCE },
  },
  required: [
    "title", "description", "category", "condition",
    "coins_min", "coins_max", "coins_suggested", "reason", "confidence",
  ],
};

const SYSTEM_INSTRUCTION = `คุณเป็นผู้ช่วยลงประกาศในแอป Give & Take แอปแลกเปลี่ยนสิ่งของมือสองของนักศึกษาและบุคลากร ม.อ. หาดใหญ่
หน้าที่: ดูรูปสิ่งของ แล้วกรอกข้อมูลประกาศและประเมินมูลค่าเป็น "เหรียญ"

หลักการ:
- 1 เหรียญ เทียบเท่าประมาณ 1 บาท ของราคาขายต่อมือสองในประเทศไทย ไม่ใช่ราคาซื้อของใหม่
- ประเมินสภาพจากสิ่งที่เห็นในรูปจริง ถ้าเห็นรอยหรือตำหนิให้ระบุในคำอธิบาย
- ถ้าไม่แน่ใจรุ่นหรือแบรนด์ อย่าเดา ให้บรรยายตามที่เห็น และตั้ง confidence เป็น low
- ช่วงมูลค่า coins_min ถึง coins_max ควรกว้างพอสมเหตุสมผล และ coins_suggested อยู่ในช่วงนั้น
- เขียนภาษาไทย กระชับ เป็นมิตร
- ถ้ารูปไม่ใช่สิ่งของที่แลกเปลี่ยนได้ ให้ title เป็น "ไม่สามารถระบุสิ่งของได้" และ confidence เป็น low`;

function toInt(v) {
  const n = Math.round(Number(v));
  return Number.isFinite(n) && n > 0 ? n : 0;
}

/** Clamp whatever the model returned into values the app can use as-is. */
function normalize(raw) {
  let min = toInt(raw.coins_min);
  let max = toInt(raw.coins_max);
  let suggested = toInt(raw.coins_suggested);
  if (min > max) [min, max] = [max, min];
  if (!suggested) suggested = Math.round((min + max) / 2);
  if (!min) min = suggested;
  if (!max) max = suggested;
  suggested = Math.min(Math.max(suggested, min), max);
  return {
    title: String(raw.title || "").trim().slice(0, 80),
    description: String(raw.description || "").trim().slice(0, 1000),
    category: CATEGORIES.includes(raw.category) ? raw.category : CATEGORIES[CATEGORIES.length - 1],
    condition: CONDITIONS.includes(raw.condition) ? raw.condition : "มือสองสภาพดี",
    coins_min: min,
    coins_max: max,
    coins_suggested: suggested,
    reason: String(raw.reason || "").trim().slice(0, 300),
    confidence: CONFIDENCE.includes(raw.confidence) ? raw.confidence : "low",
  };
}

/** Recently traded items, so estimates follow what people here actually use. */
async function marketReference(db) {
  try {
    const snap = await db.collection("listings")
      .where("status", "==", "completed")
      .limit(30)
      .get();
    return snap.docs
      .map((d) => d.data())
      .filter((l) => l.title && l.estimated_coins)
      .map((l) => `- ${l.title} | ${l.category || "-"} | ${l.condition || "-"} | ${l.estimated_coins} เหรียญ`)
      .join("\n");
  } catch (error) {
    logger.warn(`estimateListing: market reference unavailable: ${error.message}`);
    return "";
  }
}

/**
 * Looks at an item's photos and suggests the listing fields plus a coin range.
 *
 * Callable: { images: [{ data: <base64>, mimeType }], hint?: string }
 * Returns:  { title, description, category, condition,
 *             coins_min, coins_max, coins_suggested, reason, confidence }
 *
 * Only a suggestion: the app fills the form and the owner can change
 * anything before posting.
 */
exports.estimateListing = onCall(
  // Free-tier keys queue at busy times (seen 5-30 s), so leave headroom.
  { secrets: [geminiApiKey], timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "กรุณาล็อกอินก่อนใช้งาน");
    }
    await assertNotBanned(request.auth.uid);
    if (request.auth.token.email_verified === false) {
      throw new HttpsError("permission-denied", "กรุณายืนยันอีเมลก่อนใช้งานผู้ช่วย AI");
    }

    const images = (request.data && request.data.images) || [];
    if (!Array.isArray(images) || images.length === 0) {
      throw new HttpsError("invalid-argument", "กรุณาเพิ่มรูปสิ่งของอย่างน้อย 1 รูป");
    }
    if (images.length > MAX_IMAGES) {
      throw new HttpsError("invalid-argument", `ส่งรูปได้สูงสุด ${MAX_IMAGES} รูป`);
    }
    for (const img of images) {
      if (!img || typeof img.data !== "string" || !img.data ||
          !MIME_TYPES.includes(img.mimeType)) {
        throw new HttpsError("invalid-argument", "รูปแบบไฟล์รูปไม่ถูกต้อง");
      }
      if (img.data.length > MAX_IMAGE_B64) {
        throw new HttpsError("invalid-argument", "ไฟล์รูปใหญ่เกินไป");
      }
    }
    const hint = String((request.data && request.data.hint) || "").trim().slice(0, 300);

    const market = await marketReference(admin.firestore());
    const prompt = [
      `มีรูปสิ่งของ ${images.length} รูป (รูปแรกคือรูปหน้าปก) ช่วยกรอกข้อมูลประกาศและประเมินมูลค่า`,
      hint ? `ข้อมูลเพิ่มเติมจากผู้ลงประกาศ: ${hint}` : "",
      market ? `ตัวอย่างสิ่งของที่เคยแลกสำเร็จในแอปนี้ (ชื่อ | หมวด | สภาพ | มูลค่า) ใช้เทียบระดับมูลค่าได้:\n${market}` : "",
    ].filter(Boolean).join("\n\n");

    const client = new GoogleGenAI({ apiKey: geminiApiKey.value() });
    const request_ = {
      system_instruction: SYSTEM_INSTRUCTION,
      input: [
        { type: "text", text: prompt },
        ...images.map((img) => ({ type: "image", data: img.data, mime_type: img.mimeType })),
      ],
      response_format: { type: "text", mime_type: "application/json", schema: RESPONSE_SCHEMA },
      // Default thinking made a 3-photo estimate take ~90 s; "low" keeps
      // the same answer quality for this task in a few seconds.
      generation_config: { thinking_level: "low" },
      store: false,
    };

    let raw = null;
    let lastError = null;
    for (const model of MODELS) {
      const started = Date.now();
      try {
        const interaction = await Promise.race([
          client.interactions.create({ model, ...request_ }),
          new Promise((_, reject) => setTimeout(
            () => reject(new Error(`timeout after ${MODEL_TIMEOUT_MS} ms`)), MODEL_TIMEOUT_MS)),
        ]);
        raw = JSON.parse(interaction.output_text || "{}");
        logger.info(`estimateListing: ${model} answered in ${Date.now() - started} ms`);
        break;
      } catch (error) {
        lastError = error;
        logger.warn(`estimateListing: ${model} failed after ${Date.now() - started} ms: ${error.message}`);
      }
    }
    if (!raw) {
      logger.error(`estimateListing failed for ${request.auth.uid}: ${lastError && lastError.message}`);
      const busy = /429|quota|rate|timeout/i.test((lastError && lastError.message) || "");
      throw new HttpsError(
        busy ? "resource-exhausted" : "internal",
        busy ? "ผู้ช่วย AI มีผู้ใช้งานมากเกินไป กรุณาลองใหม่ในอีกสักครู่" : "ผู้ช่วย AI ประเมินไม่สำเร็จ กรุณาลองใหม่"
      );
    }

    const result = normalize(raw);
    logger.info(`estimateListing ${request.auth.uid}: ${images.length} images → ${result.coins_suggested} coins (${result.confidence})`);
    return result;
  }
);

exports._internal = { normalize, CATEGORIES, CONDITIONS };
