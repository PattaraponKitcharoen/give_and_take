import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/chat_repository.dart';
import '../../models/chat_room_model.dart';
import 'chat_list_state.dart';

class ChatListCubit extends Cubit<ChatListState> {
  final ChatRepository _repository;
  StreamSubscription? _subscription;

  ChatListCubit({required ChatRepository repository})
      : _repository = repository,
        super(ChatListInitial());

  void listenToChatRooms(String currentUserId) {
    emit(ChatListLoading());
    _subscription?.cancel();
    _subscription = _repository.getChatRoomsStream(currentUserId).listen(
      (rooms) async {
        try {
          List<ChatListItem> items = [];
          for (var room in rooms) {
            String title = 'ห้องแชทส่วนตัว';
            String status = '';
            String thumbnail = '';
            
            if (room.activeOfferId != null && room.activeOfferId!.isNotEmpty) {
              try {
                final itemData = await _repository.getTargetItemInfo(room.activeOfferId!, currentUserId);
                if (itemData.isNotEmpty) {
                  title = itemData['title'] ?? 'ไม่มีชื่อสิ่งของ';
                  thumbnail = itemData['thumbnail_url'] ?? '';
                  status = itemData['status'] ?? ''; 
                } else {
                  title = 'ห้องแชท (ไม่พบข้อมูล)';
                }
              } catch (e) {
                title = 'ห้องแชท';
              }
            }
            
            bool isUnread = !room.readBy.contains(currentUserId) && room.lastMessageText.isNotEmpty;
            
            items.add(ChatListItem(
              room: room,
              title: title,
              status: status,
              thumbnail: thumbnail,
              isUnread: isUnread,
            ));
          }
          if (!isClosed) emit(ChatListLoaded(items));
        } catch (e) {
          if (!isClosed) emit(ChatListError(e.toString()));
        }
      },
      onError: (error) {
        debugPrint('\n=== FIREBASE INDEX URL ===\n$error\n==========================\n');
        if (!isClosed) emit(ChatListError(error.toString()));
      },
    );
  }

  Future<void> removeMember(String roomId, String currentUserId) async {
    await _repository.removeMember(roomId, currentUserId);
  }

  Future<bool> canDeleteChatRoom(String? offerId, String currentUserId) async {
    return await _repository.canDeleteChatRoom(offerId, currentUserId);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
