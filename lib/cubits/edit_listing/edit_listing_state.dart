import 'package:equatable/equatable.dart';

abstract class EditListingState extends Equatable {
  const EditListingState();

  @override
  List<Object?> get props => [];
}

class EditListingInitial extends EditListingState {}

class EditListingSubmitting extends EditListingState {}

class EditListingSuccess extends EditListingState {}

class EditListingError extends EditListingState {
  final String message;
  const EditListingError(this.message);

  @override
  List<Object?> get props => [message];
}
