import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/report_repository.dart';
import '../widgets/report_sheet.dart';
import '../repositories/auth_repository.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../repositories/chat_repository.dart';
import '../cubits/chat/chat_cubit.dart';
import '../cubits/offer/offer_cubit.dart';
import '../cubits/offer/offer_state.dart';
import '../cubits/transaction/transaction_cubit.dart';
import '../cubits/transaction/transaction_state.dart';
import '../cubits/review/review_cubit.dart';
import '../cubits/review/review_state.dart';

import '../widgets/system_offer_card.dart';
import '../widgets/counter_offer_dialog.dart';
import '../widgets/handover_otp_dialog.dart';
import '../widgets/rating_review_dialog.dart';
import '../widgets/chat_bubble_widget.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  String get currentUserId =>
      context.read<AuthRepository>().currentUser?.uid ?? '';
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Memoizes the target-item Future by offerId so the outer
  // StreamBuilder<ChatRoomModel?> (which re-fires on every room-doc change,
  // e.g. a read-receipt update) doesn't hand the AppBar's FutureBuilder a
  // brand-new Future — and therefore a redundant Firestore read — on every
  // single rebuild when the offer itself hasn't changed.
  String? _cachedTargetOfferId;
  Future<Map<String, dynamic>>? _cachedTargetItemInfoFuture;

  Future<Map<String, dynamic>> _targetItemInfoFor(String? offerId) {
    if (_cachedTargetOfferId != offerId) {
      _cachedTargetOfferId = offerId;
      _cachedTargetItemInfoFuture = _getTargetItemInfo(offerId);
    }
    return _cachedTargetItemInfoFuture!;
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🟢 DATABASE LOGIC METHODS
  // ==========================================

  Future<void> _markAsRead() async {
    await context.read<ChatCubit>().markAsRead(widget.roomId, currentUserId);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    int hour = date.hour;
    final min = date.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$min $ampm';
  }

  Future<Map<String, dynamic>> _getTargetItemInfo(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return {};
    return await context
        .read<ChatCubit>()
        .getTargetItemInfo(offerId, currentUserId);
  }

  Future<void> _cancelOffer(String offerId) async {
    context
        .read<OfferCubit>()
        .cancelOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _rejectOffer(String offerId) async {
    context
        .read<OfferCubit>()
        .rejectOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _acceptOffer(BuildContext context, String offerId) async {
    context
        .read<OfferCubit>()
        .acceptOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _cancelAcceptedDeal(String offerId, String reason) async {
    context
        .read<TransactionCubit>()
        .cancelAcceptedDeal(offerId, reason, currentUserId, widget.roomId);
  }

  Future<void> _verifyHandoverCode(String offerId, String inputCode) async {
    context
        .read<TransactionCubit>()
        .confirmTransactionByOfferId(offerId, currentUserId, inputCode);
  }

  Future<void> _submitCounterOffer(String offerId,
      Map<String, dynamic> offerData, int amount, bool iWillPay) async {
    context.read<OfferCubit>().submitCounterOffer(
        offerId, offerData, amount, iWillPay, widget.roomId, currentUserId);
  }

  Future<void> _submitReview(String targetUserId, String transactionId,
      int rating, String comment) async {
    context.read<ReviewCubit>().submitReview(
          targetUserId: targetUserId,
          currentUserId: currentUserId,
          transactionId: transactionId,
          rating: rating.toDouble(),
          comment: comment,
        );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    // Guard against an unexpectedly-null/expired auth session — without
    // this, a message would be written with senderId: '' instead of being
    // rejected client-side.
    if (currentUserId.isEmpty) return;
    final String text = _messageController.text.trim();
    _messageController.clear();

    List<String> roomUsers =
        await context.read<ChatCubit>().getRoomMembers(widget.roomId);
    if (mounted) {
      context
          .read<ChatCubit>()
          .sendMessage(widget.roomId, text, currentUserId, roomUsers);
    }
  }

  // ==========================================
  // 🟢 DIALOG TRIGGER METHODS
  // ==========================================

  void _showCounterOfferDialog(
      BuildContext context, String offerId, Map<String, dynamic> offerData) {
    showDialog(
      context: context,
      builder: (context) => CounterOfferDialog(
        offerId: offerId,
        offerData: offerData,
        currentUserId: currentUserId,
        onSubmit: (amount, iWillPay) =>
            _submitCounterOffer(offerId, offerData, amount, iWillPay),
      ),
    );
  }

  void _showOtpDialog(BuildContext context, String offerId) {
    showDialog(
      context: context,
      builder: (context) => HandoverOtpDialog(
        onSubmit: (otpCode) => _verifyHandoverCode(offerId, otpCode),
      ),
    );
  }

  void _showRatingDialog(
      BuildContext context, String targetUserId, String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingReviewDialog(
        onSubmit: (rating, comment) =>
            _submitReview(targetUserId, transactionId, rating, comment),
      ),
    );
  }

  // ==========================================
  // 🟢 CORE UI BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: MultiBlocListener(
        listeners: [
          // Confirming a handover OTP or cancelling an accepted deal never
          // showed any feedback — success or failure — so from the user's
          // side pressing "ยืนยัน" looked like nothing happened, even when it
          // actually succeeded (just waiting on the other party) or failed
          // for a real, specific reason.
          BlocListener<TransactionCubit, TransactionState>(
            listener: (context, state) {
              if (state is TransactionSuccess) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (state is TransactionError) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          // Accept / reject / counter / withdraw on the offer card had no
          // listener at all, so a failed call (permission, insufficient coins,
          // unreachable function) left the user with a button that simply did
          // nothing. Success needs no snackbar — the card itself changes.
          BlocListener<OfferCubit, OfferState>(
            listener: (context, state) {
              if (state is OfferError) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          // Same gap for submitting a rating/review — the dialog closes
          // itself immediately on submit regardless of outcome, so without
          // this, a failed submit (e.g. permission/validation error) looked
          // exactly like a successful one.
          BlocListener<ReviewCubit, ReviewState>(
            listener: (context, state) {
              if (state is ReviewSuccess) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (state is ReviewError) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
        child: StreamBuilder<ChatRoomModel?>(
            stream:
                context.read<ChatRepository>().getChatRoomStream(widget.roomId),
            builder: (context, roomSnap) {
              if (!roomSnap.hasData || roomSnap.data == null)
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));

              final roomData = roomSnap.data!;
              final String? activeOfferId = roomData.activeOfferId;

              Map<String, dynamic> readTimestamps = roomData.readTimestamps;
              Timestamp? otherUserReadTime;
              readTimestamps.forEach((key, value) {
                if (key != currentUserId && value is Timestamp)
                  otherUserReadTime = value;
              });

              final List<String> readBy = roomData.readBy;
              final bool isReadByOther =
                  readBy.any((id) => id != currentUserId);

              return Scaffold(
                appBar: AppBar(
                  shape: const Border(
                      bottom: BorderSide(color: AppColors.hairline)),
                  title: FutureBuilder<Map<String, dynamic>>(
                      future: _targetItemInfoFor(activeOfferId),
                      builder: (context, itemSnap) {
                        if (!itemSnap.hasData || itemSnap.data!.isEmpty) {
                          return const Text('เจรจาแลกเปลี่ยน',
                              style: AppText.subtitle);
                        }
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Container(
                                width: 38,
                                height: 38,
                                color: AppColors.surfaceMuted,
                                child: itemSnap.data!['thumbnail_url'] !=
                                            null &&
                                        itemSnap.data!['thumbnail_url'] != ''
                                    ? Image.network(
                                        itemSnap.data!['thumbnail_url'],
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image,
                                        size: 20, color: AppColors.inkTertiary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      itemSnap.data!['title'] ??
                                          'สิ่งของแลกเปลี่ยน',
                                      style: AppText.label
                                          .copyWith(fontSize: 14.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const Text(
                                      'รายละเอียดเพิ่มเติมกดดูที่ข้อเสนอ',
                                      style: TextStyle(
                                          color: AppColors.inkTertiary,
                                          fontSize: 11)),
                                ],
                              ),
                            )
                          ],
                        );
                      }),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (_) => showReportSheet(context,
                          type: ReportTarget.chat, targetId: widget.roomId),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(children: [
                            Icon(Icons.flag_outlined,
                                color: AppColors.danger, size: 20),
                            SizedBox(width: 10),
                            Text('รายงานแชทนี้'),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: context
                            .read<ChatRepository>()
                            .getMessagesStream(widget.roomId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          final messages = snapshot.data!;

                          int latestReadIndex = -1;
                          if (otherUserReadTime != null) {
                            for (int i = 0; i < messages.length; i++) {
                              var msgData = messages[i];
                              if (msgData.senderId == currentUserId) {
                                Timestamp? msgTime = msgData.timestamp != null
                                    ? Timestamp.fromDate(msgData.timestamp!)
                                    : null;
                                if (msgTime != null &&
                                    msgTime.compareTo(otherUserReadTime!) <=
                                        0) {
                                  latestReadIndex = i;
                                  break;
                                }
                              }
                            }
                          } else if (isReadByOther) {
                            for (int i = 0; i < messages.length; i++) {
                              var msgData = messages[i];
                              if (msgData.senderId == currentUserId) {
                                latestReadIndex = i;
                                break;
                              }
                            }
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              bool isMe = msg.senderId == currentUserId;
                              String type = msg.type;
                              String timeStr = msg.timestamp != null
                                  ? _formatTime(
                                      Timestamp.fromDate(msg.timestamp!))
                                  : '';

                              if (msg.senderId == 'system' &&
                                  type != 'system_offer') {
                                // Kept narrower than the screen and centred,
                                // so long notices wrap into a tidy block
                                // instead of a full-width bar.
                                return Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 28),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 9),
                                    decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        boxShadow: AppShadows.raised,
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.lg)),
                                    child: Text(msg.content,
                                        textAlign: TextAlign.center,
                                        style: AppText.caption.copyWith(
                                            color: AppColors.inkSecondary,
                                            fontWeight: FontWeight.w600,
                                            height: 1.45)),
                                  ),
                                );
                              }

                              if (type == 'system_offer') {
                                return SystemOfferCard(
                                  msg: msg,
                                  activeOfferId: activeOfferId,
                                  currentUserId: currentUserId,
                                  onCancel: () => _cancelOffer(activeOfferId!),
                                  onReject: () => _rejectOffer(activeOfferId!),
                                  onAccept: () =>
                                      _acceptOffer(context, activeOfferId!),
                                  onCounter: (offerData) =>
                                      _showCounterOfferDialog(
                                          context, activeOfferId!, offerData),
                                  onVerifyOtp: () =>
                                      _showOtpDialog(context, activeOfferId!),
                                  onCancelDeal: () => _cancelAcceptedDeal(
                                      activeOfferId!, 'เปลี่ยนใจไม่แลกแล้ว'),
                                  onOpenRating: (partnerId, txId) =>
                                      _showRatingDialog(
                                          context, partnerId, txId),
                                );
                              }

                              bool showTimeByDefault = true;
                              bool showAvatar = true;
                              if (index > 0) {
                                final newerMsg = messages[index - 1];
                                final newerTime = newerMsg.timestamp;
                                final currentTime = msg.timestamp;
                                if (newerMsg.senderId == msg.senderId &&
                                    newerTime != null &&
                                    currentTime != null) {
                                  if (newerTime
                                          .difference(currentTime)
                                          .inMinutes
                                          .abs() <
                                      3) {
                                    showTimeByDefault = false;
                                    showAvatar = false;
                                  }
                                }
                              }

                              return ChatBubbleWidget(
                                msg: msg,
                                isMe: isMe,
                                timeStr: timeStr,
                                showTimeByDefault: showTimeByDefault,
                                showAvatar: showAvatar,
                                isLatestRead: index == latestReadIndex,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                              top: BorderSide(color: AppColors.hairline))),
                      child: SafeArea(
                        bottom: true,
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: AppText.body,
                                decoration: InputDecoration(
                                    hintText: 'พิมพ์ข้อความ...',
                                    filled: true,
                                    fillColor: AppColors.surfaceMuted,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.pill),
                                        borderSide: const BorderSide(
                                            color: AppColors.hairline)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppGradients.primary,
                                  boxShadow: AppShadows.glow(AppColors.primary),
                                ),
                                child: const Icon(Icons.arrow_upward_rounded,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
      ),
    );
  }
}
