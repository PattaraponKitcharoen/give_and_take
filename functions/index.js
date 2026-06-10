const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.acceptTradeOffer = functions.https.onCall(async (data, context) => {
  // 1. ตรวจสอบว่าเรียกคำสั่งผ่านแอปที่ล็อกอินแล้วเท่านั้น
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "กรุณาล็อกอินก่อนทำรายการ");
  }

  const offerId = data.offerId;
  const db = admin.firestore();

  try {
    // 2. ใช้ Transaction เพื่อรับประกันว่าข้อมูลจะถูกบันทึกครบทุกจุดพร้อมกัน
    await db.runTransaction(async (transaction) => {
      const offerRef = db.collection('offers').doc(offerId);
      const offerSnap = await transaction.get(offerRef);

      if (!offerSnap.exists) throw new Error("ไม่พบข้อมูลข้อเสนอ");
      const offerData = offerSnap.data();

      const coinOffset = offerData.coin_offset || 0;
      const senderId = offerData.sender_id;
      const targetUserId = offerData.target_user_id;
      const targetItemId = offerData.target_listing_id;
      const offeredItemId = offerData.offered_listing_id;

      let payerId = null;
      let amountToPay = 0;

      // 3. คำนวณว่าใครเป็นคนต้องจ่ายเหรียญ
      if (coinOffset > 0) {
        payerId = senderId;
        amountToPay = coinOffset;
      } else if (coinOffset < 0) {
        payerId = targetUserId;
        amountToPay = Math.abs(coinOffset);
      }

      // 4. หักเหรียญและสร้างประวัติลง Wallet
      if (payerId && amountToPay > 0) {
        const payerRef = db.collection('users').doc(payerId);
        const payerSnap = await transaction.get(payerRef);
        if (!payerSnap.exists) throw new Error("ไม่พบข้อมูลผู้ใช้งาน");

        const currentBalance = payerSnap.data().coins_balance || 0;
        if (currentBalance < amountToPay) throw new Error("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");

        const newBalance = currentBalance - amountToPay;
        transaction.update(payerRef, { coins_balance: newBalance });

        const walletTxRef = db.collection('wallet_transactions').doc();
        transaction.set(walletTxRef, {
          log_id: walletTxRef.id,
          user_id: payerId,
          amount: -amountToPay,
          balance_after: newBalance,
          type: 'escrow_lock',
          status: 'success',
          reference_id: offerId,
          description: 'หักเหรียญเข้ากองกลางสำหรับข้อเสนอแลกเปลี่ยน',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // 5. สร้างรหัสยืนยันและเปิดห้อง Transaction
      const code1 = (100000 + (Date.now() % 400000)).toString();
      const code2 = (500000 + (Date.now() % 400000)).toString();
      
      const mainTxRef = db.collection('transactions').doc();
      transaction.set(mainTxRef, {
        transaction_id: mainTxRef.id,
        offer_id: offerId,
        listings: [offeredItemId, targetItemId],
        members: [senderId, targetUserId],
        escrow_coins: amountToPay,
        status: 'in_progress',
        cancel_reason: '',
        verification_codes: { [senderId]: code1, [targetUserId]: code2 },
        confirmed_by_user_ids: [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. อัปเดตสถานะของต่างๆ ให้เป็นระหว่างดำเนินการ
      transaction.update(offerRef, { status: 'accepted' });
      transaction.update(db.collection('listings').doc(targetItemId), { status: 'in_progress' });
      transaction.update(db.collection('listings').doc(offeredItemId), { status: 'in_progress' });
    });

    return { success: true, message: "เริ่มการแลกเปลี่ยนและหักเหรียญสำเร็จ" };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});