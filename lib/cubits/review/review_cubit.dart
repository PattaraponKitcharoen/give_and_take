import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/review_repository.dart';
import 'review_state.dart';

class ReviewCubit extends Cubit<ReviewState> {
  final ReviewRepository _repository;

  ReviewCubit({required ReviewRepository repository})
      : _repository = repository,
        super(ReviewInitial());

  Future<void> submitReview({
    required String targetUserId,
    required String currentUserId,
    required String transactionId,
    required double rating,
    required String comment,
  }) async {
    emit(ReviewSubmitting());
    try {
      // The Cloud Function resolves the reviewer from the auth token and
      // generates the review doc's id itself now, so currentUserId is no
      // longer needed here — kept in the signature so chat_screen.dart's
      // call site doesn't need to change.
      await _repository.submitReview(
        revieweeId: targetUserId,
        transactionId: transactionId,
        rating: rating,
        comment: comment,
      );
      emit(const ReviewSuccess('ส่งรีวิวสำเร็จ ขอบคุณสำหรับความคิดเห็นของคุณ'));
    } catch (e) {
      emit(ReviewError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
