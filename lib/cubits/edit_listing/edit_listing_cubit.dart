import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/listing_model.dart';
import '../../repositories/listing_repository.dart';
import 'edit_listing_state.dart';

class EditListingCubit extends Cubit<EditListingState> {
  final ListingRepository _listingRepository;

  EditListingCubit({required ListingRepository listingRepository})
      : _listingRepository = listingRepository,
        super(EditListingInitial());

  Future<void> updateListing({
    required ListingModel originalListing,
    required String title,
    required String description,
    required String category,
    required String condition,
    required int estimatedCoins,
    required List<ListingImageInput> images,
  }) async {
    emit(EditListingSubmitting());
    try {
      final updated = originalListing.copyWith(
        title: title,
        description: description,
        category: category,
        condition: condition,
        estimatedCoins: estimatedCoins,
        updatedAt: DateTime.now(),
      );

      await _listingRepository.updateListing(updated, images: images);
      emit(EditListingSuccess());
    } catch (e) {
      emit(EditListingError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
