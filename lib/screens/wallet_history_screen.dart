import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/wallet_history/wallet_history_cubit.dart';
import '../cubits/wallet_history/wallet_history_state.dart';
import '../models/wallet_entry.dart';
import '../repositories/auth_repository.dart';
import '../repositories/wallet_repository.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthRepository>().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการโอนเหรียญ'),
        centerTitle: true,
      ),
      body: currentUserId == null
          ? const Center(child: Text('กรุณาล็อกอิน'))
          : BlocProvider(
              create: (context) => WalletHistoryCubit(
                walletRepository: context.read<WalletRepository>(),
                userId: currentUserId,
              ),
              child: BlocBuilder<WalletHistoryCubit, WalletHistoryState>(
                builder: (context, state) {
                  if (state is WalletHistoryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // แจ้ง Error เผื่อลืมทำ Index ใน Firebase
                  if (state is WalletHistoryError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SelectableText(
                            'เกิดข้อผิดพลาด (อย่าลืมทำ Index): ${state.message}',
                            style: const TextStyle(color: AppColors.danger)),
                      ),
                    );
                  }

                  final entries = (state as WalletHistoryLoaded).entries;
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('ยังไม่มีประวัติการทำธุรกรรม',
                          style: TextStyle(
                              color: AppColors.inkTertiary, fontSize: 16)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.page, 8, AppSpace.page, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _WalletEntryCard(entry: entries[index]),
                  );
                },
              ),
            ),
    );
  }
}

class _WalletEntryCard extends StatelessWidget {
  final WalletEntry entry;
  const _WalletEntryCard({required this.entry});

  String get _typeLabel => switch (entry.type) {
        'escrow_lock' => 'กันเหรียญเข้ากองกลาง',
        'escrow_release' => 'ได้รับเหรียญ',
        'refund' => 'คืนเหรียญ',
        _ => 'รายการเหรียญ',
      };

  @override
  Widget build(BuildContext context) {
    final amount = entry.amount;
    final deal = entry.deal;

    // 🟢 จัดการรูปแบบเวลา
    String timeText = '';
    final date = entry.createdAt;
    if (date != null) {
      timeText =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // 🟢 เช็คว่าเงินเข้าหรือเงินออก เพื่อกำหนดสี
    final bool isPositive = amount > 0;
    final Color amountColor = isPositive ? AppColors.success : AppColors.danger;
    final String amountPrefix = isPositive ? '+' : '';
    final roomId = deal?.roomId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.raised,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Opens the deal's chat, where the offer card shows the full deal.
          onTap: roomId == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ChatScreen(roomId: roomId))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.of(amountColor),
                        boxShadow: AppShadows.glow(amountColor),
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_typeLabel,
                              style: AppText.label.copyWith(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(entry.description,
                              style: AppText.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$amountPrefix$amount', // โชว์เช่น +50 หรือ -100
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(timeText,
                            style: AppText.caption.copyWith(
                                color: AppColors.inkTertiary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                if (deal != null) ...[
                  const SizedBox(height: 12),
                  _buildDeal(deal, roomId != null),
                ] else if (entry.referenceId.isNotEmpty &&
                    !entry.dealLoaded) ...[
                  const SizedBox(height: 12),
                  Text('กำลังโหลดข้อมูลดีล…',
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeal(WalletDeal deal, bool canOpen) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 44,
              height: 44,
              color: AppColors.hairline,
              child: deal.theirItemThumbnail.isNotEmpty
                  ? Image.network(deal.theirItemThumbnail, fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined,
                      color: AppColors.inkTertiary, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: deal.myItemTitle),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.swap_horiz_rounded,
                            size: 14, color: AppColors.primary),
                      ),
                    ),
                    TextSpan(text: deal.theirItemTitle),
                  ]),
                  style: AppText.label.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('แลกกับ ${deal.partnerName}',
                    style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          if (canOpen)
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.inkTertiary),
        ],
      ),
    );
  }
}
