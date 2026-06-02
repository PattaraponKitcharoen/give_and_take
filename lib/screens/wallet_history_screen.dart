import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final Color tealColor = const Color(0xFF008080);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ประวัติการโอนเหรียญ', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: currentUserId == null
          ? const Center(child: Text('กรุณาล็อกอิน'))
          : StreamBuilder<QuerySnapshot>(
              // 🟢 ดึงข้อมูลเฉพาะประวัติของคนที่ล็อกอินอยู่ เรียงจากใหม่ไปเก่า
              stream: FirebaseFirestore.instance
                  .collection('wallet_transactions')
                  .where('user_id', isEqualTo: currentUserId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // แจ้ง Error เผื่อลืมทำ Index ใน Firebase
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SelectableText('เกิดข้อผิดพลาด (อย่าลืมทำ Index): ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีประวัติการทำธุรกรรม', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final int amount = data['amount'] ?? 0;
                    final String description = data['description'] ?? 'ทำรายการ';
                    
                    // 🟢 จัดการรูปแบบเวลา
                    String timeText = '';
                    if (data['created_at'] != null) {
                      DateTime date = (data['created_at'] as Timestamp).toDate();
                      timeText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    // 🟢 เช็คว่าเงินเข้าหรือเงินออก เพื่อกำหนดสี
                    final bool isPositive = amount > 0;
                    final Color amountColor = isPositive ? Colors.green : Colors.red;
                    final String amountPrefix = isPositive ? '+' : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: amountColor.withOpacity(0.1),
                          child: Icon(
                            isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                            color: amountColor,
                          ),
                        ),
                        title: Text(description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(timeText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Text(
                          '$amountPrefix$amount', // โชว์เช่น +50 หรือ -100
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}