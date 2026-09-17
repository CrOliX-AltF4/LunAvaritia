# Changelog

## [1.3.0] — 2026-09-17

**Release pipeline gap** — PR #19 and #20 (below) merged to `main` on 2026-09-16 with green CI but
neither bumped this file's version, so `auto-tag.yml` silently skipped tagging (the tag for the
unchanged version already existed) and `release.yml` never ran — no release/APK was built for
either. This version bump is what finally ships them.

### Features

- Digest sheet shown automatically on cold start / foreground resume (time-gated, default 4h),
  reusing the same `showDigestSheet()` as the manual button (`DigestGate`, `MainShell`)

### Fixes

- Chat history persisted locally (`ChatHistoryStore`, capped at 200 messages) — previously lost on
  app close
- Auth token moved from plaintext `SharedPreferences` to `flutter_secure_storage`, with automatic
  one-time migration of any existing plaintext token
- Push notification tap now deep-links to the relevant screen (`DeepLinkRouter`) instead of just
  opening the app to its default tab

## [1.2.1] — 2026-07-29

### Fixes

- `NatsumeStatus.affinityTier` crashed on `/api/mobile/status` when the server sent an `int`
  and the client parsed it as a `String` — now parsed with `(json['affinityTier'] as num?)?.toInt()`,
  regression-tested against a realistic payload shape
- Mobile identity resolves to the same "master" account as PC/Discord — no more guest fallback

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
