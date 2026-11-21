import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/notification/notification_tap_cubit.dart';
import 'package:give_and_take/models/notification_target.dart';

void main() {
  group('NotificationTarget.fromData', () {
    test('a new offer opens its chat', () {
      final target = NotificationTarget.fromData(
          {'type': 'new_offer', 'offer_id': 'o1', 'listing_id': 'l1'})!;
      expect(target.destination, NotificationDestination.offerChat);
      expect(target.offerId, 'o1');
    });

    test('a new offer without an id still opens the chats', () {
      final target = NotificationTarget.fromData({'type': 'new_offer'})!;
      expect(target.destination, NotificationDestination.offerChat);
      expect(target.offerId, isNull);
    });

    test('a match opens the match screen, a banned listing My Listings', () {
      expect(
          NotificationTarget.fromData({'type': 'new_match', 'match_id': 'm'})!
              .destination,
          NotificationDestination.matches);
      expect(
          NotificationTarget.fromData(
                  {'type': 'listing_banned', 'listing_id': 'l'})!
              .destination,
          NotificationDestination.myListings);
    });

    test('types with nothing to open, or unknown ones, give null', () {
      expect(NotificationTarget.fromData({'type': 'account_banned'}), isNull);
      expect(NotificationTarget.fromData({'type': 'report_reviewed'}), isNull);
      expect(NotificationTarget.fromData({'type': 'something_new'}), isNull);
      expect(NotificationTarget.fromData({}), isNull);
    });
  });

  group('NotificationTapCubit', () {
    const offer =
        NotificationTarget(NotificationDestination.offerChat, offerId: 'o1');
    const matches = NotificationTarget(NotificationDestination.matches);
    late StreamController<NotificationTarget> taps;

    setUp(() => taps = StreamController<NotificationTarget>());
    tearDown(() => taps.close());

    test('starts with the notification that launched the app', () {
      final cubit =
          NotificationTapCubit(taps: taps.stream, launchTarget: offer);
      expect(cubit.state, same(offer));
      cubit.close();
    });

    blocTest<NotificationTapCubit, NotificationTarget?>(
      'holds each tap until it is handled',
      build: () => NotificationTapCubit(taps: taps.stream),
      act: (cubit) async {
        taps.add(matches);
        await Future<void>.delayed(Duration.zero);
        cubit.handled();
        taps.add(offer);
      },
      expect: () => [same(matches), isNull, same(offer)],
    );
  });
}
