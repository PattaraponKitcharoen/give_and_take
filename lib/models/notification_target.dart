/// Where tapping a push notification takes the user.
enum NotificationDestination {
  /// The chat for an offer (or the chat list if the room can't be found).
  offerChat,

  /// The "แลกตามความต้องการ" match screen.
  matches,

  /// My Listings, e.g. after one of them was banned.
  myListings,
}

/// A tapped notification, parsed from the FCM `data` payload the Cloud
/// Functions send (`type` plus ids).
class NotificationTarget {
  final NotificationDestination destination;
  final String? offerId;

  const NotificationTarget(this.destination, {this.offerId});

  /// Null for types with nothing to open: `account_banned` (MainLayout
  /// already shows the ban screen) and `report_reviewed`.
  static NotificationTarget? fromData(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'new_offer':
        final offerId = data['offer_id'];
        return NotificationTarget(NotificationDestination.offerChat,
            offerId: offerId is String && offerId.isNotEmpty ? offerId : null);
      case 'new_match':
        return const NotificationTarget(NotificationDestination.matches);
      case 'listing_banned':
        return const NotificationTarget(NotificationDestination.myListings);
      default:
        return null;
    }
  }
}
