import 'package:flutter/material.dart';
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

  // ฟังก์ชันช่วยสร้างปุ่มไอคอน เพื่อให้โค้ดดูสะอาดตา
  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? tealColor : Colors.black54, // ถ้าเลือกอยู่ให้เป็นสี Teal ถ้าไม่เลือกเป็นสีเทาเข้ม
        size: 28,
      ),
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
            _buildNavItem(Icons.chat_bubble_outline, 3),
            _buildNavItem(Icons.person_outline, 4),
          ],
        ),
      ),
    );
  }
}