import 'package:equatable/equatable.dart';
import '../../models/offer_model.dart';

abstract class OfferState extends Equatable {
  const OfferState();
  
  @override
  List<Object?> get props => [];
}

class OfferInitial extends OfferState {}

class OfferLoading extends OfferState {}

class OfferLoaded extends OfferState {
  final List<OfferModel> incomingOffers;
  final List<OfferModel> outgoingOffers;

  const OfferLoaded({required this.incomingOffers, required this.outgoingOffers});

  @override
  List<Object?> get props => [incomingOffers, outgoingOffers];
}

class OfferSubmitting extends OfferState {}

class OfferSuccess extends OfferState {
  final String message;
  const OfferSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class OfferError extends OfferState {
  final String error;
  const OfferError(this.error);

  @override
  List<Object?> get props => [error];
}
