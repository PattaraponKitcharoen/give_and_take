import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/wallet_history/wallet_history_cubit.dart';
import 'package:give_and_take/cubits/wallet_history/wallet_history_state.dart';
import 'package:give_and_take/models/wallet_entry.dart';
import 'package:give_and_take/repositories/wallet_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

class MockQuerySnapshot extends Mock implements QuerySnapshot<Object?> {}

// Firestore marks its snapshot types @sealed; faking them is fine in tests.
// ignore: subtype_of_sealed_class
class MockDoc extends Mock implements QueryDocumentSnapshot<Object?> {}

MockDoc entryDoc(String id, String ref, int amount) {
  final d = MockDoc();
  when(() => d.id).thenReturn(id);
  when(() => d.data()).thenReturn(<String, dynamic>{
    'amount': amount,
    'type': amount < 0 ? 'escrow_lock' : 'escrow_release',
    'description': 'x',
    'reference_id': ref,
  });
  return d;
}

QuerySnapshot<Object?> snapshot(List<MockDoc> docs) {
  final s = MockQuerySnapshot();
  when(() => s.docs).thenReturn(docs);
  return s;
}

const deal = WalletDeal(
  offerId: 'O1',
  myItemTitle: 'เสื่อโยคะ',
  theirItemTitle: 'หูฟัง',
  theirItemThumbnail: '',
  partnerName: 'Bob',
  roomId: 'R1',
);

void main() {
  late MockWalletRepository repo;
  late StreamController<QuerySnapshot<Object?>> history;

  setUpAll(() => registerFallbackValue(const WalletEntry(
      id: '', amount: 0, type: '', description: '', referenceId: '')));

  setUp(() {
    repo = MockWalletRepository();
    history = StreamController<QuerySnapshot<Object?>>();
    when(() => repo.getWalletHistoryStream('me'))
        .thenAnswer((_) => history.stream);
  });

  tearDown(() => history.close().ignore());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('rows show at once, then gain their deal', () async {
    final pending = Completer<WalletDeal?>();
    when(() => repo.resolveDeal(any(), 'me')).thenAnswer((_) => pending.future);
    final cubit = WalletHistoryCubit(walletRepository: repo, userId: 'me');
    history.add(snapshot([entryDoc('w1', 'O1', -50)]));
    await settle();
    var e = (cubit.state as WalletHistoryLoaded).entries.single;
    expect(e.dealLoaded, isFalse);
    pending.complete(deal);
    await settle();
    e = (cubit.state as WalletHistoryLoaded).entries.single;
    expect(e.dealLoaded, isTrue);
    expect(e.deal?.partnerName, 'Bob');
    await cubit.close();
  });

  test('one lookup per deal, even with several rows and new snapshots',
      () async {
    when(() => repo.resolveDeal(any(), 'me')).thenAnswer((_) async => deal);
    final cubit = WalletHistoryCubit(walletRepository: repo, userId: 'me');
    history
        .add(snapshot([entryDoc('w1', 'O1', -50), entryDoc('w2', 'O1', 50)]));
    await settle();
    history.add(snapshot([
      entryDoc('w1', 'O1', -50),
      entryDoc('w2', 'O1', 50),
      entryDoc('w3', 'T9', 20)
    ]));
    await settle();
    verify(() => repo.resolveDeal(any(), 'me')).called(2); // O1 once, T9 once
    final entries = (cubit.state as WalletHistoryLoaded).entries;
    expect(entries.every((e) => e.dealLoaded), isTrue);
    await cubit.close();
  });

  test('a deal that cannot be found still finishes loading', () async {
    when(() => repo.resolveDeal(any(), 'me')).thenAnswer((_) async => null);
    final cubit = WalletHistoryCubit(walletRepository: repo, userId: 'me');
    history.add(snapshot([entryDoc('w1', 'GONE', -10)]));
    await settle();
    await settle();
    final e = (cubit.state as WalletHistoryLoaded).entries.single;
    expect(e.dealLoaded, isTrue);
    expect(e.deal, isNull);
    await cubit.close();
  });

  test('stream error shows the error state', () async {
    final cubit = WalletHistoryCubit(walletRepository: repo, userId: 'me');
    history.addError(Exception('index missing'));
    await settle();
    expect(cubit.state, isA<WalletHistoryError>());
    await cubit.close();
  });
}
