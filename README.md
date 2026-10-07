<div align="center">

# ◆ Lun'Avaritia

[![Version](https://img.shields.io/github/v/tag/CrOliX-AltF4/LunAvaritia?style=flat-square&color=C8A415&label=version)](https://github.com/CrOliX-AltF4/LunAvaritia/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/CrOliX-AltF4/LunAvaritia/ci.yml?style=flat-square&label=CI)](https://github.com/CrOliX-AltF4/LunAvaritia/actions)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.22-555555?style=flat-square)](.)
[![License](https://img.shields.io/badge/license-MIT-333333?style=flat-square)](LICENSE)

**pocket → your day**

_Lun'Acedia in your pocket. An Android app to talk to your assistant one topic at a time, go through your box and act on it at the source, and confirm what is waiting for you — from anywhere._

</div>

> [!NOTE]
> **Status: in development.** Talks to [Lun'Acedia](https://github.com/CrOliX-AltF4/LunAcedia) directly by default;
> it can instead be wired to an optional hub, an advanced setting. The app is neutral: the assistant's name comes from
> the server. Part of the [Lun' ecosystem](https://github.com/CrOliX-AltF4).

---

## Quick start

Download the signed APK from [Releases](https://github.com/CrOliX-AltF4/LunAvaritia/releases), allow installs from
your browser or file manager, and open it. Then, in **Réglages**:

1. type the address of your Lun'Acedia server;
2. **Appairer**: ask the dashboard (**Appareils**) for a pairing code and type it — the phone gets its own token, no
   server secret is ever typed or stored.

From source:

```bash
git clone https://github.com/CrOliX-AltF4/LunAvaritia.git
cd LunAvaritia
flutter pub get
# place android/app/google-services.json (Firebase project) for notifications
flutter run
```

---

## What it does

**Topics** — one conversation is one topic to deal with ("any urgent mail?", "and the second one?"). Kept on the
server, the same from every client; listed by day in the drawer, renamed, archived or deleted with a long press. An
answer shows the items it cites (open one, or start a topic on it), the actions it proposes with **Confirmer /
Annuler** right there and their deadline, and says when it read a third party's text.

**The box** — your inbox at the source, urgent first, filtered by source. Tap an item to read it in full (opening is
reading: marked read at the source); swipe to archive a mail or mark a GitHub notification done; a long press for the
rest — read, archive, trash (apart, never on a swipe), **Traiter** to open a topic on it, **Fait** on a task. Gmail's
trash a page at a time, with **Restaurer**. Every gesture waits for the source's answer: a refused one keeps the item
and says why. Once an item is read or gone, an action decided or a hub alert read, its notification is taken down.

**À valider** — what waits for you: the writes your assistant proposed (in words, with their deadline and whether a
third party's text came first) — **Confirmer / Annuler**; and, wired to a hub, what it would like to remember —
**Retenir**, **Modifier**, **Écarter**.

**Notifications** — a new item opens itself in the reader; a pending write opens **À valider**. A notification that
arrives with the app open refreshes what it concerns.

**Pairing** — each phone has its own token, revocable from the server; an unpaired phone says so on every screen.

**Updates** — signed releases; the app checks for a newer one at launch and in **Réglages → À propos**.

---

## Configuration

| Setting                    | Where                    | What                                                                 |
| -------------------------- | ------------------------ | -------------------------------------------------------------------- |
| Lun'Acedia address         | Réglages                 | The server the app talks to by default                               |
| Pairing                    | Réglages → Appairer      | A one-time code from the server; replaces any old shared secret      |
| Optional hub               | Réglages → Avancé        | Wired, every call goes to the hub — the app no longer reaches Lun'Acedia directly |

Moving to a hub takes the phone off Lun'Acedia's notifications (the hub sends them from then on), so nothing rings twice.

---

## Architecture

```
BackendClient (abstract)                one client per server, the screens don't know which
├── LunAcediaClient → Lun'Acedia        /api/conversations · /api/inbox · /api/actions · /api/devices
└── ApiService      → an optional hub   the same contract under /api/mobile/*
    ├── TopicApi        topics and decisions on their actions
    ├── InboxApi        the box, gestures, trash
    └── ValidationApi   pending writes, memory proposals (hub)
```

One HTTP transport: every call has a time limit, and every failure is told apart — out of reach, too slow, refused,
server error. The app follows the API and never runs ahead of it.

---

## Development

```bash
flutter analyze
flutter test
flutter build apk --release
```

Each version tag publishes a **signed release APK** (`lunavaritia-vX.Y.Z.apk`). Every release is signed with the same
key, so an update installs over the previous one and keeps its settings.

> **Upgrading from 1.3.x or earlier** — those APKs were signed with a throwaway debug key. Uninstall once, then install
> the signed release; later updates install in place.

**Repository secrets** used by `.github/workflows/release.yml` (it refuses to publish without them):

| Secret                      | Content                                                   |
| --------------------------- | --------------------------------------------------------- |
| `ANDROID_KEYSTORE_B64`      | The release keystore (PKCS12), base64-encoded             |
| `ANDROID_KEYSTORE_PASSWORD` | Its password (also the key's password)                    |
| `ANDROID_KEY_ALIAS`         | The key alias                                             |
| `GOOGLE_SERVICES_JSON_B64`  | `google-services.json`, base64-encoded (notifications)    |

A local release build reads `android/key.properties` (gitignored: `storeFile`, `storePassword`, `keyAlias`); without
it, it is signed with the debug key and Gradle says so.

---

## Lun' ecosystem

| Project                                                     | Role                                             | Status         |
| ----------------------------------------------------------- | ------------------------------------------------ | -------------- |
| [Lun'Ira](https://github.com/CrOliX-AltF4/LunIra)           | AI dev pipeline — intent → code                  | Active         |
| [Lun'Acedia](https://github.com/CrOliX-AltF4/LunAcedia)     | Your box and your day — events · actions · agent | In development |
| **Lun'Avaritia**                                            | Lun'Acedia in your pocket — Android              | In development |
| [Lun'Gula](https://github.com/CrOliX-AltF4/LunGula)         | Imitation learning — replays → ONNX model        | Paused         |

---

<div align="center">

Built by **[CrOliX-AltF4](https://github.com/CrOliX-AltF4)** · MIT License · © 2026

</div>
