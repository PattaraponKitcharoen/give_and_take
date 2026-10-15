import 'package:equatable/equatable.dart';
import '../../models/listing_estimate.dart';

abstract class ListingEstimateState extends Equatable {
  const ListingEstimateState();

  @override
  List<Object?> get props => [];
}

class ListingEstimateInitial extends ListingEstimateState {}

class ListingEstimateLoading extends ListingEstimateState {}

class ListingEstimateSuccess extends ListingEstimateState {
  final ListingEstimate estimate;
  const ListingEstimateSuccess(this.estimate);

  @override
  List<Object?> get props => [estimate];
}

class ListingEstimateError extends ListingEstimateState {
  final String message;
  const ListingEstimateError(this.message);

  @override
  List<Object?> get props => [message];
}
