import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC); 

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coinsController = TextEditingController();
  
  String _selectedCategory = 'Home Goods';
  final List<String> _categories = ['Skills', 'Home Goods', 'Books', 'Gadgets', 'Fashion'];

  // 🟢 เปลี่ยนตัวเลือกเป็นภาษาอังกฤษ
  String _selectedCondition = 'Good';
  final List<String> _conditions = ['Brand New', 'Like New', 'Good', 'Fair'];

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
        SnackBar(
          content: const Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final int? coins = int.tryParse(coinsText);
    if (coins == null || coins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกราคาประเมินเป็นตัวเลข'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('listings').add({
        'owner_id': user.uid,
        'type': 'item',
        'title': title,
        'description': description,
        'category': _selectedCategory,
        'estimated_coins': coins,
        'thumbnail_url': '', 
        'images': [], 
        'location': {
          'province': 'สงขลา', 
          'lat': 7.0086, 
          'lng': 100.4746,
        },
        'metadata': {
          'condition': _selectedCondition, 
        },
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(), 
        'is_deleted': false, 
      });

      if (mounted) {
        _titleController.clear();
        _descriptionController.clear();
        _coinsController.clear();
        setState(() {
          _selectedCategory = 'Home Goods';
          _selectedCondition = 'Good';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('โพสต์สิ่งของสำเร็จ!'),
            backgroundColor: primaryTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // กลับไปหน้าก่อนหน้าหลังจากโพสต์เสร็จ
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('เกิดข้อผิดพลาด ไม่สามารถโพสต์ได้'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryTeal, width: 1.5),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Colors.blueGrey.shade800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text('Add Item', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        // 🟢 เอาปุ่ม Draft ตรงนี้ออกไปแล้ว
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Photos'),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: primaryTeal.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryTeal.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt, color: primaryTeal, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text('Cover Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 4),
                  // 🟢 เปลี่ยนคำอธิบายเป็นภาษาไทย
                  Text('แตะเพื่ออัปโหลดหรือถ่ายรูป', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.photo_library_outlined, size: 16, color: Colors.grey.shade700),
                        label: Text('Gallery', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.camera_alt_outlined, size: 16, color: Colors.grey.shade700),
                        label: Text('Camera', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text('อัปโหลดได้สูงสุด 6 รูป · รูปแรกจะเป็นรูปหน้าปก', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),

            _buildSectionTitle('Item Details'),
            TextField(
              controller: _titleController,
              decoration: _buildInputDecoration('ชื่อสิ่งของ', Icons.edit_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _buildInputDecoration('อธิบายสิ่งของของคุณ เช่น แบรนด์, อายุการใช้งาน, ตำหนิ...', Icons.description_outlined),
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
                  items: _categories.map((String item) {
                    return DropdownMenuItem(value: item, child: Row(
                      children: [
                        Icon(Icons.category_outlined, color: Colors.grey.shade400, size: 20),
                        const SizedBox(width: 12),
                        Text(item, style: const TextStyle(fontSize: 14)),
                      ],
                    ));
                  }).toList(),
                  onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
                ),
              ),
            ),

            _buildSectionTitle('Condition'),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _conditions.map((condition) {
                bool isSelected = _selectedCondition == condition;
                return ChoiceChip(
                  label: Text(condition),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCondition = condition);
                  },
                  selectedColor: primaryTeal,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  showCheckmark: false,
                  avatar: isSelected ? const Icon(Icons.check_circle, color: Colors.white, size: 16) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? primaryTeal : Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryTeal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การระบุสภาพตามจริงจะช่วยให้การแลกเปลี่ยนเป็นไปอย่างราบรื่น',
                      style: TextStyle(color: primaryTeal, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionTitle('Estimated Value'),
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'ราคาประเมิน (Coins)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.grey.shade400, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryTeal, width: 1.5),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text('ช่วยให้ผู้อื่นคำนวณการใช้เหรียญเพื่อชดเชยส่วนต่างได้', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),

            const SizedBox(height: 40), // เผื่อพื้นที่ว่างด้านล่างให้กดง่ายๆ
          ],
        ),
      ),
      // 🟢 ย้ายปุ่ม Post Item มายึดติดไว้ด้านล่างของจอแบบ Bottom Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryTeal.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitPost,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, color: Colors.white, size: 18),
              label: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Post Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}