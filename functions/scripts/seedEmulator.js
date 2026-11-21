// Seeds the local Firebase emulators with the accounts and listings the
// integration tests (integration_test/) expect. Refuses to run against
// anything but the emulators.
//
//   firebase emulators:exec --project demo-give-and-take \
//     "node functions/scripts/seedEmulator.js && <run tests>"
//
// Test accounts (emulator only), password for all: test-password-123
//   alice@test.dev   regular user, owns "เสื่อโยคะ"
//   bob@test.dev     regular user, owns "หูฟังบลูทูธ JBL"
//   banned@test.dev  permanently banned
//   admin@test.dev   admin
//   carol@test.dev   regular user, owns "โคมไฟตั้งโต๊ะ" (deletes her account)
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-give-and-take";
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("seedEmulator: FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST not set — refusing to touch a real project.");
  process.exit(1);
}
if (!process.env.GCLOUD_PROJECT.startsWith("demo-")) {
  console.error(`seedEmulator: project ${process.env.GCLOUD_PROJECT} is not a demo- project — refusing.`);
  process.exit(1);
}

const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = admin.firestore();
const PASSWORD = "test-password-123";
const now = admin.firestore.Timestamp.now();
const hatYai = { latitude: 7.01, longitude: 100.47, district: "หาดใหญ่", province: "สงขลา", display_name: "หาดใหญ่, สงขลา" };

const users = [
  { uid: "alice", email: "alice@test.dev", name: "Alice" },
  { uid: "bob", email: "bob@test.dev", name: "Bob" },
  { uid: "banned", email: "banned@test.dev", name: "Banned User", status: "banned", ban_reason: "สแปม / ลงของซ้ำ" },
  { uid: "admin", email: "admin@test.dev", name: "Admin", role: "admin" },
  { uid: "carol", email: "carol@test.dev", name: "Carol" },
];

const listings = [
  { id: "alice-mat", owner: "alice", title: "เสื่อโยคะ หนา 6mm", category: "กีฬา & กิจกรรมกลางแจ้ง", coins: 300 },
  { id: "bob-headphones", owner: "bob", title: "หูฟังบลูทูธ JBL", category: "อุปกรณ์ไอที & แก็ดเจ็ต", coins: 350 },
  { id: "carol-lamp", owner: "carol", title: "โคมไฟตั้งโต๊ะ", category: "ของใช้ในบ้าน & เฟอร์นิเจอร์", coins: 200 },
];

(async () => {
  for (const u of users) {
    await admin.auth().createUser({ uid: u.uid, email: u.email, password: PASSWORD, emailVerified: true, displayName: u.name });
    await db.collection("users").doc(u.uid).set({
      name: u.name, email: u.email, tel: "", bio: "", profile_img_url: "",
      role: u.role || "user", status: u.status || "active",
      ...(u.ban_reason ? { ban_reason: u.ban_reason, banned_at: now } : {}),
      coins_balance: 1000, owner_rating_scores: 0, owner_rating_count: 0,
      is_email_verified: true, is_phone_verified: false, is_verified: false,
      // Students skip the "verify you're a student" dialog on first launch.
      is_student: true, faculty: "วิศวกรรมศาสตร์", academic_year: "3",
      wishlist: [], location: hatYai, created_at: now, updated_at: now,
    });
  }
  for (const l of listings) {
    const owner = users.find((u) => u.uid === l.owner);
    await db.collection("listings").doc(l.id).set({
      type: "item", status: "active", category: l.category, owner_id: l.owner,
      owner_name: owner.name, owner_profile_img: "", owner_rating_scores: 0,
      title: l.title, description: `${l.title} สภาพดี`, condition: "มือสองสภาพดี",
      estimated_coins: l.coins, thumbnail_url: "", images: [], location: hatYai,
      created_at: now, updated_at: now,
    });
  }
  console.log(`seedEmulator: ${users.length} users, ${listings.length} listings`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
