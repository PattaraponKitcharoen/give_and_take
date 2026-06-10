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
  
  final Color tealColor = const Color(0xFF10B981); // ปรับสี Teal ให้ตรงกับหน้า Register
  final Color bgColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // 🟢 Floating ทำให้ SnackBar ลอยเหนือเนื้อหาปกติ
        behavior: SnackBarBehavior.floating,
        // 🟢 margin คือหัวใจ: ตั้งค่าให้ลอยห่างจากขอบล่าง 100 pixels เพื่อไม่ให้ทับปุ่ม Save
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'user_id': user.uid,
        'email': user.email,
        'name': _nameController.text.trim(),
        'tel': _telController.text.trim(),
        'bio': _bioController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSuccessSnackBar('บันทึกโปรไฟล์เรียบร้อย');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSuccessSnackBar('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 ฟังก์ชันสร้าง TextField ให้ตรงกับสไตล์ในรูป
  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🟢 ส่วนรูปโปรไฟล์
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: tealColor.withOpacity(0.1),
                                  child: Icon(Icons.person, size: 50, color: tealColor),
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: tealColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _nameController.text.isNotEmpty ? _nameController.text : 'ชื่อผู้ใช้งาน',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 🟢 หัวข้อ Section
                    const Text(
                      'PERSONAL INFO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),

                    // 🟢 ฟอร์มกรอกข้อมูล
                    _buildLabeledTextField(
                      label: 'DISPLAY NAME',
                      controller: _nameController,
                      hintText: 'John Doe',
                      icon: Icons.person_outline,
                    ),
                    
                    _buildLabeledTextField(
                      label: 'BIO / ABOUT ME',
                      controller: _bioController,
                      hintText: 'Tell others about yourself or what you like to trade',
                      icon: Icons.info_outline,
                      maxLines: 3,
                    ),

                    _buildLabeledTextField(
                      label: 'PHONE NUMBER',
                      controller: _telController,
                      hintText: '08X-XXX-XXXX',
                      icon: Icons.phone_iphone_outlined,
                    ),
                  ],
                ),
              ),
            ),
            
            // 🟢 ปุ่ม Save ที่ล็อคติดขอบล่างเสมอ
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: bgColor,
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveProfile,
                icon: _isLoading ? const SizedBox() : const Icon(Icons.check, color: Colors.white, size: 20),
                label: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: tealColor.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}