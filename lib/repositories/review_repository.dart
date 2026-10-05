import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/firebase_config.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ReviewRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? appFunctions();

  Stream<List<ReviewModel>> getReviewsForTransaction(
      String transactionId, String reviewerId) {
    return _firestore
        .collection('reviews')
        .where('transaction_id', isEqualTo: transactionId)
        .where('reviewer_id', isEqualTo: reviewerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addReview(ReviewModel review) async {
    await _firestore
        .collection('reviews')
        .doc(review.reviewId)
        .set(review.toJson());
  }

  // Submitting a review updates the REVIEWEE's own rating aggregate fields
  // (owner_rating_scores/owner_rating_count) — a different user's document
  // than the caller's — the same class of cross-user write that
  // confirmHandoverOtp/cancelAcceptedTrade had to move server-side for. This
  // also closes a gap the old client-side version had: it never checked that
  // the reviewer/reviewee were actually both members of a real, completed
  // transaction before writing, which the Cloud Function now verifies.
  Future<void> submitReview({
    required String revieweeId,
    required String transactionId,
    required double rating,
    required String comment,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitTradeReview');
      await callable.call(<String, dynamic>{
        'revieweeId': revieweeId,
        'transactionId': transactionId,
        'rating': rating,
        'comment': comment,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'ไม่สามารถส่งรีวิวได้ กรุณาลองใหม่อีกครั้ง');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการส่งรีวิว กรุณาลองใหม่อีกครั้ง');
    }
  }
}
