import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';
import '../../models/listing_model.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserModel user;
  final List<ListingModel> userListings;
  final int tradeCount;
  final List<Map<String, dynamic>> enrichedReviews; 
  final bool isSendingVerification;
  final String? verificationMessage;
  final bool isVerificationError;

  const ProfileLoaded({
    required this.user,
    required this.userListings,
    this.tradeCount = 0,
    this.enrichedReviews = const [],
    this.isSendingVerification = false,
    this.verificationMessage,
    this.isVerificationError = false,
  });

  ProfileLoaded copyWith({
    UserModel? user,
    List<ListingModel>? userListings,
    int? tradeCount,
    List<Map<String, dynamic>>? enrichedReviews,
    bool? isSendingVerification,
    String? verificationMessage,
    bool? isVerificationError,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      userListings: userListings ?? this.userListings,
      tradeCount: tradeCount ?? this.tradeCount,
      enrichedReviews: enrichedReviews ?? this.enrichedReviews,
      isSendingVerification: isSendingVerification ?? this.isSendingVerification,
      verificationMessage: verificationMessage, 
      isVerificationError: isVerificationError ?? this.isVerificationError,
    );
  }

  @override
  List<Object?> get props => [
        user,
        userListings,
        tradeCount,
        enrichedReviews,
        isSendingVerification,
        verificationMessage,
        isVerificationError,
      ];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
