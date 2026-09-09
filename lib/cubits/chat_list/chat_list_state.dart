import 'package:equatable/equatable.dart';
import '../../models/chat_room_model.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();
  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {}

class ChatListLoading extends ChatListState {}

class ChatListLoaded extends ChatListState {
  final List<ChatListItem> items;
  const ChatListLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class ChatListError extends ChatListState {
  final String error;
  const ChatListError(this.error);
  @override
  List<Object?> get props => [error];
}
