import 'package:equatable/equatable.dart';
import '../../models/listing_model.dart';

abstract class StudentListingsState extends Equatable {
  const StudentListingsState();
  @override
  List<Object?> get props => [];
}

class StudentListingsLoading extends StudentListingsState {}

class StudentListingsError extends StudentListingsState {
  final String message;
  const StudentListingsError(this.message);
  @override
  List<Object?> get props => [message];
}

class StudentListingsLoaded extends StudentListingsState {
  final List<ListingModel> items;
  final List<String> wishlist;

  const StudentListingsLoaded({required this.items, required this.wishlist});

  StudentListingsLoaded copyWith({
    List<ListingModel>? items,
    List<String>? wishlist,
  }) {
    return StudentListingsLoaded(
      items: items ?? this.items,
      wishlist: wishlist ?? this.wishlist,
    );
  }

  @override
  List<Object?> get props => [items, wishlist];
}
