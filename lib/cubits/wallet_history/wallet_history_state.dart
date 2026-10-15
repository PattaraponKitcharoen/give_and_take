import 'package:equatable/equatable.dart';
import '../../models/wallet_entry.dart';

abstract class WalletHistoryState extends Equatable {
  const WalletHistoryState();
  @override
  List<Object?> get props => [];
}

class WalletHistoryLoading extends WalletHistoryState {}

class WalletHistoryError extends WalletHistoryState {
  final String message;
  const WalletHistoryError(this.message);
  @override
  List<Object?> get props => [message];
}

class WalletHistoryLoaded extends WalletHistoryState {
  final List<WalletEntry> entries;
  const WalletHistoryLoaded(this.entries);
  @override
  List<Object?> get props => [entries];
}
