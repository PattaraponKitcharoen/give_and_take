import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../repositories/listing_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final ListingRepository _listingRepository;
  final String currentUserId;
  StreamSubscription<List<ListingModel>>? _itemsSubscription;

  HomeCubit({
    required ListingRepository listingRepository,
    required this.currentUserId,
  })  : _listingRepository = listingRepository,
        super(HomeLoading());

  void fetchItems() {
    emit(HomeLoading());
    _itemsSubscription?.cancel();
    
    _itemsSubscription = _listingRepository.getActiveItemsStream().listen(
      (List<ListingModel> items) {
        final otherUserItems = items.where((item) => item.ownerId != currentUserId).toList();
        
        if (state is HomeLoaded) {
          final currentState = state as HomeLoaded;
          final newFiltered = _applyCurrentFilters(
            items: otherUserItems,
            categories: currentState.selectedCategories,
            sortBy: currentState.sortBy,
          );
          emit(currentState.copyWith(
            allItems: otherUserItems,
            filteredItems: newFiltered,
          ));
        } else {
          final initialFiltered = _applyCurrentFilters(
            items: otherUserItems,
            categories: const ['All'],
            sortBy: 'newest',
          );
          emit(HomeLoaded(
            allItems: otherUserItems,
            filteredItems: initialFiltered,
          ));
        }
      },
      onError: (error) {
        emit(HomeError(error.toString()));
      },
    );
  }

  void toggleCategory(String category) {
    if (state is! HomeLoaded) return;
    final currentState = state as HomeLoaded;
    
    List<String> newCategories = List.from(currentState.selectedCategories);
    
    if (category == 'All') {
      newCategories = ['All'];
    } else {
      newCategories.remove('All');
      if (newCategories.contains(category)) {
        newCategories.remove(category);
        if (newCategories.isEmpty) {
          newCategories = ['All'];
        }
      } else {
        newCategories.add(category);
      }
    }
    
    final newFiltered = _applyCurrentFilters(
      items: currentState.allItems,
      categories: newCategories,
      sortBy: currentState.sortBy,
    );
    
    emit(currentState.copyWith(
      selectedCategories: newCategories,
      filteredItems: newFiltered,
    ));
  }

  void updateSort(String sortBy) {
    if (state is! HomeLoaded) return;
    final currentState = state as HomeLoaded;
    
    final newFiltered = _applyCurrentFilters(
      items: currentState.allItems,
      categories: currentState.selectedCategories,
      sortBy: sortBy,
    );
    
    emit(currentState.copyWith(
      sortBy: sortBy,
      filteredItems: newFiltered,
    ));
  }

  Future<void> toggleLike(ListingModel item) async {
    try {
      final isLiked = item.likedBy.contains(currentUserId);
      await _listingRepository.toggleLike(item.listingId, currentUserId, isLiked);
    } catch (e) {
      // Opt: emit error or silent fail
    }
  }

  List<ListingModel> _applyCurrentFilters({
    required List<ListingModel> items,
    required List<String> categories,
    required String sortBy,
  }) {
    var filtered = items.where((item) {
      bool hasWishlistFilter = categories.contains('Wishlists');
      if (hasWishlistFilter && !item.likedBy.contains(currentUserId)) {
        return false;
      }

      List<String> activeCats = categories.where((c) => c != 'Wishlists').toList();
      if (activeCats.isNotEmpty && !activeCats.contains('All')) {
        if (!activeCats.contains(item.category)) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (sortBy == 'coins_asc') {
        return a.estimatedCoins.compareTo(b.estimatedCoins);
      } else if (sortBy == 'coins_desc') {
        return b.estimatedCoins.compareTo(a.estimatedCoins);
      } else {
        final timeA = a.createdAt ?? DateTime.now();
        final timeB = b.createdAt ?? DateTime.now();
        return timeB.compareTo(timeA);
      }
    });

    return filtered;
  }

  @override
  Future<void> close() {
    _itemsSubscription?.cancel();
    return super.close();
  }
}
