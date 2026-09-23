import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/user_repository.dart';
import 'add_post_state.dart';

class AddPostCubit extends Cubit<AddPostState> {
  final ListingRepository _listingRepository;
  final UserRepository _userRepository;

  AddPostCubit({
    required ListingRepository listingRepository,
    required UserRepository userRepository,
  })  : _listingRepository = listingRepository,
        _userRepository = userRepository,
        super(AddPostInitial());

  Future<void> submitPost({
    required String ownerId,
    required String category,
    required String title,
    required String description,
    required String condition,
    required int estimatedCoins,
    List<ListingImageInput> images = const [],
  }) async {
    emit(AddPostSubmitting());
    try {
      final owner = await _userRepository.getUser(ownerId);

      final listing = ListingModel(
        listingId: '',
        type: 'item',
        status: 'active',
        category: category,
        ownerId: owner.uid,
        ownerName: owner.name,
        ownerProfileImg: owner.profileImgUrl,
        ownerRatingScores: 0.0,
        title: title,
        description: description,
        condition: condition,
        estimatedCoins: estimatedCoins,
        thumbnailUrl: '',
        images: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _listingRepository.createListing(listing, images: images);
      emit(AddPostSuccess());
    } catch (e) {
      emit(AddPostError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
