import 'package:equatable/equatable.dart';
import '../../models/listing_model.dart';
import '../../models/place_location.dart';

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
  final String sortBy; // 'newest', 'nearest', 'coins_asc', 'coins_desc'
  final List<String> wishlist; // listingIds in the current user's wishlist
  final PlaceLocation? userLocation; // viewer's ~1 km position, if known

  const HomeLoaded({
    required this.allItems,
    required this.filteredItems,
    this.selectedCategories = const ['All'],
    this.sortBy = 'newest',
    this.wishlist = const [],
    this.userLocation,
  });

  HomeLoaded copyWith({
    List<ListingModel>? allItems,
    List<ListingModel>? filteredItems,
    List<String>? selectedCategories,
    String? sortBy,
    List<String>? wishlist,
    PlaceLocation? userLocation,
  }) {
    return HomeLoaded(
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      sortBy: sortBy ?? this.sortBy,
      wishlist: wishlist ?? this.wishlist,
      userLocation: userLocation ?? this.userLocation,
    );
  }

  @override
  List<Object?> get props => [
        allItems,
        filteredItems,
        selectedCategories,
        sortBy,
        wishlist,
        userLocation,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
