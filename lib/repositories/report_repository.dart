import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportTarget { listing, user, chat }

/// User reports (reports/{reporterId}_{type}_{targetId}). One report per
/// reporter per target; the Cloud Function onReportCreated attaches the
/// evidence for the admins.
class ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(
          String reporterId, ReportTarget type, String targetId) =>
      _firestore
          .collection('reports')
          .doc('${reporterId}_${type.name}_$targetId');

  Future<bool> hasReported(
      String reporterId, ReportTarget type, String targetId) async {
    final doc = await _ref(reporterId, type, targetId).get();
    return doc.exists;
  }

  Future<void> submit({
    required String reporterId,
    required ReportTarget type,
    required String targetId,
    required String reason,
    String detail = '',
  }) {
    return _ref(reporterId, type, targetId).set({
      'reporter_id': reporterId,
      'target_type': type.name,
      'target_id': targetId,
      'reason': reason,
      'detail': detail,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
