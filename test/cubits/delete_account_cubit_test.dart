import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/account/delete_account_cubit.dart';
import 'package:give_and_take/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.reauthProvider).thenReturn('password');
    when(() => auth.deleteAccount()).thenAnswer((_) async {});
  });

  DeleteAccountCubit build() => DeleteAccountCubit(authRepository: auth);
  const working = DeleteAccountState(DeleteAccountStep.working);

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'signs in again with the password, then deletes',
    setUp: () => when(() => auth.reauthenticate(password: 'pw'))
        .thenAnswer((_) async => true),
    build: build,
    act: (cubit) => cubit.delete(password: 'pw'),
    expect: () => [working, const DeleteAccountState(DeleteAccountStep.done)],
    verify: (_) => verify(() => auth.deleteAccount()).called(1),
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'closing the Google picker goes back to the form without deleting',
    setUp: () => when(() => auth.reauthenticate(password: null))
        .thenAnswer((_) async => false),
    build: build,
    act: (cubit) => cubit.delete(),
    expect: () => [working, const DeleteAccountState(DeleteAccountStep.idle)],
    verify: (_) => verifyNever(() => auth.deleteAccount()),
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'a wrong password says so and deletes nothing',
    setUp: () => when(() => auth.reauthenticate(password: 'bad')).thenAnswer(
        (_) async => throw FirebaseAuthException(code: 'invalid-credential')),
    build: build,
    act: (cubit) => cubit.delete(password: 'bad'),
    expect: () => [
      working,
      const DeleteAccountState(DeleteAccountStep.failed, 'รหัสผ่านไม่ถูกต้อง'),
    ],
    verify: (_) => verifyNever(() => auth.deleteAccount()),
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'a trade in progress: tells how many need finishing first',
    setUp: () {
      when(() => auth.reauthenticate(password: 'pw'))
          .thenAnswer((_) async => true);
      when(() => auth.deleteAccount()).thenAnswer((_) async =>
          throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'active-trades',
              details: {'count': 2}));
    },
    build: build,
    act: (cubit) => cubit.delete(password: 'pw'),
    expect: () => [
      working,
      isA<DeleteAccountState>()
          .having((s) => s.step, 'step', DeleteAccountStep.failed)
          .having((s) => s.message, 'message', contains('2 รายการ')),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'any other failure gives a retry message',
    setUp: () => when(() => auth.reauthenticate(password: 'pw'))
        .thenAnswer((_) async => throw Exception('boom')),
    build: build,
    act: (cubit) => cubit.delete(password: 'pw'),
    expect: () => [
      working,
      const DeleteAccountState(
          DeleteAccountStep.failed, 'ลบบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
    ],
  );

  test('exposes how the account signs in', () {
    expect(build().provider, 'password');
  });
}
