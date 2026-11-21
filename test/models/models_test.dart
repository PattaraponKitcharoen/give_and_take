import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/models/listing_model.dart';
import 'package:give_and_take/models/match_model.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

// Firestore marks its snapshot types @sealed; faking them is fine in tests.
// ignore: subtype_of_sealed_class
class MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('UserModel.isBanned (same rule as firestore.rules)', () {
    test('active user', () => expect(user('u').isBanned, isFalse));
    test('permanent ban',
        () => expect(user('u', status: 'banned').isBanned, isTrue));
    test('temporary ban still running', () {
      final u = user('u',
          status: 'banned',
          bannedUntil: DateTime.now().add(const Duration(days: 1)));
      expect(u.isBanned, isTrue);
    });
    test('temporary ban already over, before the hourly job clears it', () {
      final u = user('u',
          status: 'banned',
          bannedUntil: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(u.isBanned, isFalse);
    });
  });

  group('ListingModel', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
          'type': 'item',
          'status': 'banned',
          'owner_id': 'B',
          'title': 'หูฟัง',
          'estimated_coins': 300,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
          ...extra,
        };

    test('reads pickup location and moderation fields', () {
      final l = ListingModel.fromJson(
          json({
            'location': {
              'latitude': 7.01,
              'longitude': 100.47,
              'district': 'หาดใหญ่',
              'province': 'สงขลา'
            },
            'ban_reason': 'ของปลอม',
            'hidden_by_user_ban': true,
          }),
          'L1');
      expect(l.location?.displayName, 'หาดใหญ่, สงขลา');
      expect(l.banReason, 'ของปลอม');
      expect(l.hiddenByUserBan, isTrue);
    });

    test('old listings without those fields still load', () {
      final l = ListingModel.fromJson(json({}), 'L1');
      expect(l.location, isNull);
      expect(l.banReason, '');
      expect(l.hiddenByUserBan, isFalse);
    });

    test('toJson never writes the moderation fields back', () {
      final l = ListingModel.fromJson(
          json({'ban_reason': 'x', 'hidden_by_user_ban': true}), 'L1');
      final out = l.toJson();
      expect(out.containsKey('ban_reason'), isFalse);
      expect(out.containsKey('hidden_by_user_ban'), isFalse);
    });

    test('copyWith keeps location and moderation fields', () {
      final l = ListingModel.fromJson(
          json({
            'location': {'latitude': 7.01, 'longitude': 100.47},
            'ban_reason': 'x',
          }),
          'L1');
      final c = l.copyWith(title: 'ใหม่');
      expect(c.location?.latitude, 7.01);
      expect(c.banReason, 'x');
    });
  });

  group('MatchModel.fromDoc', () {
    MockDocSnapshot doc(Map<String, dynamic> data) {
      final d = MockDocSnapshot();
      when(() => d.id).thenReturn('LA__LB');
      when(() => d.data()).thenReturn(data);
      return d;
    }

    final data = {
      'members': ['A', 'B'],
      'sides': {
        'A': {
          'give_listing_id': 'LA',
          'get_listing_id': 'LB',
          'want_text': 'หูฟัง'
        },
        'B': {
          'give_listing_id': 'LB',
          'get_listing_id': 'LA',
          'want_text': 'เสื่อโยคะ'
        },
      },
      'score': 0.83,
      'seen_by': ['B'],
    };

    test('seen from A', () {
      final m = MatchModel.fromDoc(doc(data), 'A')!;
      expect(m.partnerId, 'B');
      expect(m.myListingId, 'LA');
      expect(m.theirListingId, 'LB');
      expect(m.myWantText, 'หูฟัง');
      expect(m.theirWantText, 'เสื่อโยคะ');
      expect(m.seen, isFalse);
    });

    test('seen from B', () {
      final m = MatchModel.fromDoc(doc(data), 'B')!;
      expect(m.myListingId, 'LB');
      expect(m.seen, isTrue);
    });

    test('a user with no side gets nothing', () {
      expect(MatchModel.fromDoc(doc(data), 'C'), isNull);
    });
  });
}
