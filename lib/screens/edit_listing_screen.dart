import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditListingScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const EditListingScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _coinsController;
  bool _isLoading = false;
  final Color tealColor = const Color(0xFF008080);

  @override
  void initState() {
    super.initState();
    // 🟢 ถมข้อมูลเดิมลงไปในช่องกรอกข้อความทันทีที่เปิดหน้าต่าง
    _titleController = TextEditingController(text: widget.itemData['title']);
    _descController = TextEditingController(text: widget.itemData['description']);
    _coinsController = TextEditingController(text: (widget.itemData['estimated_coins'] ?? 0).toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _updateListing() async {
    setState(() => _isLoading = true);
    try {
      // 🟢 อัปเดตข้อมูลลงฐานข้อมูล
      await FirebaseFirestore.instance.collection('listings').doc(widget.itemId).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'estimated_coins': int.tryParse(_coinsController.text.trim()) ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')));
        Navigator.pop(context); // กลับไปหน้า My Listing
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
        title: const Text('แก้ไขสิ่งของ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ในอนาคตสามารถเพิ่มส่วนจัดการรูปภาพตรงนี้ได้
            
            const Text('ชื่อสิ่งของ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            const Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            const Text('ราคาประเมิน (Coins)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}