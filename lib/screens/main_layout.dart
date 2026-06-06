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
  final Color tealColor = const Color(0xFF008080); 
  final Color inactiveColor = Colors.grey.shade400; 

  Widget _buildNavItem(IconData icon, int index, {bool isChat = false}) {
    bool isSelected = _currentIndex == index;
    
    Widget iconWidget = Icon(
      icon,
      color: isSelected ? tealColor : inactiveColor, 
      size: 28,
    );

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
                color: isSelected ? tealColor : inactiveColor,
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 5 - 10, 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          // 🟢 เปลี่ยนจาก spaceBetween เป็น start เพื่อดันของจากบนลงล่างตามใจเรา
          mainAxisAlignment: MainAxisAlignment.start, 
          children: [
            // 🟢 ขีดด้านบน (บางลง และ ยาวขึ้น)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutQuint,
              height: 2.5, // บางลง
              width: isSelected ? 52 : 0, // ยาวขึ้น (ถ้าอยากให้ยาวกว่านี้ลองปรับเป็น 48-50 ดูครับ)
              decoration: BoxDecoration(
                color: tealColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)), 
              ),
            ),
            const SizedBox(height: 8), // 🟢 เพิ่มช่องว่างดันไอคอนลงมาไม่ให้ชิดเส้นเกินไป
            iconWidget,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),       
          MyListingScreen(),  
          ChatListScreen(),   
          ProfileScreen(),    
        ],
      ),
      
      floatingActionButton: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: Container(
          height: 64, 
          width: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF20C997), Color(0xFF008080)], 
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF008080).withOpacity(0.4), 
                blurRadius: 16, 
                spreadRadius: 2, 
                offset: const Offset(0, 6), 
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
        ),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(), 
        notchMargin: 10.0, 
        elevation: 20, 
        padding: EdgeInsets.zero, 
        // 🟢 ปรับความสูง Nav Bar เป็น 60 ให้มีพื้นที่หายใจ (ถ้าน้อยกว่านี้ไอคอนจะเบียดขอบล่าง)
        height: 45, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            _buildNavItem(Icons.home_rounded, 0),
            _buildNavItem(Icons.grid_view_rounded, 1),
            const SizedBox(width: 48), 
            _buildNavItem(Icons.chat_bubble_outline_rounded, 2, isChat: true), 
            _buildNavItem(Icons.person_outline_rounded, 3),
          ],
        ),
      ),
    );
  }
}