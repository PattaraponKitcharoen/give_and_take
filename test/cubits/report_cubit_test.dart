import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/report/report_cubit.dart';
import 'package:give_and_take/repositories/report_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockReportRepository repo;

  setUpAll(() => registerFallbackValue(ReportTarget.listing));
  setUp(() => repo = MockReportRepository());

  ReportCubit build() => ReportCubit(
      repository: repo,
      reporterId: 'me',
      type: ReportTarget.listing,
      targetId: 'L1');

  blocTest<ReportCubit, ReportState>(
    'new target: checking -> ready',
    setUp: () => when(() => repo.hasReported('me', ReportTarget.listing, 'L1'))
        .thenAnswer((_) async => false),
    build: build,
    expect: () => [const ReportState(ReportStep.ready)],
  );

  blocTest<ReportCubit, ReportState>(
    'already reported: shows that instead of the form',
    setUp: () => when(() => repo.hasReported(any(), any(), any()))
        .thenAnswer((_) async => true),
    build: build,
    expect: () => [const ReportState(ReportStep.alreadyReported)],
  );

  blocTest<ReportCubit, ReportState>(
    'check fails: still lets the user try (rules refuse duplicates)',
    setUp: () => when(() => repo.hasReported(any(), any(), any()))
        .thenAnswer((_) async => throw Exception('offline')),
    build: build,
    expect: () => [const ReportState(ReportStep.ready)],
  );

  blocTest<ReportCubit, ReportState>(
    'submit sends reason and trimmed detail',
    setUp: () {
      when(() => repo.hasReported(any(), any(), any()))
          .thenAnswer((_) async => false);
      when(() => repo.submit(
            reporterId: any(named: 'reporterId'),
            type: any(named: 'type'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            detail: any(named: 'detail'),
          )).thenAnswer((_) async {});
    },
    build: build,
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.submit('ของปลอม', '  ดูจากรูป  ');
    },
    expect: () => [
      const ReportState(ReportStep.ready),
      const ReportState(ReportStep.submitting),
      const ReportState(ReportStep.sent),
    ],
    verify: (_) => verify(() => repo.submit(
          reporterId: 'me',
          type: ReportTarget.listing,
          targetId: 'L1',
          reason: 'ของปลอม',
          detail: 'ดูจากรูป',
        )).called(1),
  );

  blocTest<ReportCubit, ReportState>(
    'failed submit ends in failed',
    setUp: () {
      when(() => repo.hasReported(any(), any(), any()))
          .thenAnswer((_) async => false);
      when(() => repo.submit(
            reporterId: any(named: 'reporterId'),
            type: any(named: 'type'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            detail: any(named: 'detail'),
          )).thenAnswer((_) async => throw Exception('permission-denied'));
    },
    build: build,
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.submit('สแปม', '');
    },
    skip: 1, // the initial "ready"
    expect: () => [
      const ReportState(ReportStep.submitting),
      const ReportState(ReportStep.failed),
    ],
  );
}
