# Lun'Avaritia

Mobile companion app for the Lun ecosystem — Android.

Supports two backend modes selectable from the settings screen:

| Mode | Backend | Endpoints |
|---|---|---|
| **Natsume** (default) | Natsume Core | `/api/mobile/chat`, `/api/mobile/alerts`, `/api/mobile/status` |
| **LunAcedia** | LunAcedia server | `/api/chat`, `/api/events`, `/api/devices/push-token` |

## Features

- **Chat** — conversation with Natsume (or AI butler via LunAcedia)
- **Alert feed** — alerts from Natsume or events from LunAcedia, with filters (urgent, email, calendar, tasks)
- **Push notifications** — FCM integration for real-time alerts
- **Settings** — backend mode picker, server URL, token

## Setup

1. Add `android/app/google-services.json` (Firebase project for FCM)
2. `flutter pub get`
3. `flutter run`
4. Open Settings → set backend mode, server URL, and token

## Backend mode

The mode is persisted in `SharedPreferences` and applied at next app launch.

- **Natsume mode** — connects to Natsume Core (default port `3333`). Requires `ADMIN_SECRET`.
- **LunAcedia mode** — connects to LunAcedia HTTP API (default port `4001`). Requires `ACEDIA_SECRET` (leave empty if auth is disabled). `markRead` / `markAllRead` are client-side only — LunAcedia has no server-side read state.

## Architecture

```
BackendClient (abstract)
├── ApiService      → Natsume Core  /api/mobile/*
└── LunAcediaClient → LunAcedia     /api/chat, /api/events, /api/devices/push-token
```

Providers (`ChatProvider`, `AlertProvider`) and `PushService` depend only on `BackendClient` — swapping backend requires no provider changes.
