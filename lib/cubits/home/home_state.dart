import 'package:equatable/equatable.dart';
import '../../models/listing_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ListingModel> allItems; // Original list from stream
  final List<ListingModel> filteredItems; // Items shown to user
  final List<String> selectedCategories;
  final String sortBy; // 'newest', 'coins_asc', 'coins_desc'

  const HomeLoaded({
    required this.allItems,
    required this.filteredItems,
    this.selectedCategories = const ['All'],
    this.sortBy = 'newest',
  });

  HomeLoaded copyWith({
    List<ListingModel>? allItems,
    List<ListingModel>? filteredItems,
    List<String>? selectedCategories,
    String? sortBy,
  }) {
    return HomeLoaded(
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  List<Object?> get props => [
        allItems,
        filteredItems,
        selectedCategories,
        sortBy,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
