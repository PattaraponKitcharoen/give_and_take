import 'package:flutter/material.dart';

class RatingReviewDialog extends StatefulWidget {
  final Function(int, String) onSubmit;
  const RatingReviewDialog({super.key, required this.onSubmit});

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  int selectedRating = 5;
  final TextEditingController commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ให้คะแนนการแลกเปลี่ยน', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ความประทับใจต่อคู่กรณีในดีลนี้', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (idx) => IconButton(icon: Icon(idx < selectedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36), onPressed: () => setState(() => selectedRating = idx + 1)))),
          const SizedBox(height: 16),
          TextField(controller: commentController, maxLines: 3, decoration: InputDecoration(hintText: 'เขียนรีวิวสั้นๆ (ไม่บังคับ)...', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ข้าม', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () { Navigator.pop(context); widget.onSubmit(selectedRating, commentController.text.trim()); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('ยืนยัน', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}