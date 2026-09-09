import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../models/user_model.dart';
import '../../models/listing_model.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/listing_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepository;
  final ListingRepository _listingRepository;
  final AuthRepository _authRepository;
  final String userId;

  StreamSubscription<UserModel>? _userSubscription;
  StreamSubscription<List<ListingModel>>? _listingsSubscription;

  UserModel? _latestUser;
  List<ListingModel>? _latestListings;
  bool _hasError = false;

  ProfileCubit({
    required UserRepository userRepository,
    required ListingRepository listingRepository,
    required AuthRepository authRepository,
    required this.userId,
  })  : _userRepository = userRepository,
        _listingRepository = listingRepository,
        _authRepository = authRepository,
        super(ProfileLoading()) {
    _initStreams();
  }

  void _initStreams() {
    emit(ProfileLoading());

    _userSubscription = _userRepository.getUserStream(userId).listen(
      (UserModel user) {
        if (_hasError) return;
        _latestUser = user;
        _emitIfReady();
      },
      onError: (error) {
        _hasError = true;
        emit(ProfileError(error.toString()));
      },
    );

    _listingsSubscription = _listingRepository.getUserListings(userId).listen(
      (List<ListingModel> listings) {
        if (_hasError) return;
        _latestListings = listings;
        _emitIfReady();
      },
      onError: (error) {
        _hasError = true;
        emit(ProfileError(error.toString()));
      },
    );
  }

  void _emitIfReady() async {
    if (_latestUser != null && _latestListings != null) {
      if (state is ProfileLoaded) {
        emit((state as ProfileLoaded).copyWith(
          user: _latestUser,
          userListings: _latestListings,
        ));
      } else {
        emit(ProfileLoading());
        try {
          int tradeCount = await _fetchTradeCount();
          List<Map<String, dynamic>> enrichedReviews = await _fetchEnrichedReviews();
          
          emit(ProfileLoaded(
            user: _latestUser!,
            userListings: _latestListings!,
            tradeCount: tradeCount,
            enrichedReviews: enrichedReviews,
          ));
        } catch (e) {
          emit(ProfileError(e.toString()));
        }
      }
    }
  }

  Future<int> _fetchTradeCount() async {
    return await _userRepository.getTradeCount(userId);
  }

  Future<List<Map<String, dynamic>>> _fetchEnrichedReviews() async {
    return await _userRepository.getEnrichedReviews(userId);
  }

  Future<void> sendVerificationEmail() async {
    if (state is! ProfileLoaded) return;
    final currentState = state as ProfileLoaded;
    
    emit(currentState.copyWith(
      isSendingVerification: true, 
      verificationMessage: null,
      isVerificationError: false
    ));
    
    try {
      if (_authRepository.currentUser != null) {
        await _authRepository.sendEmailVerification();
        emit(currentState.copyWith(
          isSendingVerification: false,
          verificationMessage: 'ส่งลิงก์ไปยัง ${_authRepository.currentUser!.email} แล้ว กรุณาเช็กอีเมลของคุณ',
          isVerificationError: false
        ));
      } else {
        throw Exception("User not logged in");
      }
    } catch (e) {
      String message = 'เกิดข้อผิดพลาดในการส่งอีเมล';
      if (e.toString().contains('too-many-requests') || e.toString().contains('ส่งอีเมลบ่อยเกินไป')) {
        message = 'ส่งอีเมลถี่เกินไป กรุณารอสักครู่';
      }
      emit(currentState.copyWith(
        isSendingVerification: false,
        verificationMessage: message,
        isVerificationError: true
      ));
    }
  }
  
  void clearVerificationMessage() {
    if (state is ProfileLoaded) {
      final currentState = state as ProfileLoaded;
      emit(ProfileLoaded(
        user: currentState.user,
        userListings: currentState.userListings,
        tradeCount: currentState.tradeCount,
        enrichedReviews: currentState.enrichedReviews,
        isSendingVerification: currentState.isSendingVerification,
        verificationMessage: null,
        isVerificationError: false,
      ));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    _listingsSubscription?.cancel();
    return super.close();
  }
}
