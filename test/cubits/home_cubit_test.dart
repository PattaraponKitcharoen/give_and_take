import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:give_and_take/cubits/home/home_cubit.dart';
import 'package:give_and_take/cubits/home/home_state.dart';
import 'package:give_and_take/models/listing_model.dart';
import 'package:give_and_take/models/place_location.dart';
import 'package:give_and_take/models/user_model.dart';
import 'package:give_and_take/repositories/listing_repository.dart';
import 'package:give_and_take/repositories/user_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class MockListingRepository extends Mock implements ListingRepository {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockListingRepository listings;
  late MockUserRepository users;
  late StreamController<List<ListingModel>> items;
  late StreamController<UserModel> me;

  const hatYai = PlaceLocation(latitude: 7.01, longitude: 100.47);
  const songkhla = PlaceLocation(latitude: 7.20, longitude: 100.60);

  setUp(() {
    listings = MockListingRepository();
    users = MockUserRepository();
    items = StreamController<List<ListingModel>>();
    me = StreamController<UserModel>();
    when(() => listings.getActiveItemsStream()).thenAnswer((_) => items.stream);
    when(() => users.getUserStream('me')).thenAnswer((_) => me.stream);
  });

  tearDown(() async {
    await items.close();
    await me.close();
  });

  /// A loaded cubit with [list] on the market and [wishlist] for "me".
  Future<HomeCubit> loaded(List<ListingModel> list,
      {List<String> wishlist = const []}) async {
    final cubit = HomeCubit(
        listingRepository: listings, userRepository: users, currentUserId: 'me')
      ..fetchItems();
    items.add(list);
    me.add(user('me', wishlist: wishlist));
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  List<String> ids(HomeCubit c) =>
      (c.state as HomeLoaded).filteredItems.map((l) => l.listingId).toList();

  test('loads once both the market and the user arrive, without own items',
      () async {
    final cubit = await loaded([
      listing('A', createdAt: DateTime(2026, 1, 1)),
      listing('MINE', owner: 'me'),
      listing('B', createdAt: DateTime(2026, 2, 1)),
    ]);
    expect(cubit.state, isA<HomeLoaded>());
    expect(ids(cubit), ['B', 'A']); // newest first, own item hidden
    await cubit.close();
  });

  test('category filter, and back to All', () async {
    final cubit = await loaded([
      listing('A', category: 'เกม & ของเล่น'),
      listing('B', category: 'หนังสือ & เครื่องเขียน'),
    ]);
    cubit.toggleCategory('เกม & ของเล่น');
    expect(ids(cubit), ['A']);
    cubit.toggleCategory('เกม & ของเล่น'); // last one off -> All
    expect((cubit.state as HomeLoaded).selectedCategories, ['All']);
    expect(ids(cubit).toSet(), {'A', 'B'});
    await cubit.close();
  });

  test('wishlist filter shows only hearted items', () async {
    final cubit =
        await loaded([listing('A'), listing('B')], wishlist: const ['B']);
    cubit.toggleCategory('Wishlists');
    expect(ids(cubit), ['B']);
    await cubit.close();
  });

  test('sort by coins both ways', () async {
    final cubit = await loaded([
      listing('A', coins: 300),
      listing('B', coins: 100),
      listing('C', coins: 200)
    ]);
    cubit.updateSort('coins_asc');
    expect(ids(cubit), ['B', 'C', 'A']);
    cubit.updateSort('coins_desc');
    expect(ids(cubit), ['A', 'C', 'B']);
    await cubit.close();
  });

  test('nearest: closest first, listings without a location last', () async {
    final cubit = await loaded([
      listing('FAR', location: songkhla),
      listing('NONE'),
      listing('NEAR', location: hatYai),
    ]);
    cubit.setUserLocation(hatYai);
    cubit.updateSort('nearest');
    expect(ids(cubit), ['NEAR', 'FAR', 'NONE']);
    expect((cubit.state as HomeLoaded).userLocation, hatYai);
    await cubit.close();
  });

  test('a new user location re-sorts while "nearest" is on', () async {
    final cubit = await loaded([
      listing('HY', location: hatYai),
      listing('SK', location: songkhla),
    ]);
    cubit.setUserLocation(hatYai);
    cubit.updateSort('nearest');
    expect(ids(cubit).first, 'HY');
    cubit.setUserLocation(songkhla);
    expect(ids(cubit).first, 'SK');
    await cubit.close();
  });

  test('toggleWishlist flips the heart at once and saves', () async {
    when(() => users.toggleWishlist('me', 'A', false)).thenAnswer((_) async {});
    final cubit = await loaded([listing('A')]);
    final pending = cubit.toggleWishlist(listing('A'));
    expect((cubit.state as HomeLoaded).wishlist, ['A']); // optimistic
    await pending;
    verify(() => users.toggleWishlist('me', 'A', false)).called(1);
    await cubit.close();
  });

  test('toggleWishlist rolls back and rethrows when the save fails', () async {
    when(() => users.toggleWishlist('me', 'A', false))
        .thenThrow(Exception('offline'));
    final cubit = await loaded([listing('A')]);
    await expectLater(cubit.toggleWishlist(listing('A')), throwsException);
    expect((cubit.state as HomeLoaded).wishlist, isEmpty);
    await cubit.close();
  });

  test('a stream error shows HomeError', () async {
    final cubit = HomeCubit(
        listingRepository: listings, userRepository: users, currentUserId: 'me')
      ..fetchItems();
    items.addError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<HomeError>());
    await cubit.close();
  });
}
