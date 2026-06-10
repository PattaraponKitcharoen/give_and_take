import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/item_detail_screen.dart'; 

class SystemOfferCard extends StatelessWidget {
  final Map<String, dynamic> msgData;
  final String? activeOfferId;
  final String currentUserId;
  final VoidCallback onCancel;
  final VoidCallback onReject;
  final VoidCallback onAccept;
  final Function(Map<String, dynamic>) onCounter;
  final VoidCallback onVerifyOtp;
  final VoidCallback onCancelDeal;
  final Function(String, String) onOpenRating;

  const SystemOfferCard({
    super.key, required this.msgData, required this.activeOfferId, required this.currentUserId,
    required this.onCancel, required this.onReject, required this.onAccept, required this.onCounter,
    required this.onVerifyOtp, required this.onCancelDeal, required this.onOpenRating,
  });

  Widget _buildItemThumbnail(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(itemData: item))),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
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

  @override
  Widget build(BuildContext context) {
    final offerDataFromMsg = msgData['offer_data'] ?? {};
    final targetItem = offerDataFromMsg['target_item'] ?? {};
    final offeredItem = offerDataFromMsg['offered_item'] ?? {};
    
    bool isSender = (msgData['sender_id'] == currentUserId);
    var myItemData = isSender ? offeredItem : targetItem;
    var theirItemData = isSender ? targetItem : offeredItem;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('offers').doc(activeOfferId).snapshots(),
      builder: (context, offerSnap) {
        String offerStatus = 'cancelled'; Map<String, dynamic> offerData = {};
        if (offerSnap.hasData && offerSnap.data!.exists) {
          offerData = offerSnap.data!.data() as Map<String, dynamic>;
          offerStatus = offerData['status'] ?? 'pending';
        }

        String lastOfferBy = offerData['last_offer_by'] ?? offerData['sender_id'] ?? '';
        bool isMyTurn = (lastOfferBy != currentUserId); 
        int currentOffset = offerData['coin_offset'] ?? 0;
        String offsetText = 'แลกของต่อของ (ไม่มีการเพิ่มเหรียญ)'; Color offsetColor = Colors.black54;

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
            color: Colors.white, borderRadius: BorderRadius.circular(16),
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
                  children: [Icon(Icons.monetization_on, color: offsetColor, size: 16), const SizedBox(width: 8), Text(offsetText, style: TextStyle(color: offsetColor, fontWeight: FontWeight.bold, fontSize: 13))],
                ),
              ),
              const Divider(height: 16),
              if (offerStatus == 'pending') ...[
                if (!isMyTurn)
                  Column(
                    children: [
                      const Text('รออีกฝ่ายพิจารณาข้อเสนอ...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ยกเลิกข้อเสนอ'))),
                    ]
                  )
                else 
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: onReject, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ปฏิเสธ'))),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(onPressed: () => onCounter(offerData), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('ต่อรอง', style: TextStyle(color: Colors.white)))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('ยอมรับข้อเสนอ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                    ],
                  )
              ] else if (offerStatus == 'accepted' || offerStatus == 'in_progress') ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('ตกลงแลกเปลี่ยนแล้ว', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
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
                        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text('รหัสของคุณ (ให้อีกฝ่ายกรอก)', style: TextStyle(color: Colors.black54)), Text(myCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5, color: Color(0xFF008080)))])),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onVerifyOtp, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('กรอกรหัสของอีกฝ่าย', style: TextStyle(color: Colors.white)))),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancelDeal, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('ยกเลิกดีลนี้'))),
                      ],
                    );
                  }
                )
              ] else ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: offerStatus == 'completed' ? Colors.green.shade50 : (offerStatus == 'rejected' ? Colors.orange.shade50 : Colors.red.shade50), borderRadius: BorderRadius.circular(8)), child: Text(offerStatus == 'completed' ? 'แลกเปลี่ยนสำเร็จสมบูรณ์' : (offerStatus == 'rejected' ? 'ถูกปฏิเสธ' : 'ถูกยกเลิกแล้ว'), style: TextStyle(fontWeight: FontWeight.bold, color: offerStatus == 'completed' ? Colors.green : (offerStatus == 'rejected' ? Colors.orange : Colors.red)))),
                if (offerStatus == 'completed') ...[
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('transactions').where('offer_id', isEqualTo: activeOfferId).limit(1).get(),
                    builder: (context, txSnap) {
                      if (!txSnap.hasData || txSnap.data!.docs.isEmpty) return const SizedBox();
                      String transactionId = txSnap.data!.docs.first.id;
                      var txData = txSnap.data!.docs.first.data() as Map<String, dynamic>;
                      String partnerId = (txData['members'] as List).firstWhere((id) => id != currentUserId);
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('reviews').where('transaction_id', isEqualTo: transactionId).where('reviewer_id', isEqualTo: currentUserId).snapshots(),
                        builder: (context, reviewSnap) {
                          bool hasReviewed = reviewSnap.hasData && reviewSnap.data!.docs.isNotEmpty;
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: hasReviewed ? null : () => onOpenRating(partnerId, transactionId), icon: Icon(hasReviewed ? Icons.check_circle : Icons.star, color: hasReviewed ? Colors.white70 : Colors.white, size: 20), label: Text(hasReviewed ? 'คุณให้คะแนนเรียบร้อยแล้ว' : 'ให้คะแนนคู่กรณี', style: TextStyle(color: hasReviewed ? Colors.white70 : Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, disabledBackgroundColor: Colors.grey.shade400))),
                            ],
                          );
                        },
                      );
                    }
                  ),
                ]
              ]
            ],
          ),
        );
      },
    );
  }
}