import 'package:flutter/material.dart';
import '../models/place_location.dart';
import '../theme/app_theme.dart';

/// "จุดรับของ" row on the post/edit listing forms: the listing's coarse
/// pickup area plus a button that sets it to where the user is now.
class PickupLocationTile extends StatelessWidget {
  final PlaceLocation? location;
  final bool loading;
  final String actionLabel;
  final VoidCallback? onUseCurrent;

  const PickupLocationTile({
    super.key,
    required this.location,
    required this.actionLabel,
    this.onUseCurrent,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = location?.displayName ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    location == null
                        ? 'ยังไม่ได้ระบุจุดรับของ'
                        : (name.isNotEmpty ? name : 'ตำแหน่งปัจจุบัน'),
                    style: AppText.label),
                const SizedBox(height: 2),
                const Text(
                    'คนอื่นจะเห็นเป็นระยะโดยประมาณ (~1 กม.) ไม่เห็นตำแหน่งจริง',
                    style: AppText.caption),
              ],
            ),
          ),
          loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: onUseCurrent,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary),
                  child: Text(actionLabel, textAlign: TextAlign.center),
                ),
        ],
      ),
    );
  }
}
