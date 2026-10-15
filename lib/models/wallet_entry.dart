import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The deal a wallet movement belongs to, resolved from the entry's
/// reference_id (an offer id for escrow locks, a transaction id for
/// releases/refunds) so the history can say what the coins were for.
class WalletDeal extends Equatable {
  final String offerId;
  final String myItemTitle;
  final String theirItemTitle;
  final String theirItemThumbnail;
  final String partnerName;

  /// Chat room of the deal, if the user is still a member of it.
  final String? roomId;

  const WalletDeal({
    required this.offerId,
    required this.myItemTitle,
    required this.theirItemTitle,
    required this.theirItemThumbnail,
    required this.partnerName,
    this.roomId,
  });

  @override
  List<Object?> get props => [
        offerId,
        myItemTitle,
        theirItemTitle,
        theirItemThumbnail,
        partnerName,
        roomId
      ];
}

/// One row of `wallet_transactions`, as written by the trade Cloud Functions.
class WalletEntry extends Equatable {
  final String id;
  final int amount;
  final String type; // escrow_lock | escrow_release | refund
  final String description;
  final String referenceId;
  final DateTime? createdAt;
  final WalletDeal? deal;

  /// True once the deal lookup has finished (deal may still be null when
  /// it couldn't be found).
  final bool dealLoaded;

  const WalletEntry({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.referenceId,
    this.createdAt,
    this.deal,
    this.dealLoaded = false,
  });

  factory WalletEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletEntry(
      id: doc.id,
      amount: data['amount'] ?? 0,
      type: data['type'] ?? '',
      description: data['description'] ?? 'ทำรายการ',
      referenceId: data['reference_id'] ?? '',
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  WalletEntry withDeal(WalletDeal? deal, {required bool loaded}) => WalletEntry(
        id: id,
        amount: amount,
        type: type,
        description: description,
        referenceId: referenceId,
        createdAt: createdAt,
        deal: deal,
        dealLoaded: loaded,
      );

  @override
  List<Object?> get props =>
      [id, amount, type, description, referenceId, createdAt, deal, dealLoaded];
}
