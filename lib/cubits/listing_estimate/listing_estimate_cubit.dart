import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/ai_repository.dart';
import 'listing_estimate_state.dart';

class ListingEstimateCubit extends Cubit<ListingEstimateState> {
  final AiRepository _aiRepository;

  ListingEstimateCubit({required AiRepository aiRepository})
      : _aiRepository = aiRepository,
        super(ListingEstimateInitial());

  Future<void> estimate(List<File> images, {String hint = ''}) async {
    if (images.isEmpty || state is ListingEstimateLoading) return;
    emit(ListingEstimateLoading());
    try {
      final result = await _aiRepository.estimateListing(images, hint: hint);
      if (!isClosed) emit(ListingEstimateSuccess(result));
    } catch (e) {
      if (!isClosed) {
        emit(ListingEstimateError(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  /// Photos changed: the last suggestion no longer describes them.
  void reset() {
    if (state is! ListingEstimateLoading) emit(ListingEstimateInitial());
  }
}
