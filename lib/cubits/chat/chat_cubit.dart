import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/chat_repository.dart';
import '../../models/message_model.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _subscription;

  ChatCubit({required ChatRepository repository})
      : _repository = repository,
        super(ChatInitial());

  void listenToMessages(String roomId) {
    emit(ChatLoading());
    _subscription?.cancel();
    _subscription = _repository.getMessagesStream(roomId).listen(
      (messages) {
        emit(ChatLoaded(messages));
      },
      onError: (error) {
        emit(ChatError(error.toString()));
      },
    );
  }

  Future<void> sendMessage(String roomId, String text, String currentUserId, List<String> roomUsers) async {
    try {
      final message = MessageModel(
        id: '', // Firestore will auto-generate ID
        senderId: currentUserId,
        content: text,
        type: 'text',
      );
      await _repository.sendMessage(roomId, message, roomUsers, currentUserId);
    } catch (e) {
      emit(ChatError('เกิดข้อผิดพลาดในการส่งข้อความ: $e'));
    }
  }

  Future<void> sendSystemMessage(String roomId, String text, String type, String? notiType, List<String> roomUsers, String currentUserId) async {
    try {
      await _repository.sendSystemMessage(roomId, text, type, notiType, roomUsers, currentUserId);
    } catch (e) {
      emit(ChatError('เกิดข้อผิดพลาดในการส่งข้อความระบบ: $e'));
    }
  }

  Future<void> markAsRead(String roomId, String currentUserId) async {
    await _repository.markRoomAsRead(roomId, currentUserId);
  }

  Future<Map<String, dynamic>> getTargetItemInfo(String offerId, String currentUserId) async {
    return await _repository.getTargetItemInfo(offerId, currentUserId);
  }

  Future<List<String>> getRoomMembers(String roomId) async {
    return await _repository.getRoomMembers(roomId);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
