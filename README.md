<div align="center">

# ◆ Lun'Avaritia

[![Version](https://img.shields.io/github/v/tag/CrOliX-AltF4/LunAvaritia?style=flat-square&color=C8A415&label=version)](https://github.com/CrOliX-AltF4/LunAvaritia/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/CrOliX-AltF4/LunAvaritia/ci.yml?style=flat-square&label=CI)](https://github.com/CrOliX-AltF4/LunAvaritia/actions)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.22-555555?style=flat-square)](.)
[![License](https://img.shields.io/badge/license-MIT-333333?style=flat-square)](LICENSE)

**pocket → companion**

_Android companion app for the Lun ecosystem. Chat with Natsume, monitor your alert feed, receive push notifications — from your pocket._

</div>

> [!NOTE]
> Fully standalone — connects to Natsume Core or LunAcedia, switchable from the settings screen with no rebuild required. Part of the [Lun' ecosystem](https://github.com/CrOliX-AltF4).

---

## Quick start

```bash
git clone https://github.com/CrOliX-AltF4/LunAvaritia.git
cd LunAvaritia
flutter pub get
# place android/app/google-services.json (Firebase project)
flutter run
```

Open **Settings** in the app → set server URL, bearer token, and backend mode.

---

## Backend modes

Two modes, switchable from the settings screen — no rebuild required.

| Mode | Backend | Endpoints used |
|---|---|---|
| **Natsume** (default) | Natsume Core | `/api/mobile/chat` · `/api/mobile/alerts` · `/api/mobile/status` |
| **LunAcedia** | LunAcedia server | `/api/chat` · `/api/events` · `/api/devices/push-token` |

In LunAcedia mode, `markRead` / `markAllRead` are client-side only — LunAcedia has no server-side read state.

---

## Features

**Chat** — conversation with Natsume or the LunAcedia AI butler, with live status bar (mood / energy / affinity)

**Alert feed** — filterable by source (email, calendar, tasks) and priority (urgent), swipe-to-dismiss, pull-to-refresh

**Push notifications** — FCM integration, foreground + background handlers, Android notification channel

---

## Architecture

```
BackendClient (abstract)
├── ApiService      → Natsume Core  /api/mobile/*
└── LunAcediaClient → LunAcedia     /api/chat · /api/events · /api/devices/push-token
```

`ChatProvider` and `AlertProvider` depend only on `BackendClient` — swapping backend requires no provider changes.

---

## Release

Each release publishes a **debug APK** as a GitHub Release asset (CI-built, no signing config required for sideloading).

To install: download `app-debug.apk` from [Releases](https://github.com/CrOliX-AltF4/LunAvaritia/releases), enable "install from unknown sources" on your device, install via file manager or `adb install`.

> **Secret required** — add `GOOGLE_SERVICES_JSON_B64` to repository secrets (base64-encoded `google-services.json`) for the APK build workflow.

---

## Lun ecosystem

| Project | Role |
|---|---|
| [LunAtar](https://github.com/CrOliX-AltF4/LunAtar) | AI dev pipeline — intent → code |
| [LunAcedia](https://github.com/CrOliX-AltF4/LunAcedia) | Information infrastructure — events · actions · AI butler |
| **LunAvaritia** | Mobile companion — Android |
| [LunImago](https://github.com/CrOliX-AltF4/LunImago) | Imitation learning — gameplay → ONNX policy |
| LunAnima | AI companion core — private |

---

<div align="center">

Built by **[CrOliX-AltF4](https://github.com/CrOliX-AltF4)** · MIT License · © 2026

_Part of the [Lun' ecosystem](https://github.com/CrOliX-AltF4)._

</div>
