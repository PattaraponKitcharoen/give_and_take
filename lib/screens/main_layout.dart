import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_listings_screen.dart';
import 'add_post_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0; // ตัวแปรเก็บว่าตอนนี้อยู่แท็บไหน

  // รายการหน้าจอทั้ง 5 หน้า
  final List<Widget> _screens = [
    const HomeScreen(),
    const MyListingsScreen(),
    const AddPostScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack ช่วยจำสถานะของหน้าจอไว้ ไม่ให้โหลดใหม่ทุกครั้งที่เปลี่ยนแท็บ
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // เปลี่ยนแท็บตามที่ผู้ใช้กด
          });
        },
        type: BottomNavigationBarType.fixed, // บังคับให้โชว์ไอคอนครบทุกตัว
        selectedItemColor: const Color(0xFF008080), // สี Deep Teal
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'My Listing'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}