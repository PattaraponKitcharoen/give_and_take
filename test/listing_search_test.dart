import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/utils/listing_search.dart';

import 'helpers.dart';

void main() {
  final mat = listing('mat',
      title: 'เสื่อโยคะ หนา 6mm',
      category: 'กีฬา & กิจกรรมกลางแจ้ง',
      description: 'ใช้ไม่กี่ครั้ง มีถุงใส่',
      createdAt: DateTime(2026, 1, 1));
  final bag = listing('bag',
      title: 'กระเป๋าผ้า',
      category: 'แฟชั่น & เครื่องแต่งกาย',
      description: 'ใส่เสื่อโยคะได้พอดี',
      createdAt: DateTime(2026, 3, 1));
  final headphones = listing('hp',
      title: 'หูฟังบลูทูธ JBL',
      category: 'อุปกรณ์ไอที & แก็ดเจ็ต',
      description: 'Bluetooth 5.0 แบตอึด',
      createdAt: DateTime(2026, 2, 1));
  final all = [mat, bag, headphones];

  List<String> ids(String q, {String? exclude}) =>
      searchListings(all, q, excludeOwnerId: exclude)
          .map((l) => l.listingId)
          .toList();

  test('finds words that are only in the description', () {
    expect(ids('ถุง'), ['mat']);
    expect(ids('bluetooth'), ['hp']);
  });

  test('title matches come before description-only matches', () {
    // "เสื่อโยคะ" is mat's title but only bag's description.
    expect(ids('เสื่อโยคะ'), ['mat', 'bag']);
  });

  test('matches the category', () {
    expect(ids('แก็ดเจ็ต'), ['hp']);
  });

  test('ignores case and extra spaces', () {
    expect(ids('  JBL  '), ['hp']);
    expect(ids('jbl'), ['hp']);
  });

  test('every word must appear somewhere (title, category or description)',
      () {
    expect(ids('jbl แบต'), ['hp']);
    expect(ids('jbl เสื่อ'), isEmpty);
  });

  test('same rank: newest first', () {
    // Both only in the description... "ใส่" is in mat's and bag's.
    expect(ids('ใส่'), ['bag', 'mat']);
  });

  test("leaves out the searcher's own listings and empty queries", () {
    expect(ids('เสื่อโยคะ', exclude: 'other'), isEmpty);
    expect(ids('   '), isEmpty);
  });
}
