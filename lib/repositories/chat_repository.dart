import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ChatRoomModel>> getChatRoomsStream(String currentUserId) {
    return _firestore
        .collection('chat_rooms')
        .where('members', arrayContains: currentUserId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatRoomModel.fromJson(doc.data(), doc.id)).toList());
  }

  Stream<ChatRoomModel?> getChatRoomStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ChatRoomModel.fromJson(snapshot.data()!, snapshot.id);
    });
  }

  Stream<List<MessageModel>> getMessagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromJson(doc.data(), doc.id)).toList());
  }

  Future<void> sendMessage(String roomId, MessageModel message, List<String> roomUsers, String currentUserId) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      DocumentReference msgRef = _firestore.collection('chat_rooms').doc(roomId).collection('messages').doc();
      
      Map<String, dynamic> msgData = message.toJson();
      msgData['timestamp'] = FieldValue.serverTimestamp();
      batch.set(msgRef, msgData);
      
      DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
      batch.update(roomRef, {
        'last_message_text': message.content,
        'last_message_type': message.type,
        'last_sender_id': currentUserId,
        'read_by': [currentUserId],
        'updated_at': FieldValue.serverTimestamp(),
        'members': FieldValue.arrayUnion(roomUsers),
        'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์ส่งข้อความ');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการส่งข้อความ: $e');
    }
  }

  Future<void> sendSystemMessage(String roomId, String text, String type, String? notiType, List<String> roomUsers, String currentUserId) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      DocumentReference msgRef = _firestore.collection('chat_rooms').doc(roomId).collection('messages').doc();
      batch.set(msgRef, {
        'sender_id': 'system', 'content': text, 'timestamp': FieldValue.serverTimestamp(), 'type': type, 
      });
      
      DocumentReference roomRef = _firestore.collection('chat_rooms').doc(roomId);
      batch.update(roomRef, {
        'last_message_text': text, 
        'last_message_type': notiType ?? type, 
        'last_sender_id': currentUserId, 
        'read_by': [currentUserId], 
        'updated_at': FieldValue.serverTimestamp(),
        'members': FieldValue.arrayUnion(roomUsers), 
        'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('ไม่มีสิทธิ์ส่งข้อความระบบ');
      }
      throw Exception('เกิดข้อผิดพลาดจากระบบ: ${e.message}');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการส่งข้อความระบบ: $e');
    }
  }

  Future<void> markRoomAsRead(String roomId, String currentUserId) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'read_by': FieldValue.arrayUnion([currentUserId]),
        'read_timestamps.$currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<Map<String, dynamic>> getTargetItemInfo(String offerId, String currentUserId) async {
    if (offerId.isEmpty) return {};
    try {
      final offerDoc = await _firestore.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return {};
      final data = offerDoc.data()!;

      String targetId = data['target_listing_id'] ?? '';
      String offeredId = data['offered_listing_id'] ?? '';
      String senderId = data['sender_id'] ?? '';

      String itemToShowId = (currentUserId == senderId) ? targetId : offeredId;
      if (itemToShowId.isNotEmpty) {
        final itemDoc = await _firestore.collection('listings').doc(itemToShowId).get();
        if (itemDoc.exists) {
          var itemData = itemDoc.data() as Map<String, dynamic>;
          itemData['listing_id'] = itemDoc.id;
          return itemData;
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<String>> getRoomMembers(String roomId) async {
    try {
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
      if (doc.exists) {
         final members = doc.data()?['members'] as List<dynamic>?;
         return members?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (e) {
      debugPrint('Error getting room members: $e');
    }
    return [];
  }

  Future<void> removeMember(String roomId, String currentUserId) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'members': FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      debugPrint('Error removing member from chat room: $e');
    }
  }

  Future<bool> canDeleteChatRoom(String? offerId, String currentUserId) async {
    if (offerId == null || offerId.isEmpty) return true;

    try {
      final offerDoc = await _firestore.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return true;

      final data = offerDoc.data();
      if (data == null) return true;

      final status = data['status'] ?? '';
      if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
        return true;
      }
      
      final targetListingId = data['target_listing_id'];
      if (targetListingId != null) {
        final listingDoc = await _firestore.collection('listings').doc(targetListingId).get();
        if (!listingDoc.exists) return true;
      }

      final offeredListingId = data['offered_listing_id'];
      if (offeredListingId != null) {
        final listingDoc = await _firestore.collection('listings').doc(offeredListingId).get();
        if (!listingDoc.exists) return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error in canDeleteChatRoom: $e');
      return true; // Allow deletion if document is inaccessible or broken
    }
  }

  Stream<bool> hasUnreadNotifications(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      for (var doc in snapshot.docs) {
        final room = doc.data();
        final List readBy = room['read_by'] ?? [];
        final String msgType = room['last_message_type'] ?? 'text';
        if (msgType != 'text' && !readBy.contains(userId)) {
          return true;
        }
      }
      return false;
    });
  }

  Future<String> getChatRoomName(String? offerId) async {
    if (offerId == null || offerId.isEmpty) return 'การแลกเปลี่ยน';
    try {
      final offerDoc = await _firestore.collection('offers').doc(offerId).get();
      if (!offerDoc.exists) return 'การแลกเปลี่ยน';

      final targetItemId = offerDoc.data()?['target_listing_id'];
      if (targetItemId == null) return 'การแลกเปลี่ยน';

      final itemDoc = await _firestore.collection('listings').doc(targetItemId).get();
      if (!itemDoc.exists) return 'สิ่งของถูกลบไปแล้ว';

      return itemDoc.data()?['title'] ?? 'การแลกเปลี่ยนสิ่งของ';
    } catch (e) {
      return 'การแลกเปลี่ยน';
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chat_rooms')
          .where('members', arrayContains: userId)
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (var doc in querySnapshot.docs) {
        final room = doc.data();
        final List readBy = room['read_by'] ?? [];
        final String msgType = room['last_message_type'] ?? 'text';
        
        if (msgType != 'text' && !readBy.contains(userId)) {
          batch.update(doc.reference, {
            'read_by': FieldValue.arrayUnion([userId])
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit(); 
      }
    } catch (e) {
      // Ignore
    }
  }
}
