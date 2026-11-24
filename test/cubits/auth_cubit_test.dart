import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/auth/auth_cubit.dart';
import 'package:give_and_take/cubits/auth/auth_state.dart';
import 'package:give_and_take/models/user_model.dart';
import 'package:give_and_take/repositories/auth_repository.dart';
import 'package:give_and_take/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart' as h;

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository auth;
  late MockUserRepository users;

  setUpAll(() => registerFallbackValue(h.user('fallback')));

  MockUserCredential signedIn(
      {String uid = 'u1', String? name, String? email = 'x@privaterelay.appleid.com'}) {
    final user = MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.displayName).thenReturn(name);
    when(() => user.email).thenReturn(email);
    when(() => user.photoURL).thenReturn(null);
    final credential = MockUserCredential();
    when(() => credential.user).thenReturn(user);
    return credential;
  }

  setUp(() {
    auth = MockAuthRepository();
    users = MockUserRepository();
    // No auth events: the tests drive sign-in directly.
    when(() => auth.user).thenAnswer((_) => const Stream.empty());
    when(() => users.userExists(any())).thenAnswer((_) async => false);
    when(() => users.createUser(any())).thenAnswer((_) async {});
  });

  AuthCubit build() =>
      AuthCubit(authRepository: auth, userRepository: users);

  UserModel created() =>
      verify(() => users.createUser(captureAny())).captured.single as UserModel;

  blocTest<AuthCubit, AuthState>(
    'first Apple sign-in without a name: profile with the fallback name',
    setUp: () =>
        when(() => auth.signInWithApple()).thenAnswer((_) async => signedIn()),
    build: build,
    act: (cubit) => cubit.signInWithApple(),
    verify: (_) {
      final u = created();
      expect(u.name, 'ผู้ใช้ Apple');
      expect(u.coinsBalance, 1000);
      expect(u.isEmailVerified, isTrue);
      expect(u.email, 'x@privaterelay.appleid.com');
    },
  );

  blocTest<AuthCubit, AuthState>(
    'Apple shares a name: the profile uses it',
    setUp: () => when(() => auth.signInWithApple())
        .thenAnswer((_) async => signedIn(name: 'Somchai Jaidee')),
    build: build,
    act: (cubit) => cubit.signInWithApple(),
    verify: (_) => expect(created().name, 'Somchai Jaidee'),
  );

  blocTest<AuthCubit, AuthState>(
    'returning Apple user: no new profile',
    setUp: () {
      when(() => auth.signInWithApple()).thenAnswer((_) async => signedIn());
      when(() => users.userExists('u1')).thenAnswer((_) async => true);
    },
    build: build,
    act: (cubit) => cubit.signInWithApple(),
    verify: (_) => verifyNever(() => users.createUser(any())),
  );

  blocTest<AuthCubit, AuthState>(
    'closing the Apple sheet: back to signed out, no error',
    setUp: () =>
        when(() => auth.signInWithApple()).thenAnswer((_) async => null),
    build: build,
    act: (cubit) => cubit.signInWithApple(),
    // Starts in AuthLoading (waiting for the first auth event).
    expect: () => [isA<Unauthenticated>()],
  );

  blocTest<AuthCubit, AuthState>(
    'an Apple failure is reported with its code',
    setUp: () => when(() => auth.signInWithApple()).thenAnswer(
        (_) async => throw FirebaseAuthException(code: 'invalid-credential')),
    build: build,
    act: (cubit) => cubit.signInWithApple(),
    expect: () => [
      isA<AuthError>().having((s) => s.message, 'message',
          'เข้าสู่ระบบด้วย Apple ไม่สำเร็จ (invalid-credential)'),
      isA<Unauthenticated>(),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'Google still falls back to the email name',
    setUp: () => when(() => auth.signInWithGoogle())
        .thenAnswer((_) async => signedIn(email: 'somchai@gmail.com')),
    build: build,
    act: (cubit) => cubit.signInWithGoogle(),
    verify: (_) => expect(created().name, 'somchai'),
  );
}
