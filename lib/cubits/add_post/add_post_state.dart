import 'package:equatable/equatable.dart';

abstract class AddPostState extends Equatable {
  const AddPostState();

  @override
  List<Object?> get props => [];
}

class AddPostInitial extends AddPostState {}

class AddPostSubmitting extends AddPostState {}

class AddPostSuccess extends AddPostState {}

class AddPostError extends AddPostState {
  final String message;
  const AddPostError(this.message);

  @override
  List<Object?> get props => [message];
}
