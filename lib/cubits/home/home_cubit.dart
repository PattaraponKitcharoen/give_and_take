import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/user_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final ListingRepository _listingRepository;
  final UserRepository _userRepository;
  final String currentUserId;
  StreamSubscription<List<ListingModel>>? _itemsSubscription;
  StreamSubscription<UserModel>? _userSubscription;

  // Latest values from each stream, combined into a single HomeLoaded once
  // both have reported at least once (mirrors ProfileCubit's dual-stream
  // pattern).
  List<ListingModel>? _latestItems;
  List<String>? _latestWishlist;

  HomeCubit({
    required ListingRepository listingRepository,
    required UserRepository userRepository,
    required this.currentUserId,
  })  : _listingRepository = listingRepository,
        _userRepository = userRepository,
        super(HomeLoading());

  void fetchItems() {
    emit(HomeLoading());
    _itemsSubscription?.cancel();
    _userSubscription?.cancel();
    _latestItems = null;
    _latestWishlist = null;

    _itemsSubscription = _listingRepository.getActiveItemsStream().listen(
      (List<ListingModel> items) {
        _latestItems =
            items.where((item) => item.ownerId != currentUserId).toList();
        _emitCombined();
      },
      onError: (error) {
        emit(HomeError(error.toString()));
      },
    );

    if (currentUserId.isEmpty) {
      // No signed-in user to own a wishlist — behave as if it's empty
      // instead of trying to stream doc `users/` (empty id).
      _latestWishlist = const [];
    } else {
      _userSubscription = _userRepository.getUserStream(currentUserId).listen(
        (UserModel user) {
          _latestWishlist = user.wishlist;
          _emitCombined();
        },
        onError: (error) {
          emit(HomeError(error.toString()));
        },
      );
    }
  }

  void _emitCombined() {
    final items = _latestItems;
    final wishlist = _latestWishlist;
    if (items == null || wishlist == null) return;

    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      final newFiltered = _applyCurrentFilters(
        items: items,
        wishlist: wishlist,
        categories: currentState.selectedCategories,
        sortBy: currentState.sortBy,
      );
      emit(currentState.copyWith(
        allItems: items,
        filteredItems: newFiltered,
        wishlist: wishlist,
      ));
    } else {
      final initialFiltered = _applyCurrentFilters(
        items: items,
        wishlist: wishlist,
        categories: const ['All'],
        sortBy: 'newest',
      );
      emit(HomeLoaded(
        allItems: items,
        filteredItems: initialFiltered,
        wishlist: wishlist,
      ));
    }
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
      wishlist: currentState.wishlist,
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
      wishlist: currentState.wishlist,
      categories: currentState.selectedCategories,
      sortBy: sortBy,
    );

    emit(currentState.copyWith(
      sortBy: sortBy,
      filteredItems: newFiltered,
    ));
  }

  Future<void> toggleWishlist(ListingModel item) async {
    if (state is! HomeLoaded) return;
    final loadedBeforeWrite = state as HomeLoaded;

    final isWishlisted = loadedBeforeWrite.wishlist.contains(item.listingId);
    final optimisticWishlist = isWishlisted
        ? loadedBeforeWrite.wishlist
            .where((id) => id != item.listingId)
            .toList()
        : [...loadedBeforeWrite.wishlist, item.listingId];

    // Optimistic update: flip the heart immediately instead of waiting on
    // the Firestore stream round-trip, which can take a moment.
    _latestWishlist = optimisticWishlist;
    _emitWithWishlist(loadedBeforeWrite, optimisticWishlist);

    try {
      await _userRepository.toggleWishlist(
          currentUserId, item.listingId, isWishlisted);
    } catch (e) {
      // Roll back the optimistic change instead of silently leaving the UI
      // showing a wishlist toggle that never actually saved, and let the
      // caller find out the write failed.
      _latestWishlist = loadedBeforeWrite.wishlist;
      if (state is HomeLoaded) {
        _emitWithWishlist(state as HomeLoaded, loadedBeforeWrite.wishlist);
      }
      rethrow;
    }
  }

  void _emitWithWishlist(HomeLoaded current, List<String> wishlist) {
    final updatedFiltered = _applyCurrentFilters(
      items: current.allItems,
      wishlist: wishlist,
      categories: current.selectedCategories,
      sortBy: current.sortBy,
    );
    emit(current.copyWith(wishlist: wishlist, filteredItems: updatedFiltered));
  }

  List<ListingModel> _applyCurrentFilters({
    required List<ListingModel> items,
    required List<String> wishlist,
    required List<String> categories,
    required String sortBy,
  }) {
    var filtered = items.where((item) {
      bool hasWishlistFilter = categories.contains('Wishlists');
      if (hasWishlistFilter && !wishlist.contains(item.listingId)) {
        return false;
      }

      List<String> activeCats =
          categories.where((c) => c != 'Wishlists').toList();
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
    _userSubscription?.cancel();
    return super.close();
  }
}
