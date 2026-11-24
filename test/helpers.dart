// Builders for test data, so each test only spells out what it cares about.
import 'package:give_and_take/models/listing_model.dart';
import 'package:give_and_take/models/match_model.dart';
import 'package:give_and_take/models/place_location.dart';
import 'package:give_and_take/models/user_model.dart';

ListingModel listing(
  String id, {
  String owner = 'other',
  String status = 'active',
  String category = 'อื่นๆ (Miscellaneous)',
  int coins = 100,
  DateTime? createdAt,
  PlaceLocation? location,
  String? title,
  String description = '',
}) =>
    ListingModel(
      listingId: id,
      type: 'item',
      status: status,
      category: category,
      ownerId: owner,
      ownerName: 'Owner',
      ownerProfileImg: '',
      ownerRatingScores: 0,
      title: title ?? 'Item $id',
      description: description,
      condition: 'มือสองสภาพดี',
      estimatedCoins: coins,
      thumbnailUrl: '',
      images: const [],
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      location: location,
    );

UserModel user(String uid,
        {List<String> wishlist = const [],
        String status = 'active',
        DateTime? bannedUntil}) =>
    UserModel(
      uid: uid,
      name: 'User $uid',
      email: '$uid@test.dev',
      tel: '',
      bio: '',
      status: status,
      profileImgUrl: '',
      coinsBalance: 1000,
      isEmailVerified: true,
      isPhoneVerified: false,
      wishlist: wishlist,
      bannedUntil: bannedUntil,
    );

MatchModel match(String id,
        {String mine = 'M',
        String theirs = 'T',
        double score = 0.8,
        bool seen = false}) =>
    MatchModel(
      id: id,
      partnerId: 'partner',
      myListingId: mine,
      theirListingId: theirs,
      myWantText: 'หูฟัง',
      theirWantText: 'เสื่อโยคะ',
      score: score,
      seen: seen,
    );
