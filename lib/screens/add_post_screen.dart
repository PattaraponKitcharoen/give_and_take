import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);

  // Controllers สำหรับรับข้อความ
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController(); // 🟢 เพิ่มช่องรายละเอียด
  final _coinsController = TextEditingController();
  
  String _selectedCategory = 'Home Goods';
  final List<String> _categories = ['Skills', 'Home Goods', 'Books', 'Gadgets', 'Fashion'];

  // 🟢 เพิ่มตัวเลือกสภาพสินค้า (นำไปใส่ใน metadata)
  String _selectedCondition = 'มือสอง สภาพดี';
  final List<String> _conditions = ['ของใหม่', 'มือสอง สภาพเหมือนใหม่', 'มือสอง สภาพดี', 'มือสอง มีตำหนิ'];

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final coinsText = _coinsController.text.trim();

    if (title.isEmpty || description.isEmpty || coinsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
        ),
      );
      return;
    }

    final int? coins = int.tryParse(coinsText);
    if (coins == null || coins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกราคาประเมินเป็นตัวเลข'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
        ),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 🟢 จัดโครงสร้างข้อมูลให้เป๊ะตาม Database Schema ที่ออกแบบไว้
      await FirebaseFirestore.instance.collection('listings').add({
        'owner_id': user.uid,
        'type': 'item',
        'title': title,
        'description': description, // เพิ่ม description
        'category': _selectedCategory,
        'estimated_coins': coins,
        'thumbnail_url': '', // เผื่อไว้ก่อนสำหรับระบบอัปโหลดรูป
        'images': [], // เผื่อไว้สำหรับแกลลอรี่รูปภาพ
        'location': {
          'province': 'สงขลา', // ค่าเริ่มต้นสำหรับ MVP
          'lat': 7.0086, // พิกัดจำลอง หาดใหญ่
          'lng': 100.4746,
        },
        'metadata': {
          'condition': _selectedCondition, // เก็บสภาพของลงใน map metadata
        },
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(), // เผื่อไว้สำหรับตอนแก้ไขโพสต์
        'is_deleted': false, // ฟิลด์สำหรับทำ Soft Delete
      });

      if (mounted) {
        _titleController.clear();
        _descriptionController.clear();
        _coinsController.clear();
        setState(() {
          _selectedCategory = 'Home Goods';
          _selectedCondition = 'มือสอง สภาพดี';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โพสต์สิ่งของสำเร็จ!'),
            backgroundColor: Color(0xFF008080),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด ไม่สามารถโพสต์ได้'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ฟังก์ชันช่วยสร้างกล่อง Dropdown ให้โค้ดคลีนขึ้น
  Widget _buildDropdown({required String title, required String value, required List<String> items, required Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: tealColor),
              items: items.map((String item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('เพิ่มสิ่งของใหม่', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('เพิ่มรูปภาพ (ระบบอยู่ในช่วงพัฒนา)', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('ชื่อสิ่งของ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'เช่น คีย์บอร์ดแมคคานิคอล',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // 🟢 เพิ่มช่องกรอกรายละเอียด
            const Text('รายละเอียดเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4, // ให้กล่องสูงขึ้น พิมพ์ได้หลายบรรทัด
              decoration: InputDecoration(
                hintText: 'บอกรายละเอียด, ตำหนิ, หรือเหตุผลที่อยากแลก...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // หมวดหมู่
            _buildDropdown(
              title: 'หมวดหมู่',
              value: _selectedCategory,
              items: _categories,
              onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
            ),
            const SizedBox(height: 20),

            // 🟢 สภาพสิ่งของ (เก็บเข้า metadata)
            _buildDropdown(
              title: 'สภาพสิ่งของ',
              value: _selectedCondition,
              items: _conditions,
              onChanged: (newValue) => setState(() => _selectedCondition = newValue!),
            ),
            const SizedBox(height: 20),

            const Text('ราคาประเมิน (Coins)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'เช่น 500',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: tealColor),
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('โพสต์สิ่งของ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 80), // ดันให้พ้น Bottom Navigation
          ],
        ),
      ),
    );
  }
}