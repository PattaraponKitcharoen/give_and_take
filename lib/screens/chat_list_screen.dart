import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; // อย่าลืมสร้างไฟล์นี้ด้วย

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final Color tealColor = const Color(0xFF008080);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อความ', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🟢 ดึงเฉพาะห้องแชทที่มี UID ของเราอยู่ใน participants
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUserId)
            .orderBy('updated_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // สั่งให้ปริ้นต์ลง Console ด้วย และโชว์บนหน้าจอแอปด้วยเลย
            print('🔥 Firebase Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'พังเพราะสาเหตุนี้ครับ:\n${snapshot.error}', 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('ยังไม่มีรายการสนทนา'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final room = docs[index].data() as Map<String, dynamic>;
              final String roomId = docs[index].id;
              
              return ListTile(
                leading: CircleAvatar(backgroundColor: tealColor.withOpacity(0.1), child: Icon(Icons.person, color: tealColor)),
                title: Text('ห้องแชท: ${roomId.substring(0, 8)}...'), // ชั่วคราว: แสดงรหัสห้อง
                subtitle: Text(room['last_message'] ?? 'เริ่มการสนทนาได้เลย'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ChatScreen(roomId: roomId),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}