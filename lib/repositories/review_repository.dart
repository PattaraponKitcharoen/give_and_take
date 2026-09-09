import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String generateReviewId() {
    return _firestore.collection('reviews').doc().id;
  }

  Stream<List<ReviewModel>> getReviewsForTransaction(String transactionId, String reviewerId) {
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
    await _firestore.collection('reviews').doc(review.reviewId).set(review.toJson());
  }

  Future<void> submitReview(ReviewModel review) async {
    final txRef = _firestore.collection('reviews').doc(review.reviewId);
    final userRef = _firestore.collection('users').doc(review.revieweeId);

    final existingReview = await _firestore.collection('reviews')
        .where('transaction_id', isEqualTo: review.transactionId)
        .where('reviewer_id', isEqualTo: review.reviewerId)
        .get();
        
    if (existingReview.docs.isNotEmpty) {
      throw Exception('คุณได้ให้คะแนนดีลนี้ไปแล้ว');
    }

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) throw Exception("ไม่พบผู้ใช้งานเป้าหมาย");
      final userData = userSnap.data() as Map<String, dynamic>;
      
      double currentScores = (userData['owner_rating_scores'] ?? 0.0).toDouble();
      int currentCount = userData['owner_rating_count'] ?? 0;
      
      double newScores = ((currentScores * currentCount) + review.rating) / (currentCount + 1);
      
      transaction.set(txRef, review.toJson());
      transaction.update(userRef, {
        'owner_rating_scores': newScores,
        'owner_rating_count': currentCount + 1,
      });
    });
  }
}
