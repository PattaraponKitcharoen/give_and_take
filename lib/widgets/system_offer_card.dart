import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/transaction/transaction_cubit.dart';
import '../cubits/transaction/transaction_state.dart';
import '../repositories/offer_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/listing_model.dart';
import '../models/message_model.dart';
import '../models/offer_model.dart';
import '../models/review_model.dart';
import '../screens/item_detail_screen.dart';
import '../theme/app_theme.dart';
import 'ui/primary_button.dart';

class SystemOfferCard extends StatelessWidget {
  final MessageModel msg;
  final String? activeOfferId;
  final String currentUserId;
  final VoidCallback onCancel;
  final VoidCallback onReject;
  final VoidCallback onAccept;
  final Function(Map<String, dynamic>) onCounter;
  final VoidCallback onVerifyOtp;
  final VoidCallback onCancelDeal;
  final Function(String, String) onOpenRating;
  final bool isSubmitting;

  const SystemOfferCard({
    super.key,
    required this.msg,
    required this.activeOfferId,
    required this.currentUserId,
    required this.onCancel,
    required this.onReject,
    required this.onAccept,
    required this.onCounter,
    required this.onVerifyOtp,
    required this.onCancelDeal,
    required this.onOpenRating,
    this.isSubmitting = false,
  });

  Widget _buildItemThumbnail(BuildContext context, ListingModel? item) {
    if (item == null) return const SizedBox(width: 80, height: 100);
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ItemDetailScreen(listing: item)));
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: AppShadows.raised),
            child: (item.thumbnailUrl != '')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md - 2),
                    child: Image.network(item.thumbnailUrl, fit: BoxFit.cover))
                : const Icon(Icons.image,
                    color: AppColors.inkTertiary, size: 30),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(item.title,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offerData = msg.offerData;
    final targetItem = offerData?.targetItem;
    final offeredItem = offerData?.offeredItem;

    bool isSender = (msg.senderId == currentUserId);
    var myItemData = isSender ? offeredItem : targetItem;
    var theirItemData = isSender ? targetItem : offeredItem;

    if (activeOfferId == null || activeOfferId!.isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<OfferModel>(
      stream: context.read<OfferRepository>().getOfferStream(activeOfferId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator()));
        }

        OfferModel? currentOffer = snapshot.data;
        String offerStatus = currentOffer?.status ?? 'pending';
        String lastOfferBy =
            currentOffer?.lastOfferBy ?? currentOffer?.senderId ?? '';
        bool isMyTurn = (lastOfferBy != currentUserId);
        int currentOffset = currentOffer?.coinOffset ?? 0;

        String offsetText = 'แลกของต่อของ (ไม่มีการเพิ่มเหรียญ)';
        Color offsetColor = AppColors.inkSecondary;

        if (currentOffset > 0) {
          bool iAmSender = (currentUserId == currentOffer?.senderId);
          offsetText = iAmSender
              ? 'คุณเสนอจ่ายเพิ่ม $currentOffset Coins'
              : 'อีกฝ่ายเสนอจ่ายเพิ่ม $currentOffset Coins';
          offsetColor = iAmSender ? AppColors.danger : AppColors.success;
        } else if (currentOffset < 0) {
          bool iAmSender = (currentUserId == currentOffer?.senderId);
          offsetText = iAmSender
              ? 'คุณขอรับเงินเพิ่ม ${currentOffset.abs()} Coins'
              : 'อีกฝ่ายขอรับเงินเพิ่ม ${currentOffset.abs()} Coins';
          offsetColor = iAmSender ? AppColors.success : AppColors.danger;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.primary.withOpacity(0.18)),
            boxShadow: AppShadows.lifted,
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('ข้อเสนอแลกเปลี่ยน',
                    style:
                        AppText.label.copyWith(color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildItemThumbnail(context, theirItemData),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.primary,
                      boxShadow: AppShadows.glow(AppColors.primary),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Colors.white, size: 22),
                  ),
                  _buildItemThumbnail(context, myItemData),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.toll_rounded, color: offsetColor, size: 16),
                    const SizedBox(width: 8),
                    Text(offsetText,
                        style: AppText.label.copyWith(color: offsetColor))
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (offerStatus == 'pending') ...[
                if (!isMyTurn)
                  Column(children: [
                    const Text('รออีกฝ่ายพิจารณาข้อเสนอ...',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side:
                                    const BorderSide(color: AppColors.danger)),
                            child: const Text('ยกเลิกข้อเสนอ'))),
                  ])
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: onReject,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(
                                          color: AppColors.danger)),
                                  child: const Text('ปฏิเสธ'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: PrimaryButton(
                                  onPressed: () {
                                    if (currentOffer != null) {
                                      onCounter(currentOffer.toJson());
                                    }
                                  },
                                  color: AppColors.warning,
                                  height: 48,
                                  child: const Text('ต่อรอง'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                              onPressed: onAccept,
                              isLoading: isSubmitting,
                              child: const Text('ยอมรับข้อเสนอ'))),
                    ],
                  )
              ] else if (offerStatus == 'accepted' ||
                  offerStatus == 'in_progress') ...[
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('ตกลงแลกเปลี่ยนแล้ว',
                        style:
                            AppText.label.copyWith(color: AppColors.success))),
                _dealProvider(BlocBuilder<TransactionCubit, TransactionState>(
                    builder: (context, txState) {
                  if (txState is TransactionInitial ||
                      txState is TransactionLoading) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator()));
                  }
                  if (txState is TransactionLoaded) {
                    var codes = txState.currentTransaction.verificationCodes;
                    String myCode = codes[currentUserId] ?? '------';
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                            child: Column(children: [
                              Text('รหัสของคุณ (ให้อีกฝ่ายกรอก)',
                                  style: AppText.caption
                                      .copyWith(color: AppColors.primaryDark)),
                              const SizedBox(height: 4),
                              Text(myCode,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 8,
                                      color: AppColors.primaryDark))
                            ])),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                                onPressed: onVerifyOtp,
                                child: const Text('กรอกรหัสของอีกฝ่าย'))),
                        const SizedBox(height: 8),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: onCancelDeal,
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(
                                        color: AppColors.danger)),
                                child: const Text('ยกเลิกดีลนี้'))),
                      ],
                    );
                  }
                  if (txState is TransactionError) {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        const Text('ไม่สามารถโหลดข้อมูลการแลกเปลี่ยนได้',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (activeOfferId != null &&
                                  activeOfferId!.isNotEmpty) {
                                context
                                    .read<TransactionCubit>()
                                    .listenToTransactionByOfferId(
                                        activeOfferId!, currentUserId);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side:
                                    const BorderSide(color: AppColors.primary)),
                            child: const Text('ลองอีกครั้ง'),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                }))
              ] else ...[
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: offerStatus == 'completed'
                            ? AppColors.successSoft
                            : (offerStatus == 'rejected'
                                ? AppColors.warningSoft
                                : AppColors.dangerSoft),
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(
                        offerStatus == 'completed'
                            ? 'แลกเปลี่ยนสำเร็จสมบูรณ์'
                            : (offerStatus == 'rejected'
                                ? 'ถูกปฏิเสธ'
                                : 'ถูกยกเลิกแล้ว'),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: offerStatus == 'completed'
                                ? AppColors.success
                                : (offerStatus == 'rejected'
                                    ? AppColors.warning
                                    : AppColors.danger)))),
                if (offerStatus == 'completed') ...[
                  _dealProvider(BlocBuilder<TransactionCubit, TransactionState>(
                      builder: (context, txState) {
                    if (txState is TransactionInitial ||
                        txState is TransactionLoading) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator()));
                    }
                    if (txState is TransactionLoaded) {
                      final tx = txState.currentTransaction;
                      String transactionId = tx.transactionId;
                      String partnerId = tx.members.firstWhere(
                          (id) => id != currentUserId,
                          orElse: () => '');

                      return StreamBuilder<List<ReviewModel>>(
                        // The button has no way to know a review was already
                        // sent otherwise — without this it just keeps
                        // showing "จัดการคะแนน/รีวิว" forever, even right
                        // after a successful submit, since nothing here ever
                        // re-checked that state.
                        stream: context
                            .read<ReviewRepository>()
                            .getReviewsForTransaction(
                                transactionId, currentUserId),
                        builder: (context, reviewSnap) {
                          final alreadyReviewed =
                              (reviewSnap.data ?? []).isNotEmpty;
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              if (alreadyReviewed)
                                Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md)),
                                  child: const Center(
                                      child: Text('คุณได้รีวิวดีลนี้แล้ว',
                                          style: TextStyle(
                                              color: AppColors.inkSecondary,
                                              fontWeight: FontWeight.w600))),
                                )
                              else
                                SizedBox(
                                    width: double.infinity,
                                    child: PrimaryButton(
                                        onPressed: () => onOpenRating(
                                            partnerId, transactionId),
                                        icon: Icons.star_rounded,
                                        color: AppColors.gold,
                                        child:
                                            const Text('จัดการคะแนน/รีวิว'))),
                            ],
                          );
                        },
                      );
                    }
                    return const SizedBox();
                  }))
                ]
              ]
            ],
          ),
        );
      },
    );
  }

  // Each card watches its own deal through its own cubit. It used to share
  // the app-wide TransactionCubit, which holds one deal at a time and is
  // also where confirm/cancel report their result: two deal cards in the
  // same chat kept stealing the subscription from each other (and could
  // show the other deal's OTP), and a failed action or a listener error
  // left from an earlier deal or account showed up here as "ไม่สามารถโหลด
  // ข้อมูลการแลกเปลี่ยนได้". Actions still go through the app-wide cubit
  // (ChatScreen shows their snackbars); this one only displays.
  Widget _dealProvider(Widget child) {
    return BlocProvider<TransactionCubit>(
      key: ValueKey('deal-$activeOfferId'),
      create: (context) =>
          TransactionCubit(repository: context.read<TransactionRepository>())
            ..listenToTransactionByOfferId(activeOfferId!, currentUserId),
      child: child,
    );
  }
}
