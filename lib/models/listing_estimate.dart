import 'package:equatable/equatable.dart';

/// What the AI listing assistant (Cloud Function `estimateListing`)
/// suggests for a new listing from its photos. Only a suggestion: it fills
/// the form, and the owner can change anything before posting.
class ListingEstimate extends Equatable {
  final String title;
  final String description;
  final String category;
  final String condition;
  final int coinsMin;
  final int coinsMax;
  final int coinsSuggested;
  final String reason;

  /// 'low' | 'medium' | 'high'
  final String confidence;

  const ListingEstimate({
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.coinsMin,
    required this.coinsMax,
    required this.coinsSuggested,
    required this.reason,
    required this.confidence,
  });

  factory ListingEstimate.fromJson(Map<String, dynamic> json) {
    int toInt(Object? v) => v is num ? v.round() : 0;
    return ListingEstimate(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      coinsMin: toInt(json['coins_min']),
      coinsMax: toInt(json['coins_max']),
      coinsSuggested: toInt(json['coins_suggested']),
      reason: json['reason'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'low',
    );
  }

  bool get hasPrice => coinsSuggested > 0;

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        condition,
        coinsMin,
        coinsMax,
        coinsSuggested,
        reason,
        confidence,
      ];
}
