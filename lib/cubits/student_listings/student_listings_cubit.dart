import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/user_repository.dart';
import 'student_listings_state.dart';

/// Powers the "Student" banner's destination screen: active listings whose
/// owner is a verified student, newest first.
///
/// Combines two independent streams (mirrors HomeCubit/ProfileCubit's
/// dual-stream pattern) rather than denormalizing owner_is_student onto
/// listings — see the comment on UserRepository.getStudentUserIdsStream for
/// why.
class StudentListingsCubit extends Cubit<StudentListingsState> {
  final ListingRepository _listingRepository;
  final UserRepository _userRepository;
  final String currentUserId;

  StreamSubscription<List<ListingModel>>? _itemsSubscription;
  StreamSubscription<Set<String>>? _studentIdsSubscription;
  StreamSubscription<UserModel>? _userSubscription;

  List<ListingModel>? _latestItems;
  Set<String>? _latestStudentIds;
  List<String>? _latestWishlist;

  StudentListingsCubit({
    required ListingRepository listingRepository,
    required UserRepository userRepository,
    required this.currentUserId,
  })  : _listingRepository = listingRepository,
        _userRepository = userRepository,
        super(StudentListingsLoading()) {
    _init();
  }

  void _init() {
    _itemsSubscription = _listingRepository.getActiveItemsStream().listen(
      (items) {
        _latestItems = items;
        _emitCombined();
      },
      onError: (error) => emit(StudentListingsError(error.toString())),
    );

    _studentIdsSubscription = _userRepository.getStudentUserIdsStream().listen(
      (ids) {
        _latestStudentIds = ids;
        _emitCombined();
      },
      onError: (error) => emit(StudentListingsError(error.toString())),
    );

    if (currentUserId.isEmpty) {
      _latestWishlist = const [];
    } else {
      _userSubscription = _userRepository.getUserStream(currentUserId).listen(
        (user) {
          _latestWishlist = user.wishlist;
          _emitCombined();
        },
        onError: (error) => emit(StudentListingsError(error.toString())),
      );
    }
  }

  void _emitCombined() {
    final items = _latestItems;
    final studentIds = _latestStudentIds;
    final wishlist = _latestWishlist;
    if (items == null || studentIds == null || wishlist == null) return;

    final filtered = items
        .where((item) =>
            studentIds.contains(item.ownerId) && item.ownerId != currentUserId)
        .toList()
      ..sort((a, b) {
        final timeA = a.createdAt ?? DateTime.now();
        final timeB = b.createdAt ?? DateTime.now();
        return timeB.compareTo(timeA);
      });

    emit(StudentListingsLoaded(items: filtered, wishlist: wishlist));
  }

  Future<void> toggleWishlist(ListingModel item) async {
    if (state is! StudentListingsLoaded) return;
    final loadedBeforeWrite = state as StudentListingsLoaded;

    final isWishlisted = loadedBeforeWrite.wishlist.contains(item.listingId);
    final optimisticWishlist = isWishlisted
        ? loadedBeforeWrite.wishlist
            .where((id) => id != item.listingId)
            .toList()
        : [...loadedBeforeWrite.wishlist, item.listingId];

    _latestWishlist = optimisticWishlist;
    emit(loadedBeforeWrite.copyWith(wishlist: optimisticWishlist));

    try {
      await _userRepository.toggleWishlist(
          currentUserId, item.listingId, isWishlisted);
    } catch (e) {
      _latestWishlist = loadedBeforeWrite.wishlist;
      if (state is StudentListingsLoaded) {
        emit((state as StudentListingsLoaded)
            .copyWith(wishlist: loadedBeforeWrite.wishlist));
      }
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _itemsSubscription?.cancel();
    _studentIdsSubscription?.cancel();
    _userSubscription?.cancel();
    return super.close();
  }
}
