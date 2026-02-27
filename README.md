# Stranger Connect

Connect with strangers by shaking your phone. Built with Flutter and Firebase.

## Setup

### Prerequisites
- Flutter SDK (>=3.1.0)
- Node.js (>=20)
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

### Firebase Setup
1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Anonymous Authentication**
3. Enable **Cloud Firestore** (start in test mode)
4. Enable **Firebase Storage** (start in test mode)

### Connect Firebase to Flutter
```bash
firebase login
flutterfire configure --project=YOUR_PROJECT_ID
```
Then uncomment the Firebase options import in `lib/main.dart`.

### Install Dependencies
```bash
# Flutter dependencies
flutter pub get

# Cloud Functions dependencies
cd firebase/functions && npm install
```

### Deploy Cloud Functions
```bash
firebase deploy --only functions
```

### Deploy Firestore Rules & Indexes
```bash
firebase deploy --only firestore
```

### Run the App
```bash
flutter run
```

## Architecture

- **Flutter** - Cross-platform mobile app (iOS + Android)
- **Firebase Anonymous Auth** - No signup, auto-assigned identity
- **Cloud Firestore** - Real-time database for chat and user data
- **Cloud Functions** - Serverless matchmaking logic
- **Firebase Storage** - Profile picture storage
