import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/report_repository.dart';

enum ReportStep { checking, ready, alreadyReported, submitting, sent, failed }

class ReportState extends Equatable {
  final ReportStep step;
  const ReportState(this.step);
  @override
  List<Object?> get props => [step];
}

/// Drives the report sheet: checks whether this user already reported the
/// target, then sends the report.
class ReportCubit extends Cubit<ReportState> {
  final ReportRepository _repository;
  final String reporterId;
  final ReportTarget type;
  final String targetId;

  ReportCubit({
    required ReportRepository repository,
    required this.reporterId,
    required this.type,
    required this.targetId,
  })  : _repository = repository,
        super(const ReportState(ReportStep.checking)) {
    _check();
  }

  Future<void> _check() async {
    try {
      final done = await _repository.hasReported(reporterId, type, targetId);
      if (!isClosed) {
        emit(ReportState(done ? ReportStep.alreadyReported : ReportStep.ready));
      }
    } catch (_) {
      // Can't tell: let them try; a duplicate is refused by the rules.
      if (!isClosed) emit(const ReportState(ReportStep.ready));
    }
  }

  Future<void> submit(String reason, String detail) async {
    emit(const ReportState(ReportStep.submitting));
    try {
      await _repository.submit(
        reporterId: reporterId,
        type: type,
        targetId: targetId,
        reason: reason,
        detail: detail.trim(),
      );
      emit(const ReportState(ReportStep.sent));
    } catch (_) {
      emit(const ReportState(ReportStep.failed));
    }
  }
}
