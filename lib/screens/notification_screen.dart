import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_room_model.dart';
import 'chat_screen.dart';
import '../theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Color tealColor = AppColors.primary;
  String get currentUserId =>
      context.read<AuthRepository>().currentUser?.uid ?? '';

  String _selectedFilter = 'All';
  // 🟢 1. เปลี่ยนชื่อหมวดหมู่ตามที่คุณต้องการ
  final List<String> _filters = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
    'Cancelled'
  ];

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      await context.read<ChatRepository>().markAllAsRead(currentUserId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('อ่านการแจ้งเตือนทั้งหมดแล้ว'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: tealColor,
            margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return '';
    final duration = DateTime.now().difference(date);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    if (duration.inDays < 7) return '${duration.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  // 🟢 2. เพิ่มสไตล์ให้ครอบคลุมสถานะ Rejected
  Map<String, dynamic> _getNotificationStyle(String type) {
    switch (type) {
      case 'system_offer':
        return {
          'icon': Icons.description_outlined,
          'color': AppColors.warning,
          'title': 'Offer Pending',
          'btn': 'Review Offer'
        };
      case 'system_counter':
        return {
          'icon': Icons.sync,
          'color': AppColors.student,
          'title': 'Counter Offer',
          'btn': 'Review'
        };
      case 'system_accept': // 🟢 2. ปรับสไตล์ให้เข้ากับคำว่า Accepted
      case 'system_confirm':
        return {
          'icon': Icons.check_circle_outline,
          'color': tealColor,
          'title': 'Trade Accepted!',
          'btn': 'View Details'
        };
      case 'system_reject':
        return {
          'icon': Icons.thumb_down_outlined,
          'color': AppColors.danger,
          'title': 'Offer Rejected',
          'btn': 'View Details'
        };
      case 'system_cancel':
        return {
          'icon': Icons.cancel_outlined,
          'color': AppColors.inkSecondary,
          'title': 'Deal Cancelled',
          'btn': 'View Details'
        };
      default:
        return {
          'icon': Icons.notifications_outlined,
          'color': AppColors.inkTertiary,
          'title': 'System Update',
          'btn': 'View'
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications', style: AppText.title),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context),
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.page, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: isSelected
                                  ? AppColors.ink
                                  : AppColors.hairline),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatRoomModel>>(
              stream: context
                  .read<ChatRepository>()
                  .getChatRoomsStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                      child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล',
                          style: TextStyle(color: AppColors.danger)));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final rawDocs = snapshot.data ?? [];

                final notiDocs = rawDocs.where((room) {
                  final List readBy = room.readBy;
                  final String msgType = room.lastMessageType;

                  final bool isUnread = !readBy.contains(currentUserId);

                  // 🟢 3. ถ้าอ่านแล้ว (ไม่เป็น Unread) ให้ซ่อนทิ้งไปเลย! (หายไปจากลิสต์)
                  if (!isUnread) return false;

                  if (msgType == 'text') return false;

                  if (_selectedFilter != 'All') {
                    if (_selectedFilter == 'Pending' &&
                        !(msgType == 'system_offer' ||
                            msgType == 'system_counter')) return false;
                    if (_selectedFilter == 'Accepted' &&
                        !(msgType == 'system_accept' ||
                            msgType == 'system_confirm')) return false;
                    if (_selectedFilter == 'Rejected' &&
                        msgType != 'system_reject') return false;
                    if (_selectedFilter == 'Cancelled' &&
                        msgType != 'system_cancel') return false;
                  }

                  return true;
                }).toList();

                if (notiDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 56, color: AppColors.inkTertiary),
                        const SizedBox(height: 16),
                        Text('No notifications',
                            style: TextStyle(
                                color: AppColors.inkTertiary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.page, 6, AppSpace.page, 24),
                  itemCount: notiDocs.length,
                  itemBuilder: (context, index) {
                    final room = notiDocs[index];
                    final String roomId = room.id;
                    final String lastMessage = room.lastMessageText.isEmpty
                        ? 'มีการอัปเดตใหม่ในดีลนี้'
                        : room.lastMessageText;
                    final String msgType = room.lastMessageType.isEmpty
                        ? 'system_offer'
                        : room.lastMessageType;
                    final DateTime? time = room.updatedAt;

                    final List readBy = room.readBy;
                    final bool isUnread = !readBy.contains(currentUserId);

                    final styleData = _getNotificationStyle(msgType);

                    return FutureBuilder<String>(
                        future: context
                            .read<ChatRepository>()
                            .getChatRoomName(room.activeOfferId),
                        builder: (context, nameSnapshot) {
                          String itemName = nameSnapshot.data ?? '...';

                          return GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ChatScreen(roomId: roomId))),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? Colors.white
                                    : AppColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.hairline.withOpacity(0.6)),
                                boxShadow: isUnread ? AppShadows.raised : [],
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 4,
                                      decoration: BoxDecoration(
                                          color: isUnread
                                              ? styleData['color']
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.only(
                                              topLeft:
                                                  Radius.circular(AppRadius.lg),
                                              bottomLeft: Radius.circular(
                                                  AppRadius.lg))),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                gradient: AppGradients.of(
                                                    styleData['color']
                                                        as Color),
                                                shape: BoxShape.circle,
                                                boxShadow: AppShadows.glow(
                                                    styleData['color']
                                                        as Color),
                                              ),
                                              child: Icon(styleData['icon'],
                                                  color: Colors.white,
                                                  size: 22),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          styleData['title'],
                                                          style: AppText
                                                              .subtitle
                                                              .copyWith(
                                                                  fontSize: 15),
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          Text(
                                                              _getTimeAgo(time),
                                                              style: AppText
                                                                  .caption
                                                                  .copyWith(
                                                                      color: AppColors
                                                                          .inkTertiary,
                                                                      fontSize:
                                                                          11)),
                                                          if (isUnread) ...[
                                                            const SizedBox(
                                                                width: 6),
                                                            Container(
                                                                width: 8,
                                                                height: 8,
                                                                decoration: BoxDecoration(
                                                                    color: AppColors
                                                                        .primary,
                                                                    shape: BoxShape
                                                                        .circle)),
                                                          ]
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'สำหรับสิ่งของ: $itemName\n$lastMessage',
                                                    style: AppText.caption
                                                        .copyWith(
                                                            color: AppColors
                                                                .inkSecondary,
                                                            fontSize: 13),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                        color:
                                                            (styleData['color']
                                                                    as Color)
                                                                .withOpacity(
                                                                    0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    AppRadius
                                                                        .pill)),
                                                    child: Text(
                                                        styleData['btn'],
                                                        style: TextStyle(
                                                            color: styleData[
                                                                'color'],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12)),
                                                  )
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
