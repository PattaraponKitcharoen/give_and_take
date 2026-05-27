import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _telController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  final Color tealColor = const Color(0xFF008080);

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลเดิมมาใส่ช่องกรอก (ถ้ามี)
    _nameController = TextEditingController(text: widget.currentData['name'] ?? '');
    _telController = TextEditingController(text: widget.currentData['tel'] ?? '');
    _bioController = TextEditingController(text: widget.currentData['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _telController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ใช้ SetOptions(merge: true) เพื่ออัปเดตเฉพาะฟิลด์ที่ส่งไป 
      // หรือสร้างเอกสารใหม่เลยถ้ายังไม่มีข้อมูลในระบบ
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'user_id': user.uid,
        'email': user.email,
        'name': _nameController.text.trim(),
        'tel': _telController.text.trim(),
        'bio': _bioController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        // ข้อมูลอื่นๆ เช่น coins_balance หรือ rating จะถูกเซ็ตตอน Register
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์เรียบร้อย')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(radius: 50, backgroundColor: tealColor.withOpacity(0.1), child: Icon(Icons.person, size: 50, color: tealColor)),
                  Positioned(
                    bottom: 0, right: 0,
                    child: CircleAvatar(backgroundColor: tealColor, radius: 18, child: const Icon(Icons.camera_alt, size: 18, color: Colors.white)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('ชื่อผู้ใช้งาน', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),

            const Text('เบอร์โทรศัพท์', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),

            const Text('เกี่ยวกับฉัน (Bio)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(hintText: 'แนะนำตัวสั้นๆ ให้คนอื่นรู้จักคุณ', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: tealColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}