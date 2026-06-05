# Give & Take 🔄

A mobile application designed for a local item barter exchange system. Give & Take empowers users to trade items they no longer need for things they want, featuring a secure negotiation chat, a coin-based escrow system, and real-time system notifications.

## ✨ Key Features

* **Item Bartering & Exchange:** Browse local item listings and send trade offers to other users.
* **Smart Negotiation Chat:** Real-time messaging with an integrated "Offer Card" to accept, reject, or counter-offer directly within the chat interface.
* **Coin Escrow System:** Securely lock and refund coins used to offset value differences during item trades.
* **Real-time Notifications:** Categorized system alerts (Pending, Accepted, Rejected, Cancelled) to keep track of all active deals.
* **Review & Rating System:** Leave feedback and rate trading partners after a successful transaction to build community trust.

## 🛠️ Tech Stack

* **Frontend:** Flutter / Dart
* **Backend:** Firebase (Firestore, Firebase Authentication)
* **State Management & Real-time:** Cloud Firestore Streams

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Latest stable version)
* Dart SDK
* A Firebase project configured for iOS and Android

### Installation

1. Clone the repository:
```bash
   git clone [https://github.com/PattaraponKitcharoen/give_and_take.git](https://github.com/PattaraponKitcharoen/give_and_take.git)
```
#
2. Navigate to the project directory:
```bash
   cd give-and-take
```
#
3. Install dependencies:
```Bash
   flutter pub get
```
#
4. Set up Firebase:

  - Add your google-services.json to android/app/

  - Add your GoogleService-Info.plist to ios/Runner/
#
5. Run the app:
```Bash
   flutter run
```