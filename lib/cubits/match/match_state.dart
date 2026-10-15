import 'package:equatable/equatable.dart';
import '../../models/match_model.dart';

class MatchState extends Equatable {
  final bool loading;
  final bool enabled;
  final bool rescanning;
  final List<WantModel> wants;
  final List<MatchModel> matches; // ready to show: both listings resolved
  final String? message; // one-off error/info for a SnackBar

  const MatchState({
    this.loading = true,
    this.enabled = true,
    this.rescanning = false,
    this.wants = const [],
    this.matches = const [],
    this.message,
  });

  MatchState copyWith({
    bool? loading,
    bool? enabled,
    bool? rescanning,
    List<WantModel>? wants,
    List<MatchModel>? matches,
    String? message,
  }) =>
      MatchState(
        loading: loading ?? this.loading,
        enabled: enabled ?? this.enabled,
        rescanning: rescanning ?? this.rescanning,
        wants: wants ?? this.wants,
        matches: matches ?? this.matches,
        message: message,
      );

  @override
  List<Object?> get props => [loading, enabled, rescanning, wants, matches, message];
}
