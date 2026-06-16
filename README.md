# Lun'Avaritia

Mobile companion app for the Natsume ecosystem — Android.

Connects to Natsume Core (`/api/mobile/`) for chat and alerts.
Standalone mode (LunAcedia backend) planned for v2.

## Setup

1. Add `android/app/google-services.json` (Firebase project for FCM)
2. Copy `.env.example` → `.env` and fill server URL + token
3. `flutter pub get`
4. `flutter run`
