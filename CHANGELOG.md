# Changelog

## [1.1.0] — 2026-06-16

### Features

- Standalone mode: `BACKEND_MODE=natsume|lunacedia` selectable from settings screen
- `BackendClient` abstract interface — decouples providers from backend implementation
- `LunAcediaClient` — connects to LunAcedia `/api/chat`, `/api/events`, `/api/devices/push-token`
- `ApiConfig.backendMode` persisted in SharedPreferences
- CI: `flutter analyze` + `flutter build apk --debug` on every push/PR
- Auto-tag + GitHub Release + debug APK artifact on version bump

## [1.0.0] — 2026-06-16

### Features

- Chat screen with Natsume status bar (mood / energy / affinity)
- Alert feed with source filters (email, calendar, tasks) and priority filter (urgent)
- FCM push notifications — foreground + background handlers
- `ApiService` connecting to Natsume Core `/api/mobile/*`
- Material 3 theme (seed `#7C5CBF`), SharedPreferences config
