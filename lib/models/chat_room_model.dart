import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String? activeOfferId;
  final String lastMessageText;
  final String lastMessageType;
  final String lastSenderId;
  final List<String> members;
  final List<String> readBy;
  final Map<String, dynamic> readTimestamps;
  final DateTime? updatedAt;

  ChatRoomModel({
    required this.id,
    this.activeOfferId,
    required this.lastMessageText,
    required this.lastMessageType,
    required this.lastSenderId,
    required this.members,
    required this.readBy,
    required this.readTimestamps,
    this.updatedAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatRoomModel(
      id: id,
      activeOfferId: json['active_offer_id'],
      lastMessageText: json['last_message_text'] ?? '',
      lastMessageType: json['last_message_type'] ?? 'text',
      lastSenderId: json['last_sender_id'] ?? '',
      members: List<String>.from(json['members'] ?? []),
      readBy: List<String>.from(json['read_by'] ?? []),
      readTimestamps: json['read_timestamps'] ?? {},
      updatedAt: json['updated_at'] != null ? (json['updated_at'] as Timestamp).toDate() : null,
    );
  }
}

class ChatListItem {
  final ChatRoomModel room;
  final String title;
  final String status;
  final String thumbnail;
  final bool isUnread;

  ChatListItem({
    required this.room,
    required this.title,
    required this.status,
    required this.thumbnail,
    required this.isUnread,
  });
}
