import 'package:flutter/material.dart';

class HandoverOtpDialog extends StatelessWidget {
  final Function(String) onSubmit;
  const HandoverOtpDialog({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final TextEditingController otpController = TextEditingController();
    return AlertDialog(
      title: const Text('ยืนยันการรับของ', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
      content: TextField(controller: otpController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(hintText: 'กรอกรหัส 6 หลักของอีกฝ่าย')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () { Navigator.pop(context); onSubmit(otpController.text.trim()); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)), child: const Text('ยืนยัน', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}