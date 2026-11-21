import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/match/match_badge_cubit.dart';
import 'package:give_and_take/cubits/match/match_cubit.dart';
import 'package:give_and_take/models/match_model.dart';
import 'package:give_and_take/repositories/match_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

void main() {
  late MockMatchRepository repo;
  late StreamController<List<WantModel>> wants;
  late StreamController<List<MatchModel>> matches;
  late StreamController<bool> enabled;

  setUp(() {
    repo = MockMatchRepository();
    wants = StreamController<List<WantModel>>.broadcast();
    matches = StreamController<List<MatchModel>>.broadcast();
    enabled = StreamController<bool>.broadcast();
    when(() => repo.wantsStream('me')).thenAnswer((_) => wants.stream);
    when(() => repo.matchesStream('me')).thenAnswer((_) => matches.stream);
    when(() => repo.matchEnabledStream('me')).thenAnswer((_) => enabled.stream);
    when(() => repo.markSeen(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await wants.close();
    await matches.close();
    await enabled.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<MatchCubit> ready({List<WantModel> w = const []}) async {
    final cubit = MatchCubit(matchRepository: repo, userId: 'me');
    wants.add(w);
    matches.add(const []);
    enabled.add(true);
    await settle();
    return cubit;
  }

  test('stays loading until both wants and matches have arrived', () async {
    final cubit = MatchCubit(matchRepository: repo, userId: 'me');
    wants.add(const []);
    await settle();
    expect(cubit.state.loading, isTrue);
    matches.add(const []);
    await settle();
    expect(cubit.state.loading, isFalse);
    await cubit.close();
  });

  test('a stream error stops the spinner and shows a message', () async {
    final cubit = MatchCubit(matchRepository: repo, userId: 'me');
    matches.addError(Exception('denied'));
    await settle();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.message, isNotNull);
    await cubit.close();
  });

  group('matches', () {
    test('only matches whose two listings are still active, new ones first',
        () async {
      when(() => repo.getListing(any())).thenAnswer((inv) async {
        final id = inv.positionalArguments.first as String;
        return id == 'GONE'
            ? null
            : listing(id, status: id == 'BUSY' ? 'in_progress' : 'active');
      });
      final cubit = MatchCubit(matchRepository: repo, userId: 'me');
      wants.add(const []);
      matches.add([
        match('seen-high', mine: 'M1', theirs: 'T1', score: 0.9, seen: true),
        match('new-low', mine: 'M2', theirs: 'T2', score: 0.7),
        match('new-high', mine: 'M3', theirs: 'T3', score: 0.85),
        match('deleted', mine: 'M4', theirs: 'GONE'),
        match('in-a-deal', mine: 'BUSY', theirs: 'T5'),
      ]);
      await settle();
      expect(cubit.state.matches.map((m) => m.id),
          ['new-high', 'new-low', 'seen-high']);
      expect(cubit.state.matches.first.theirListing?.listingId, 'T3');
      await cubit.close();
    });

    test('each listing is fetched once even when matches update', () async {
      when(() => repo.getListing(any())).thenAnswer(
          (inv) async => listing(inv.positionalArguments.first as String));
      final cubit = MatchCubit(matchRepository: repo, userId: 'me');
      wants.add(const []);
      matches.add([match('a', mine: 'M', theirs: 'T')]);
      await settle();
      matches.add([match('a', mine: 'M', theirs: 'T', seen: true)]);
      await settle();
      verify(() => repo.getListing('M')).called(1);
      verify(() => repo.getListing('T')).called(1);
      await cubit.close();
    });

    test('leaving the screen marks the unseen matches as seen', () async {
      when(() => repo.getListing(any())).thenAnswer(
          (inv) async => listing(inv.positionalArguments.first as String));
      final cubit = MatchCubit(matchRepository: repo, userId: 'me');
      wants.add(const []);
      matches.add([
        match('new', mine: 'M1', theirs: 'T1'),
        match('old', mine: 'M2', theirs: 'T2', seen: true),
      ]);
      await settle();
      verifyNever(() => repo.markSeen(any(), any()));
      await cubit.close();
      verify(() => repo.markSeen(['new'], 'me')).called(1);
    });
  });

  group('addWant', () {
    test('trims and saves', () async {
      when(() => repo.addWant('me', 'หูฟัง')).thenAnswer((_) async {});
      final cubit = await ready();
      expect(await cubit.addWant('  หูฟัง  '), isTrue);
      verify(() => repo.addWant('me', 'หูฟัง')).called(1);
      await cubit.close();
    });

    test('empty text is ignored', () async {
      final cubit = await ready();
      expect(await cubit.addWant('   '), isFalse);
      verifyNever(() => repo.addWant(any(), any()));
      await cubit.close();
    });

    test('over 120 characters is refused with a message', () async {
      final cubit = await ready();
      expect(await cubit.addWant('x' * 121), isFalse);
      expect(cubit.state.message, contains('120'));
      verifyNever(() => repo.addWant(any(), any()));
      await cubit.close();
    });

    test('the 11th want is refused', () async {
      final cubit = await ready(
          w: List.generate(10, (i) => WantModel(id: '$i', text: 'w$i')));
      expect(await cubit.addWant('อีกอัน'), isFalse);
      expect(cubit.state.message, contains('${MatchRepository.maxWants}'));
      await cubit.close();
    });

    test('a failed save says so', () async {
      when(() => repo.addWant(any(), any())).thenThrow(Exception('offline'));
      final cubit = await ready();
      expect(await cubit.addWant('หูฟัง'), isFalse);
      expect(cubit.state.message, isNotNull);
      await cubit.close();
    });
  });

  group('rescan and the switch', () {
    test('throttled rescan tells how long to wait', () async {
      when(() => repo.rescan()).thenAnswer((_) async => 42);
      final cubit = await ready();
      await cubit.rescan();
      expect(cubit.state.rescanning, isFalse);
      expect(cubit.state.message, contains('42 นาที'));
      await cubit.close();
    });

    test('a rescan that ran gives no message', () async {
      when(() => repo.rescan()).thenAnswer((_) async => null);
      final cubit = await ready();
      await cubit.rescan();
      expect(cubit.state.message, isNull);
      await cubit.close();
    });

    test('turning matching on saves it and rescans', () async {
      when(() => repo.setMatchEnabled('me', true)).thenAnswer((_) async {});
      when(() => repo.rescan()).thenAnswer((_) async => null);
      final cubit = await ready();
      await cubit.setEnabled(true);
      verify(() => repo.rescan()).called(1);
      await cubit.close();
    });

    test('a failed save puts the switch back', () async {
      when(() => repo.setMatchEnabled('me', false))
          .thenThrow(Exception('offline'));
      final cubit = await ready();
      await cubit.setEnabled(false);
      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.message, isNotNull);
      await cubit.close();
    });
  });

  test('MatchBadgeCubit counts unseen matches', () async {
    final badge = MatchBadgeCubit(matchRepository: repo, userId: 'me');
    matches.add([match('a'), match('b', seen: true), match('c')]);
    await settle();
    expect(badge.state, 2);
    await badge.close();
  });
}
