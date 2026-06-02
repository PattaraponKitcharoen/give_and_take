import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // 🟢 1. สร้าง Key สำหรับควบคุม SnackBar เฉพาะในหน้านี้
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // ฟังก์ชันช่วยแสดง SnackBar แบบลอย (ไม่ดัน UI อื่นๆ)
  void _showFloatingSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF008080),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String text = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': currentUserId,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'last_sender_id': currentUserId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ฟังก์ชันช่วยดึงชื่อผู้ใช้งานปัจจุบันจาก Firestore
  Future<String> _getCurrentUserName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (doc.exists && doc.data() != null) {
        final name = doc.data()!['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
    return 'ผู้ใช้งาน';
  }

  // ฟังก์ชัน: ยกเลิกข้อเสนอ (ฝั่งคนส่ง)
  Future<void> _cancelOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
    String userName = await _getCurrentUserName();
    _sendSystemMessage('$userName ได้ยกเลิกข้อเสนอนี้แล้ว');
  }

  // ฟังก์ชัน: ปฏิเสธข้อเสนอ (ฝั่งคนรับ)
  Future<void> _rejectOffer(String offerId) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({'status': 'rejected'});
    String userName = await _getCurrentUserName();
    _sendSystemMessage('$userName ได้ปฏิเสธข้อเสนอนี้แล้ว');
  }

  // ฟังก์ชัน: ยอมรับข้อเสนอ พร้อมระบบหักเงินเข้ากองกลาง (Escrow)
  Future<void> _acceptOffer(String offerId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      await db.runTransaction((transaction) async {
        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        
        if (!offerSnap.exists) throw Exception("ไม่พบข้อมูลข้อเสนอ");
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;
        
        int coinOffset = offerData['coin_offset'] ?? 0;
        String senderId = offerData['sender_id'];
        String targetUserId = offerData['target_user_id'];
        
        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        
        String? payerId;
        int amountToPay = 0;
        
        if (coinOffset > 0) {
          payerId = senderId;
          amountToPay = coinOffset;
        } else if (coinOffset < 0) {
          payerId = targetUserId;
          amountToPay = coinOffset.abs();
        }

        if (payerId != null && amountToPay > 0) {
          DocumentReference payerRef = db.collection('users').doc(payerId);
          DocumentSnapshot payerSnap = await transaction.get(payerRef);
          
          if (!payerSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้งาน");
          
          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          
          if (currentBalance < amountToPay) {
            throw Exception("ยอดเงินของฝั่งที่ต้องจ่ายไม่เพียงพอ");
          }
          
          int newBalance = currentBalance - amountToPay;

          transaction.update(payerRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id,
            'user_id': payerId,
            'amount': -amountToPay,
            'balance_after': newBalance,
            'type': 'escrow_lock',
            'status': 'success',
            'reference_id': offerId,
            'description': 'หักเหรียญเข้ากองกลางสำหรับข้อเสนอแลกเปลี่ยน',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        String code1 = (100000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        String code2 = (500000 + (DateTime.now().millisecondsSinceEpoch % 400000)).toString();
        DocumentReference mainTxRef = db.collection('transactions').doc();
        
        transaction.set(mainTxRef, {
          'transaction_id': mainTxRef.id,
          'offer_id': offerId,
          'listings': [offeredItemId, targetItemId],
          'members': [senderId, targetUserId],
          'escrow_coins': amountToPay,
          'status': 'in_progress',
          'cancel_reason': '',
          'verification_codes': {
            senderId: code1,
            targetUserId: code2,
          },
          'confirmed_by_user_ids': [],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.update(offerRef, {'status': 'accepted'});
        
        DocumentReference targetItemRef = db.collection('listings').doc(targetItemId);
        DocumentReference offeredItemRef = db.collection('listings').doc(offeredItemId);
        transaction.update(targetItemRef, {'status': 'in_progress'});
        transaction.update(offeredItemRef, {'status': 'in_progress'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ตกลงแลกเปลี่ยนแล้ว และระบบได้ทำการล็อกเหรียญไว้ในกองกลาง');

      _showFloatingSnackBar('เริ่มการแลกเปลี่ยนเรียบร้อยแล้ว');

    } catch (e) {
      _showFloatingSnackBar('ไม่สามารถทำรายการได้: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  // ตัวช่วยยิงข้อความระบบ
  Future<void> _sendSystemMessage(String text) async {
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'sender_id': 'system',
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system_log',
    });
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message_text': text,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Widget ช่วยสร้างรูปสิ่งของ
  Widget _buildItemThumbnail(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: item)));
      },
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: (item['thumbnail_url'] != null && item['thumbnail_url'] != '') 
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['thumbnail_url'], fit: BoxFit.cover))
                : const Icon(Icons.image, color: Colors.grey, size: 30),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(item['title'] ?? 'ไม่มีชื่อ', overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // ฟังก์ชัน: ยกเลิกดีลที่ตกลงไปแล้ว (Refund และ ปลดล็อกสิ่งของ)
  Future<void> _cancelAcceptedDeal(String offerId, String reason) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      
      DocumentReference mainTxRef = txQuery.docs.first.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot txSnap = await transaction.get(mainTxRef);
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;

        if (txData['status'] != 'in_progress') {
          throw Exception("ไม่สามารถยกเลิกได้ เนื่องจากสถานะไม่ใช่กำลังดำเนินการ");
        }

        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];

        int escrowCoins = txData['escrow_coins'] ?? 0;
        String? payerId;
        DocumentSnapshot? payerSnap;
        DocumentReference? payerRef;
        int newBalance = 0;

        if (escrowCoins > 0) {
          int coinOffset = offerData['coin_offset'] ?? 0;
          String senderId = offerData['sender_id'];
          String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
          
          payerId = coinOffset > 0 ? senderId : targetUserId;
          payerRef = db.collection('users').doc(payerId);
          payerSnap = await transaction.get(payerRef); 

          int currentBalance = (payerSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          newBalance = currentBalance + escrowCoins; 
        }

        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'active'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'active'});

        if (payerRef != null && escrowCoins > 0) {
          transaction.update(payerRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id,
            'user_id': payerId,
            'amount': escrowCoins,
            'balance_after': newBalance,
            'type': 'refund',
            'status': 'success',
            'reference_id': mainTxRef.id,
            'description': 'คืนเหรียญจากระบบกองกลาง (ยกเลิกการแลกเปลี่ยน)',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, {
          'status': 'cancelled',
          'cancel_reason': reason,
          'updated_at': FieldValue.serverTimestamp(),
        });
        transaction.update(offerRef, {'status': 'cancelled'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ได้ยกเลิกการแลกเปลี่ยน ระบบได้ทำการคืนสิ่งของและเหรียญเรียบร้อยแล้ว');

      _showFloatingSnackBar('ยกเลิกการแลกเปลี่ยนสำเร็จ');

    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  // ฟังก์ชัน: หน้าต่างต่อรองราคา (Counter-Offer Dialog)
  void _showCounterOfferDialog(BuildContext context, String offerId, Map<String, dynamic> offerData) {
    final TextEditingController amountController = TextEditingController();
    bool iWillPay = true; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('ต่อรองราคา', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<bool>(
                    value: iWillPay,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('ฉันจะจ่ายเงินเพิ่ม')),
                      DropdownMenuItem(value: false, child: Text('ฉันขอรับเงินเพิ่ม')),
                    ],
                    onChanged: (value) => setState(() => iWillPay = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'จำนวนเหรียญ (Coins)',
                      suffixText: 'Coins',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    int amount = int.tryParse(amountController.text.trim()) ?? 0;
                    if (amount > 0) {
                      Navigator.pop(context);
                      _submitCounterOffer(offerId, offerData, amount, iWillPay);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('ส่งข้อเสนอ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // ฟังก์ชัน: บันทึกการต่อรองราคาลงฐานข้อมูล
  Future<void> _submitCounterOffer(String offerId, Map<String, dynamic> offerData, int amount, bool iWillPay) async {
    String senderId = offerData['sender_id'];
    int newCoinOffset = 0;
    
    if (currentUserId == senderId) {
      newCoinOffset = iWillPay ? amount : -amount;
    } else {
      newCoinOffset = iWillPay ? -amount : amount;
    }

    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
      'coin_offset': newCoinOffset,
      'last_offer_by': currentUserId, 
      'updated_at': FieldValue.serverTimestamp(),
    });

    String userName = await _getCurrentUserName();
    String actionText = iWillPay ? 'เสนอจ่ายเงินเพิ่ม $amount Coins' : 'ขอรับเงินเพิ่ม $amount Coins';
    _sendSystemMessage('$userName ได้ต่อรองเงื่อนไขใหม่: $actionText');
  }

  // หน้าต่าง Pop-up สำหรับกรอกรหัส
  void _showOtpDialog(BuildContext context, String offerId) {
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการรับของ', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'กรอกรหัส 6 หลักของอีกฝ่าย'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyHandoverCode(offerId, otpController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชัน: ตรวจสอบรหัส OTP และโอนเงินจบดีล
  Future<void> _verifyHandoverCode(String offerId, String inputCode) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
      if (txQuery.docs.isEmpty) throw Exception("ไม่พบข้อมูลสัญญากองกลาง");
      
      DocumentReference mainTxRef = txQuery.docs.first.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot txSnap = await transaction.get(mainTxRef);
        Map<String, dynamic> txData = txSnap.data() as Map<String, dynamic>;

        if (txData['status'] != 'in_progress') throw Exception("สถานะดีลไม่ถูกต้อง");

        Map<String, dynamic> codes = txData['verification_codes'] ?? {};
        String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
        String partnerCode = codes[partnerId] ?? '';

        if (inputCode != partnerCode) throw Exception("รหัสยืนยันไม่ถูกต้อง");

        DocumentReference offerRef = db.collection('offers').doc(offerId);
        DocumentSnapshot offerSnap = await transaction.get(offerRef);
        Map<String, dynamic> offerData = offerSnap.data() as Map<String, dynamic>;

        String targetItemId = offerData['target_listing_id'];
        String offeredItemId = offerData['offered_listing_id'];
        
        int escrowCoins = txData['escrow_coins'] ?? 0;
        DocumentReference? receiverRef;
        int newBalance = 0;
        String? receiverId;

        if (escrowCoins > 0) {
          int coinOffset = offerData['coin_offset'] ?? 0;
          String senderId = offerData['sender_id'];
          String targetUserId = offerData['target_user_id'] ?? offerData['target_owner_id'];
          
          receiverId = coinOffset > 0 ? targetUserId : senderId;
          receiverRef = db.collection('users').doc(receiverId);
          DocumentSnapshot receiverSnap = await transaction.get(receiverRef);
          
          int currentBalance = (receiverSnap.data() as Map<String, dynamic>)['coins_balance'] ?? 0;
          newBalance = currentBalance + escrowCoins;
        }

        transaction.update(db.collection('listings').doc(targetItemId), {'status': 'completed'});
        transaction.update(db.collection('listings').doc(offeredItemId), {'status': 'completed'});

        if (receiverRef != null && escrowCoins > 0 && receiverId != null) {
          transaction.update(receiverRef, {'coins_balance': newBalance});

          DocumentReference walletTxRef = db.collection('wallet_transactions').doc();
          transaction.set(walletTxRef, {
            'log_id': walletTxRef.id,
            'user_id': receiverId,
            'amount': escrowCoins,
            'balance_after': newBalance,
            'type': 'escrow_release',
            'status': 'success',
            'reference_id': mainTxRef.id,
            'description': 'ได้รับเหรียญจากระบบกองกลาง (แลกเปลี่ยนสำเร็จ)',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(mainTxRef, {
          'status': 'completed',
          'updated_at': FieldValue.serverTimestamp(),
        });
        transaction.update(offerRef, {'status': 'completed'});
      });

      String userName = await _getCurrentUserName();
      _sendSystemMessage('$userName ได้ยืนยันรหัสส่งมอบแล้ว การแลกเปลี่ยนสำเร็จลุล่วง!');

      if (mounted) {
        _showFloatingSnackBar('ยืนยันรหัสสำเร็จ ดีลจบสมบูรณ์');
        
        final txQuery = await db.collection('transactions').where('offer_id', isEqualTo: offerId).limit(1).get();
        if (txQuery.docs.isNotEmpty) {
           var txData = txQuery.docs.first.data() as Map<String, dynamic>;
           String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
           String transactionId = txQuery.docs.first.id;
           
           Future.delayed(const Duration(milliseconds: 500), () {
             _showRatingDialog(context, partnerId, transactionId);
           });
        }
      }

    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  // 🟢 ฟังก์ชัน: หน้าต่าง Pop-up ให้คะแนนดาว (อัปเดตให้มีช่องใส่ Comment)
  void _showRatingDialog(BuildContext context, String targetUserId, String transactionId) {
    int selectedRating = 5; 
    final TextEditingController commentController = TextEditingController(); // ตัวแปรเก็บคอมเมนต์

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('ให้คะแนนการแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView( // ป้องกันคีย์บอร์ดบัง
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ความประทับใจต่อคู่กรณีในดีลนี้', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    // 🟢 เพิ่มช่องกรอกคอมเมนต์
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'เขียนรีวิวสั้นๆ (ไม่บังคับ)...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('ข้าม', style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // ส่งคอมเมนต์พ่วงไปให้ฟังก์ชันบันทึก
                    _submitReview(targetUserId, transactionId, selectedRating, commentController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                  child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 🟢 ฟังก์ชัน: คำนวณและบันทึกคะแนนลงฐานข้อมูล (อัปเดตรับค่า comment)
  Future<void> _submitReview(String targetUserId, String transactionId, int rating, String comment) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      final existingReview = await db.collection('reviews')
          .where('transaction_id', isEqualTo: transactionId)
          .where('reviewer_id', isEqualTo: currentUserId)
          .get();

      if (existingReview.docs.isNotEmpty) {
        _showFloatingSnackBar('คุณได้ให้คะแนนดีลนี้ไปแล้ว', isError: true);
        return;
      }

      await db.runTransaction((transaction) async {
        DocumentReference userRef = db.collection('users').doc(targetUserId);
        DocumentSnapshot userSnap = await transaction.get(userRef);

        if (!userSnap.exists) throw Exception('ไม่พบข้อมูลผู้ใช้ของคู่กรณี');

        Map<String, dynamic> userData = userSnap.data() as Map<String, dynamic>;
        
        num currentSum = userData['total_rating_sum'] ?? 0;
        num currentCount = userData['rating_count'] ?? 0;

        num newSum = currentSum + rating;
        num newCount = currentCount + 1;
        double newScore = newSum / newCount;

        transaction.update(userRef, {
          'total_rating_sum': newSum,
          'rating_count': newCount,
          'rating_scores': double.parse(newScore.toStringAsFixed(1)), 
        });

        DocumentReference reviewRef = db.collection('reviews').doc();
        transaction.set(reviewRef, {
          'review_id': reviewRef.id,
          'transaction_id': transactionId,
          'reviewer_id': currentUserId,
          'target_id': targetUserId,
          'rating': rating,
          'comment': comment, // 🟢 บันทึกคอมเมนต์ลงฐานข้อมูล
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      _showFloatingSnackBar('ส่งคะแนนรีวิวเรียบร้อย ขอบคุณครับ!');
    } catch (e) {
      _showFloatingSnackBar('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('เจรจาแลกเปลี่ยน', style: TextStyle(color: Colors.black87, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
          builder: (context, roomSnap) {
            if (!roomSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            final roomData = roomSnap.data!.data() as Map<String, dynamic>? ?? {};
            final String? activeOfferId = roomData['active_offer_id'];

            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(widget.roomId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        reverse: true, 
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index].data() as Map<String, dynamic>;
                          bool isMe = msg['sender_id'] == currentUserId;
                          String type = msg['type'] ?? 'text';

                          if (type == 'system_log') {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(msg['content'], style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            );
                          }

                          if (type == 'system_offer') {
                            final offerDataFromMsg = msg['offer_data'] ?? {};
                            final targetItem = offerDataFromMsg['target_item'] ?? {};
                            final offeredItem = offerDataFromMsg['offered_item'] ?? {};
                            
                            bool isSender = (msg['sender_id'] == currentUserId);
                            var myItemData = isSender ? offeredItem : targetItem;
                            var theirItemData = isSender ? targetItem : offeredItem;

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('offers').doc(activeOfferId).snapshots(),
                              builder: (context, offerSnap) {
                                String offerStatus = 'cancelled';
                                Map<String, dynamic> offerData = {};
                                
                                if (offerSnap.hasData && offerSnap.data!.exists) {
                                  offerData = offerSnap.data!.data() as Map<String, dynamic>;
                                  offerStatus = offerData['status'] ?? 'pending';
                                }

                                String lastOfferBy = offerData['last_offer_by'] ?? offerData['sender_id'] ?? '';
                                bool isMyTurn = (lastOfferBy != currentUserId); 

                                int currentOffset = offerData['coin_offset'] ?? 0;
                                String offsetText = 'แลกของต่อของ (ไม่มีการเพิ่มเหรียญ)';
                                Color offsetColor = Colors.black54;

                                if (currentOffset > 0) {
                                  bool iAmSender = (currentUserId == offerData['sender_id']);
                                  offsetText = iAmSender ? 'คุณเสนอจ่ายเพิ่ม $currentOffset Coins' : 'อีกฝ่ายเสนอจ่ายเพิ่ม $currentOffset Coins';
                                  offsetColor = iAmSender ? Colors.red : Colors.green;
                                } else if (currentOffset < 0) {
                                  bool iAmSender = (currentUserId == offerData['sender_id']);
                                  offsetText = iAmSender ? 'คุณขอรับเงินเพิ่ม ${currentOffset.abs()} Coins' : 'อีกฝ่ายขอรับเงินเพิ่ม ${currentOffset.abs()} Coins';
                                  offsetColor = iAmSender ? Colors.green : Colors.red;
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF008080), width: 2),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('ข้อเสนอแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildItemThumbnail(context, theirItemData),
                                          const Icon(Icons.sync_alt, color: Color(0xFF008080), size: 32),
                                          _buildItemThumbnail(context, myItemData),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.monetization_on, color: offsetColor, size: 16),
                                            const SizedBox(width: 8),
                                            Text(offsetText, style: TextStyle(color: offsetColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 16),
                                      
                                      if (offerStatus == 'pending') ...[
                                        if (!isMyTurn)
                                          Column(
                                            children: [
                                              const Text('รออีกฝ่ายพิจารณาข้อเสนอ...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton(
                                                  onPressed: () => _cancelOffer(activeOfferId!),
                                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                  child: const Text('ยกเลิกข้อเสนอ'),
                                                ),
                                              ),
                                            ]
                                          )
                                        else 
                                          Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () => _rejectOffer(activeOfferId!),
                                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                      child: const Text('ปฏิเสธ'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () => _showCounterOfferDialog(context, activeOfferId!, offerData),
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                                      child: const Text('ต่อรอง', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () => _acceptOffer(activeOfferId!),
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                                                  child: const Text('ยอมรับข้อเสนอ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          )
                                      ] else if (offerStatus == 'accepted' || offerStatus == 'in_progress') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                          child: const Text('ตกลงแลกเปลี่ยนแล้ว', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                        ),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: activeOfferId).limit(1).snapshots(),
                                          builder: (context, txSnap) {
                                            if (!txSnap.hasData || txSnap.data!.docs.isEmpty) return const SizedBox();
                                            var txData = txSnap.data!.docs.first.data() as Map<String, dynamic>;
                                            var codes = txData['verification_codes'] ?? {};
                                            String myCode = codes[currentUserId] ?? '------';
                                            
                                            return Column(
                                              children: [
                                                const SizedBox(height: 16),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                                  child: Column(
                                                    children: [
                                                      const Text('รหัสของคุณ (ให้อีกฝ่ายกรอก)', style: TextStyle(color: Colors.black54)),
                                                      Text(myCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5, color: Color(0xFF008080))),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: () => _showOtpDialog(context, activeOfferId!),
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                                                    child: const Text('กรอกรหัสของอีกฝ่าย', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton(
                                                    onPressed: () => _cancelAcceptedDeal(activeOfferId!, 'เปลี่ยนใจไม่แลกแล้ว'),
                                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                                    child: const Text('ยกเลิกดีลนี้'),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                        )
                                      ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: offerStatus == 'completed' ? Colors.green.shade50 : (offerStatus == 'rejected' ? Colors.orange.shade50 : Colors.red.shade50),
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Text(
                                          offerStatus == 'completed' ? 'แลกเปลี่ยนสำเร็จสมบูรณ์' : (offerStatus == 'rejected' ? 'ถูกปฏิเสธ' : 'ถูกยกเลิกแล้ว'),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: offerStatus == 'completed' ? Colors.green : (offerStatus == 'rejected' ? Colors.orange : Colors.red)),
                                        ),
                                      ),
                                      
                                      // 🟢 ปุ่มให้คะแนน อัปเดตให้มีสถานะเป็นสีเทา (Disable) ถ้าเคยรีวิวแล้ว
                                      if (offerStatus == 'completed') ...[
                                        FutureBuilder<QuerySnapshot>(
                                          future: FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: activeOfferId).limit(1).get(),
                                          builder: (context, txSnap) {
                                            if (!txSnap.hasData || txSnap.data!.docs.isEmpty) return const SizedBox();
                                            String transactionId = txSnap.data!.docs.first.id;
                                            var txData = txSnap.data!.docs.first.data() as Map<String, dynamic>;
                                            String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);

                                            // ใช้ StreamBuilder ดึงประวัติรีวิว ถ้ามีแล้วจะล็อกปุ่ม
                                            return StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance.collection('reviews')
                                                .where('transaction_id', isEqualTo: transactionId)
                                                .where('reviewer_id', isEqualTo: currentUserId)
                                                .snapshots(),
                                              builder: (context, reviewSnap) {
                                                bool hasReviewed = false;
                                                if (reviewSnap.hasData && reviewSnap.data!.docs.isNotEmpty) {
                                                  hasReviewed = true; // หาเจอแปลว่าเคยรีวิวแล้ว
                                                }

                                                return Column(
                                                  children: [
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton.icon(
                                                        // 🟢 ถ้า hasReviewed เป็น true ค่า onPressed จะเป็น null (ปุ่มเทาอัตโนมัติ)
                                                        onPressed: hasReviewed ? null : () {
                                                          _showRatingDialog(context, partnerId, transactionId);
                                                        },
                                                        icon: Icon(
                                                          hasReviewed ? Icons.check_circle : Icons.star, 
                                                          color: hasReviewed ? Colors.white70 : Colors.white, 
                                                          size: 20
                                                        ),
                                                        label: Text(
                                                          hasReviewed ? 'คุณให้คะแนนเรียบร้อยแล้ว' : 'ให้คะแนนคู่กรณี', 
                                                          style: TextStyle(
                                                            color: hasReviewed ? Colors.white70 : Colors.white, 
                                                            fontWeight: FontWeight.bold
                                                          )
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.amber.shade700,
                                                          disabledBackgroundColor: Colors.grey.shade400, // สีปุ่มตอนโดน Disable
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        ),
                                      ]
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // วาดบับเบิลข้อความธรรมดา
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF008080) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                          ),
                        );
                      },
                    );
                  },
                  ),
                ),
                
                // ช่องพิมพ์ข้อความด้านล่าง
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ข้อความ...',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF008080),
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}