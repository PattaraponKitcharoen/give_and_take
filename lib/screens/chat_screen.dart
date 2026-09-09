import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../repositories/chat_repository.dart';
import '../cubits/chat/chat_cubit.dart';
import '../cubits/offer/offer_cubit.dart';
import '../cubits/transaction/transaction_cubit.dart';
import '../cubits/review/review_cubit.dart';

import '../widgets/system_offer_card.dart';
import '../widgets/counter_offer_dialog.dart';
import '../widgets/handover_otp_dialog.dart';
import '../widgets/rating_review_dialog.dart';
import '../widgets/chat_bubble_widget.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  String get currentUserId => context.read<AuthRepository>().currentUser?.uid ?? '';
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
    return await context.read<ChatCubit>().getTargetItemInfo(offerId, currentUserId);
  }

  Future<void> _cancelOffer(String offerId) async {
    context.read<OfferCubit>().cancelOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _rejectOffer(String offerId) async {
    context.read<OfferCubit>().rejectOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _acceptOffer(BuildContext context, String offerId) async {
    context.read<OfferCubit>().acceptOffer(offerId, widget.roomId, currentUserId);
  }

  Future<void> _cancelAcceptedDeal(String offerId, String reason) async {
    context.read<TransactionCubit>().cancelAcceptedDeal(offerId, reason, currentUserId, widget.roomId);
  }

  Future<void> _verifyHandoverCode(String offerId, String inputCode) async {
    context.read<TransactionCubit>().confirmTransactionByOfferId(offerId, currentUserId, inputCode);
  }

  Future<void> _submitCounterOffer(String offerId, Map<String, dynamic> offerData, int amount, bool iWillPay) async {
    context.read<OfferCubit>().submitCounterOffer(offerId, offerData, amount, iWillPay, widget.roomId, currentUserId);
  }

  Future<void> _submitReview(String targetUserId, String transactionId, int rating, String comment) async {
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
    final String text = _messageController.text.trim();
    _messageController.clear();

    List<String> roomUsers = await context.read<ChatCubit>().getRoomMembers(widget.roomId);
    if (mounted) {
      context.read<ChatCubit>().sendMessage(widget.roomId, text, currentUserId, roomUsers);
    }
  }

  // ==========================================
  // 🟢 DIALOG TRIGGER METHODS
  // ==========================================

  void _showCounterOfferDialog(BuildContext context, String offerId, Map<String, dynamic> offerData) {
    showDialog(
      context: context,
      builder: (context) => CounterOfferDialog(
        offerId: offerId,
        offerData: offerData,
        currentUserId: currentUserId,
        onSubmit: (amount, iWillPay) => _submitCounterOffer(offerId, offerData, amount, iWillPay),
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

  void _showRatingDialog(BuildContext context, String targetUserId, String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => RatingReviewDialog(
        onSubmit: (rating, comment) => _submitReview(targetUserId, transactionId, rating, comment),
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
      child: StreamBuilder<ChatRoomModel?>(
        stream: context.read<ChatRepository>().getChatRoomStream(widget.roomId),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData || roomSnap.data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          
          final roomData = roomSnap.data!;
          final String? activeOfferId = roomData.activeOfferId;

          Map<String, dynamic> readTimestamps = roomData.readTimestamps;
          Timestamp? otherUserReadTime;
          readTimestamps.forEach((key, value) {
            if (key != currentUserId && value is Timestamp) otherUserReadTime = value;
          });
          
          final List<String> readBy = roomData.readBy;
          final bool isReadByOther = readBy.any((id) => id != currentUserId);

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white, elevation: 0.5,
              iconTheme: const IconThemeData(color: Colors.black87),
              title: FutureBuilder<Map<String, dynamic>>(
                future: _getTargetItemInfo(activeOfferId),
                builder: (context, itemSnap) {
                  if (!itemSnap.hasData || itemSnap.data!.isEmpty) {
                    return const Text('เจรจาแลกเปลี่ยน', style: TextStyle(color: Colors.black87, fontSize: 16));
                  }
                  return Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36, height: 36, color: Colors.grey.shade100,
                          child: itemSnap.data!['thumbnail_url'] != null && itemSnap.data!['thumbnail_url'] != ''
                              ? Image.network(itemSnap.data!['thumbnail_url'], fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 20, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemSnap.data!['title'] ?? 'สิ่งของแลกเปลี่ยน', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Text('รายละเอียดเพิ่มเติมกดดูที่ข้อเสนอ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      )
                    ],
                  );
                }
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: context.read<ChatRepository>().getMessagesStream(widget.roomId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final messages = snapshot.data!;

                      int latestReadIndex = -1;
                      if (otherUserReadTime != null) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i];
                          if (msgData.senderId == currentUserId) {
                            Timestamp? msgTime = msgData.timestamp != null ? Timestamp.fromDate(msgData.timestamp!) : null;
                            if (msgTime != null && msgTime.compareTo(otherUserReadTime!) <= 0) { latestReadIndex = i; break; }
                          }
                        }
                      } else if (isReadByOther) {
                        for (int i = 0; i < messages.length; i++) {
                          var msgData = messages[i];
                          if (msgData.senderId == currentUserId) { latestReadIndex = i; break; }
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        reverse: true, itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          bool isMe = msg.senderId == currentUserId;
                          String type = msg.type;
                          String timeStr = msg.timestamp != null ? _formatTime(Timestamp.fromDate(msg.timestamp!)) : '';

                          if (msg.senderId == 'system' && type != 'system_offer') {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                child: Text(msg.content, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
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
                              onAccept: () => _acceptOffer(context, activeOfferId!),
                              onCounter: (offerData) => _showCounterOfferDialog(context, activeOfferId!, offerData),
                              onVerifyOtp: () => _showOtpDialog(context, activeOfferId!),
                              onCancelDeal: () => _cancelAcceptedDeal(activeOfferId!, 'เปลี่ยนใจไม่แลกแล้ว'),
                              onOpenRating: (partnerId, txId) => _showRatingDialog(context, partnerId, txId),
                            );
                          }

                          bool showTimeByDefault = true; bool showAvatar = true;
                          if (index > 0) { 
                            final newerMsg = messages[index - 1];
                            final newerTime = newerMsg.timestamp;
                            final currentTime = msg.timestamp;
                            if (newerMsg.senderId == msg.senderId && newerTime != null && currentTime != null) {
                              if (newerTime.difference(currentTime).inMinutes.abs() < 3) {
                                showTimeByDefault = false; showAvatar = false; 
                              }
                            }
                          }

                          return ChatBubbleWidget(
                            msg: msg, isMe: isMe, timeStr: timeStr,
                            showTimeByDefault: showTimeByDefault, showAvatar: showAvatar,
                            isLatestRead: index == latestReadIndex,
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    bottom: true, top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ข้อความ...', filled: true, fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: const Color(0xFF008080),
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}