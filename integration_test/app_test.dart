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

/// Pumps until exactly one [finder] is left (e.g. a route transition that
/// briefly shows the screen twice has finished).
Future<void> waitForOne(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().length == 1) return;
  }
  throw TestFailure('Expected exactly one $finder');
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
  // Login currently shows MainLayout twice during the transition (the root
  // switches to it and LoginScreen also pushes one); wait until it's one.
  await waitForOne(tester, find.byType(MainLayout));
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
