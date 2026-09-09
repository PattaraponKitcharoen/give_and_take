import 'package:equatable/equatable.dart';
import '../../models/transaction_model.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();
  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final TransactionModel currentTransaction;

  const TransactionLoaded(this.currentTransaction);

  @override
  List<Object?> get props => [currentTransaction];
}

class TransactionSubmitting extends TransactionState {}

class TransactionSuccess extends TransactionState {
  final String message;
  final bool isCompleted;

  const TransactionSuccess(this.message, {this.isCompleted = false});

  @override
  List<Object?> get props => [message, isCompleted];
}

class TransactionError extends TransactionState {
  final String error;

  const TransactionError(this.error);

  @override
  List<Object?> get props => [error];
}
