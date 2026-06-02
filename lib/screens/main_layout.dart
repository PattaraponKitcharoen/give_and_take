import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'my_listing_screen.dart';
import 'add_post_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final Color tealColor = const Color(0xFF008080); // สี Deep Teal

  // 🟢 อัปเดตฟังก์ชันช่วยสร้างปุ่ม ให้รองรับการวาดจุดแดงเฉพาะปุ่มแชท
  Widget _buildNavItem(IconData icon, int index, {bool isChat = false}) {
    bool isSelected = _currentIndex == index;
    
    // สร้างตัวไอคอนปกติ
    Widget iconWidget = Icon(
      icon,
      color: isSelected ? tealColor : Colors.black54, // ถ้าเลือกอยู่ให้เป็นสี Teal ถ้าไม่เลือกเป็นสีเทาเข้ม
      size: 28,
    );

    // 🟢 ถ้าบอกว่าเป็นปุ่มแชท (isChat = true) ให้เอา StreamBuilder มาครอบเพื่อโชว์จุดแดง
    if (isChat) {
      iconWidget = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid ?? '')
            .snapshots(),
        builder: (context, snapshot) {
          bool hasUnreadChat = false;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (snapshot.hasData && currentUserId != null) {
            for (var doc in snapshot.data!.docs) {
              final room = doc.data() as Map<String, dynamic>;
              final List readBy = room['read_by'] ?? [];
              final String? lastMessage = room['last_message_text'];

              if (lastMessage != null && !readBy.contains(currentUserId)) {
                hasUnreadChat = true;
                break;
              }
            }
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected ? tealColor : Colors.black54,
                size: 28,
              ),
              if (hasUnreadChat)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return IconButton(
      icon: iconWidget,
      onPressed: () {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack ยังคงทำหน้าที่เก็บหน้าจอทั้ง 5 ไว้เหมือนเดิม
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),       // Index 0
          MyListingScreen(), // Index 1
          AddPostScreen(),    // Index 2 (หน้าของปุ่ม +)
          ChatListScreen(),   // Index 3
          ProfileScreen(),    // Index 4
        ],
      ),
      
      // 1. สร้างปุ่มลอย (Floating Action Button)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _currentIndex = 2; // เมื่อกดปุ่ม + ให้สลับไปหน้า AddPostScreen
          });
        },
        backgroundColor: tealColor,
        shape: const CircleBorder(), // บังคับให้เป็นวงกลม
        elevation: 4, // เพิ่มเงาให้ดูมีมิติ
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      
      // 2. จับปุ่มลอยไปยึดไว้ตรงกลางของขอบล่าง
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // 3. สร้างแถบด้านล่าง (BottomAppBar) มารองรับ
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(), // ทำให้มีรอยแหว่งเว้าหลบปุ่มกลมๆ
        notchMargin: 8.0, // ระยะห่างระหว่างปุ่มกลมกับรอยแหว่ง
        elevation: 10,
        // 🟢 1. ล้าง Padding อัตโนมัติ และเว้นบน-ล่างนิดหน่อยไม่ให้ไอคอนเบียดขอบ
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), 
        // 🟢 2. บีบความสูงลงมา (ลองปรับเลข 60-65 ดูได้จนกว่าจะพอใจครับ)
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 0),
            _buildNavItem(Icons.grid_view_rounded, 1),
            const SizedBox(width: 48),
            // 🟢 ใส่ isChat: true ตรงนี้เพื่อบอกว่านี่คือปุ่มที่ต้องมีจุดแดง
            _buildNavItem(Icons.chat_bubble_outline, 3, isChat: true), 
            _buildNavItem(Icons.person_outline, 4),
          ],
        ),
      ),
    );
  }
}