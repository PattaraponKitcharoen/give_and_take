import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui/dialog_header.dart';

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
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const DialogHeader(
          icon: Icons.star_rounded,
          title: 'ให้คะแนนการแลกเปลี่ยน',
          color: AppColors.gold),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ความประทับใจต่อคู่กรณีในดีลนี้',
              style: AppText.bodySecondary),
          const SizedBox(height: 16),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (idx) => IconButton(
                      icon: Icon(
                          idx < selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.gold,
                          size: 38),
                      onPressed: () =>
                          setState(() => selectedRating = idx + 1)))),
          const SizedBox(height: 16),
          TextField(
              controller: commentController,
              maxLines: 3,
              style: AppText.body,
              decoration: const InputDecoration(
                  hintText: 'เขียนรีวิวสั้นๆ (ไม่บังคับ)...',
                  fillColor: AppColors.surfaceMuted)),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ข้าม')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSubmit(
                      selectedRating, commentController.text.trim());
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('ยืนยัน')),
          ),
        ]),
      ],
    );
  }
}
