import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/review_repository.dart';
import '../../models/review_model.dart';
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
      final String newId = _repository.generateReviewId();
      final review = ReviewModel(
        reviewId: newId,
        reviewerId: currentUserId,
        revieweeId: targetUserId,
        transactionId: transactionId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );
      await _repository.submitReview(review);
      emit(const ReviewSuccess('ส่งรีวิวสำเร็จ ขอบคุณสำหรับความคิดเห็นของคุณ'));
    } catch (e) {
      emit(ReviewError('เกิดข้อผิดพลาดในการส่งรีวิว: $e'));
    }
  }
}
