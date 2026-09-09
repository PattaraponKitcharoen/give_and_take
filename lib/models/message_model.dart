import 'package:cloud_firestore/cloud_firestore.dart';
import 'listing_model.dart';

class SystemOfferData {
  final ListingModel? targetItem;
  final ListingModel? offeredItem;

  SystemOfferData({this.targetItem, this.offeredItem});

  factory SystemOfferData.fromJson(Map<String, dynamic> json) {
    final targetJson = json['target_item'] as Map<String, dynamic>?;
    final offeredJson = json['offered_item'] as Map<String, dynamic>?;
    return SystemOfferData(
      targetItem: targetJson != null ? ListingModel.fromJson(targetJson, targetJson['listing_id'] ?? '') : null,
      offeredItem: offeredJson != null ? ListingModel.fromJson(offeredJson, offeredJson['listing_id'] ?? '') : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (targetItem != null) 'target_item': targetItem!.toJson(),
      if (offeredItem != null) 'offered_item': offeredItem!.toJson(),
    };
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final DateTime? timestamp;
  final String type;
  final SystemOfferData? offerData;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    this.timestamp,
    required this.type,
    this.offerData,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String id) {
    return MessageModel(
      id: id,
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null ? (json['timestamp'] as Timestamp).toDate() : null,
      type: json['type'] ?? 'text',
      offerData: json['offer_data'] != null ? SystemOfferData.fromJson(json['offer_data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'type': type,
    };
    if (offerData != null) {
      map['offer_data'] = offerData!.toJson();
    }
    return map;
  }
}
