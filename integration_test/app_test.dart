// End-to-end tests on a simulator against the Firebase emulators, with the
// accounts from functions/scripts/seedEmulator.js. Run (emulators up and
// seeded) with:
//
//   flutter test integration_test -d <simulator> \
//     --dart-define=USE_FIREBASE_EMULATOR=true
//
// CI does all of it: .github/workflows/e2e.yml
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/main.dart';
import 'package:give_and_take/screens/main_layout.dart';
import 'package:give_and_take/services/firebase_setup.dart';
import 'package:integration_test/integration_test.dart';

const password = 'test-password-123';
const bobsListing = 'หูฟังบลูทูธ JBL';
const alicesListing = 'เสื่อโยคะ หนา 6mm';

/// Pumps until [finder] shows up. The app has spinners and a carousel that
/// never settle, so pumpAndSettle can't be used.
Future<void> waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Taps [target] once it's on screen and tappable, then waits for [next].
Future<void> tapAndWait(WidgetTester tester, Finder target, Finder next) async {
  await waitFor(tester, target);
  await tester.ensureVisible(target.first);
  await waitFor(tester, target.hitTestable());
  await tester.tap(target.hitTestable().first);
  await waitFor(tester, next);
}

/// Fresh app, signed in as [email].
Future<void> startAs(WidgetTester tester, String email) async {
  await FirebaseAuth.instance.signOut();
  await tester.pumpWidget(const GiveAndTakeApp());
  await waitFor(tester, find.byKey(const Key('login-email')));
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.byKey(const Key('login-submit')));
  await waitFor(tester, find.byType(MainLayout));
  // Only the app's root opens MainLayout; the login screen used to push a
  // second one on top.
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(MainLayout), findsOneWidget);
}

Future<void> openBobsListing(WidgetTester tester) async {
  await waitFor(tester, find.text(bobsListing));
  await tapAndWait(tester, find.text(bobsListing), find.text('Make an Offer'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(useFirebaseEmulator, isTrue,
        reason: 'Run with --dart-define=USE_FIREBASE_EMULATOR=true');
    await configureFirebase();
  });

  testWidgets('Home shows other people\'s listings, not your own',
      (tester) async {
    await startAs(tester, 'alice@test.dev');
    await waitFor(tester, find.text(bobsListing));
    expect(find.text(alicesListing), findsNothing);
  });

  testWidgets('a banned account sees the ban notice with its reason',
      (tester) async {
    await startAs(tester, 'banned@test.dev');
    await waitFor(tester, find.text('บัญชีของคุณถูกระงับ'));
    expect(find.text('สแปม / ลงของซ้ำ'), findsOneWidget);
    expect(find.text('ระงับถาวร'), findsOneWidget);
  });

  testWidgets('a listing can be reported once', (tester) async {
    await startAs(tester, 'alice@test.dev');
    await openBobsListing(tester);

    await tapAndWait(tester, find.byIcon(Icons.more_horiz_rounded),
        find.text('รายงานประกาศนี้'));
    await tapAndWait(tester, find.text('รายงานประกาศนี้'),
        find.text('ของปลอม / ละเมิดลิขสิทธิ์'));
    await tester.tap(find.text('ของปลอม / ละเมิดลิขสิทธิ์'));
    await tester.pump();
    await tapAndWait(tester, find.text('ส่งรายงาน'), find.text('ส่งรายงานแล้ว'));
    await tapAndWait(tester, find.text('ปิด'), find.text('Make an Offer'));

    // Second time: the sheet says it's already been reported.
    await tapAndWait(tester, find.byIcon(Icons.more_horiz_rounded),
        find.text('รายงานประกาศนี้'));
    await tapAndWait(tester, find.text('รายงานประกาศนี้'),
        find.text('คุณรายงานไปแล้ว'));
  });

  testWidgets('deleting an account removes it and signs out', (tester) async {
    await startAs(tester, 'carol@test.dev');
    await tapAndWait(tester, find.bySemanticsLabel('โปรไฟล์'),
        find.byIcon(Icons.more_horiz_rounded));
    await tapAndWait(tester, find.byIcon(Icons.more_horiz_rounded),
        find.text('ลบบัญชี'));
    await tapAndWait(tester, find.text('ลบบัญชี'),
        find.byKey(const Key('delete-confirm')));

    await tester.enterText(find.byKey(const Key('delete-password')), password);
    await tester.enterText(find.byKey(const Key('delete-confirm')), 'ลบบัญชี');
    await tester.pump();
    await tapAndWait(tester, find.byKey(const Key('delete-submit')),
        find.byKey(const Key('login-email')));
    // Shown on both scaffolds while the delete screen pops away.
    expect(find.text('ลบบัญชีเรียบร้อยแล้ว'), findsWidgets);

    // Can't sign in any more.
    await expectLater(
        FirebaseAuth.instance.signInWithEmailAndPassword(
            email: 'carol@test.dev', password: password),
        throwsA(isA<FirebaseAuthException>()));

    // As someone else: her profile is a tombstone, her listing is gone.
    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'alice@test.dev', password: password);
    final db = FirebaseFirestore.instance;
    final carol = (await db.doc('users/carol').get()).data()!;
    expect(carol['status'], 'deleted');
    expect(carol['name'], 'ผู้ใช้ที่ลบบัญชีแล้ว');
    expect(carol.containsKey('email'), isFalse);
    expect((await db.doc('listings/carol-lamp').get()).exists, isFalse);
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('making an offer creates it and opens the chat', (tester) async {
    await startAs(tester, 'alice@test.dev');
    await openBobsListing(tester);

    await tapAndWait(tester, find.text('Make an Offer'),
        find.text('Confirm & Start Chat'));
    // The sheet preselects one of Alice's items once they've loaded.
    await waitFor(tester, find.textContaining('เสื่อโยคะ'));
    await tapAndWait(tester, find.text('Confirm & Start Chat'),
        find.byIcon(Icons.more_vert_rounded)); // the chat's report menu

    final offers = await FirebaseFirestore.instance
        .collection('offers')
        .where('sender_id', isEqualTo: 'alice')
        .get();
    expect(offers.docs, hasLength(1));
    final offer = offers.docs.single.data();
    expect(offer['target_listing_id'], 'bob-headphones');
    expect(offer['offered_listing_id'], 'alice-mat');
    expect(offer['status'], 'pending');
  });
}
