<div align="center">

# ◆ Lun'Avaritia

[![Version](https://img.shields.io/github/v/tag/CrOliX-AltF4/LunAvaritia?style=flat-square&color=C8A415&label=version)](https://github.com/CrOliX-AltF4/LunAvaritia/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/CrOliX-AltF4/LunAvaritia/ci.yml?style=flat-square&label=CI)](https://github.com/CrOliX-AltF4/LunAvaritia/actions)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.22-555555?style=flat-square)](.)
[![License](https://img.shields.io/badge/license-MIT-333333?style=flat-square)](LICENSE)

**pocket → companion**

_Android companion app for the Lun ecosystem. Monitor your alert feed, chat with the AI butler, receive push notifications — from your pocket._

</div>

> [!NOTE]
> Fully standalone — connects directly to LunAcedia (default) or optionally to Natsume Core for enhanced AI, switchable from the settings screen with no rebuild required. Part of the [Lun' ecosystem](https://github.com/CrOliX-AltF4).
>
> **Doctrine** — ecosystem constitution and standards live in LunAnima's `docs/constitution.md` and `docs/standards/` (private repo), see in particular `04-securite-auth.md` (this app's token storage) and `03-ux-interface.md`.

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
| **LunAcedia** (default) | LunAcedia server | `/api/chat` · `/api/events` · `/api/devices/push-token` |
| **Natsume** | Natsume Core | `/api/mobile/chat` · `/api/mobile/alerts` · `/api/mobile/status` |

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

Each version tag publishes a **signed release APK** (`lunavaritia-vX.Y.Z.apk`) as a GitHub Release asset. Every
release is signed with the same key, so an update installs over the previous version and keeps its settings.

To install: download the APK from [Releases](https://github.com/CrOliX-AltF4/LunAvaritia/releases), allow installs
from your browser or file manager, then open it. The app checks GitHub for a newer release at launch and from
**Paramètres → À propos**.

> **Upgrading from 1.3.x or earlier** — those APKs were signed with a throwaway debug key. Uninstall once, then
> install the signed release; later updates install in place.

**Repository secrets** used by `.github/workflows/release.yml` (the workflow refuses to publish without them):

| Secret | Content |
|---|---|
| `ANDROID_KEYSTORE_B64` | The release keystore (PKCS12), base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Its password (also the key's password) |
| `ANDROID_KEY_ALIAS` | The key alias |
| `GOOGLE_SERVICES_JSON_B64` | `google-services.json`, base64-encoded (push notifications) |

A local release build reads `android/key.properties` (gitignored: `storeFile`, `storePassword`, `keyAlias`);
without it, it is signed with the debug key and Gradle says so.

---

## Lun ecosystem

| Project                                                    | Role                                                      |
| ---------------------------------------------------------- | --------------------------------------------------------- |
| [LunIra](https://github.com/CrOliX-AltF4/LunIra)           | AI dev pipeline — intent → code                           |
| [LunAcedia](https://github.com/CrOliX-AltF4/LunAcedia)     | Information infrastructure — events · actions · AI butler |
| **LunAvaritia**                                            | Mobile companion — Android                                |
| [LunGula](https://github.com/CrOliX-AltF4/LunGula)         | Imitation learning — gameplay → ONNX policy               |
| LunAnima                                                   | AI companion core — private                               |

---

<div align="center">

Built by **[CrOliX-AltF4](https://github.com/CrOliX-AltF4)** · MIT License · © 2026

_Part of the [Lun' ecosystem](https://github.com/CrOliX-AltF4)._

</div>
