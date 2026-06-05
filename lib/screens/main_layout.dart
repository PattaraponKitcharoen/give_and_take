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

  Widget _buildNavItem(IconData icon, int index, {bool isChat = false}) {
    bool isSelected = _currentIndex == index;
    
    Widget iconWidget = Icon(
      icon,
      color: isSelected ? tealColor : Colors.black54, 
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
      // 🟢 1. ตัด AddPostScreen ออก และขยับ Index ของ Chat กับ Profile ขึ้นมา
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),       // Index 0
          MyListingScreen(),  // Index 1
          ChatListScreen(),   // Index 2 
          ProfileScreen(),    // Index 3 
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 🟢 2. สั่งเปิดหน้า AddPostScreen แบบเด้งทับขึ้นมา (Push)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        backgroundColor: tealColor,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(), 
        notchMargin: 8.0, 
        elevation: 10,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), 
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 0),
            _buildNavItem(Icons.grid_view_rounded, 1),
            const SizedBox(width: 48), // เว้นที่ให้ตรงกลาง
            // 🟢 3. อัปเดต Index เป็น 2 และ 3 ให้ตรงกับ IndexedStack
            _buildNavItem(Icons.chat_bubble_outline, 2, isChat: true), 
            _buildNavItem(Icons.person_outline, 3),
          ],
        ),
      ),
    );
  }
}