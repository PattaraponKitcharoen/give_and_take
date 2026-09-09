import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/offer_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/offer_model.dart';
import 'offer_state.dart';

class OfferCubit extends Cubit<OfferState> {
  final OfferRepository _offerRepository;
  final UserRepository _userRepository;
  StreamSubscription? _incomingSubscription;
  StreamSubscription? _outgoingSubscription;

  OfferCubit({required OfferRepository offerRepository, required UserRepository userRepository}) 
      : _offerRepository = offerRepository, 
        _userRepository = userRepository,
        super(OfferInitial());

  void loadUserOffers(String userId) {
    emit(OfferLoading());
    
    List<OfferModel> incoming = [];
    List<OfferModel> outgoing = [];

    _incomingSubscription?.cancel();
    _incomingSubscription = _offerRepository.getIncomingOffers(userId).listen((offers) {
      incoming = offers;
      if (state is! OfferSubmitting) {
        emit(OfferLoaded(incomingOffers: incoming, outgoingOffers: outgoing));
      }
    }, onError: (error) {
      emit(OfferError(error.toString()));
    });

    _outgoingSubscription?.cancel();
    _outgoingSubscription = _offerRepository.getOutgoingOffers(userId).listen((offers) {
      outgoing = offers;
      if (state is! OfferSubmitting) {
        emit(OfferLoaded(incomingOffers: incoming, outgoingOffers: outgoing));
      }
    }, onError: (error) {
      emit(OfferError(error.toString()));
    });
  }

  Future<void> submitNewOffer({
    required OfferModel offer,
    required Map<String, dynamic> targetItemData,
    required Map<String, dynamic> offeredItemData,
    required String coinText,
  }) async {
    emit(OfferSubmitting());
    try {
      String roomId = await _offerRepository.createOfferAndChatRoom(
        offer: offer, 
        targetItemData: targetItemData, 
        offeredItemData: offeredItemData, 
        coinText: coinText,
      );
      emit(OfferSuccess(roomId)); 
    } catch (e) {
      debugPrint('Offer Error: $e');
      emit(OfferError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> cancelOffer(String offerId, String roomId, String currentUserId) async {
    emit(OfferSubmitting());
    try {
      final user = await _userRepository.getUser(currentUserId);
      final userName = user.name;
      await _offerRepository.cancelOffer(offerId, roomId, currentUserId, userName);
      emit(const OfferSuccess('ยกเลิกข้อเสนอเรียบร้อยแล้ว'));
    } catch (e) {
      emit(OfferError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> rejectOffer(String offerId, String roomId, String currentUserId) async {
    emit(OfferSubmitting());
    try {
      final user = await _userRepository.getUser(currentUserId);
      final userName = user.name;
      await _offerRepository.rejectOffer(offerId, roomId, currentUserId, userName);
      emit(const OfferSuccess('ปฏิเสธข้อเสนอเรียบร้อยแล้ว'));
    } catch (e) {
      emit(OfferError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> submitCounterOffer(String offerId, Map<String, dynamic> offerData, int amount, bool iWillPay, String roomId, String currentUserId) async {
    emit(OfferSubmitting());
    try {
      final user = await _userRepository.getUser(currentUserId);
      final userName = user.name;
      await _offerRepository.submitCounterOffer(offerId, offerData, amount, iWillPay, roomId, currentUserId, userName);
      emit(const OfferSuccess('ส่งข้อเสนอต่อรองเรียบร้อยแล้ว'));
    } catch (e) {
      emit(OfferError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> acceptOffer(String offerId, String roomId, String currentUserId) async {
    emit(OfferSubmitting());
    try {
      final user = await _userRepository.getUser(currentUserId);
      final userName = user.name;
      await _offerRepository.acceptOffer(offerId, roomId, currentUserId, userName);
      emit(const OfferSuccess('ตกลงรับข้อเสนอเรียบร้อยแล้ว!'));
    } catch (e) {
      emit(OfferError('เกิดข้อผิดพลาดในการรับข้อเสนอ: $e'));
    }
  }

  @override
  Future<void> close() {
    _incomingSubscription?.cancel();
    _outgoingSubscription?.cancel();
    return super.close();
  }
}
