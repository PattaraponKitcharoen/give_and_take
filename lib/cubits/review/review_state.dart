import 'package:equatable/equatable.dart';

abstract class ReviewState extends Equatable {
  const ReviewState();
  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {}

class ReviewSubmitting extends ReviewState {}

class ReviewSuccess extends ReviewState {
  final String message;
  const ReviewSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ReviewError extends ReviewState {
  final String error;
  const ReviewError(this.error);
  @override
  List<Object?> get props => [error];
}
