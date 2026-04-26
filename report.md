# Hiffi — Engineering & Architecture Report

This document summarizes the **Flutter client** in this repository: how it is structured, which product features exist, and which engineering choices support **scalability**, **stability**, and **maintainability**. It is intended as an internal or stakeholder-facing record of work accomplished on the mobile application (not the backend API itself).

---

## 1. Executive summary

**Hiffi** is a short-form / feed-style video application built with **Flutter** (Dart SDK `^3.9.2`), targeting **Android and iOS**. The app talks to a **REST backend** (`ApiConstants`), uses **Firebase** for core platform services, and integrates **WebRTC**, **background uploads**, **HLS playback** with a **local proxy**, and **rich media / PiP / background audio** behavior.

The codebase follows a **feature-first layout** under `lib/features/*` with **shared core** services under `lib/core/*`, **dependency injection via Provider**, and **declarative routing via GoRouter**. Significant effort has gone into **resilient uploads**, **connectivity-aware API access**, **observability** (Crashlytics, analytics), and **playback UX** aligned with mainstream video apps.

---

## 2. High-level architecture

### 2.1 Layering

| Layer | Location | Responsibility |
|--------|-----------|------------------|
| **UI** | `lib/features/*/presentation/` | Pages, widgets, overlays |
| **State** | `*view_model.dart` | `ChangeNotifier` / UI state |
| **Domain** | `lib/features/*/domain/` | Models, contracts (`VideoRepository`, etc.) |
| **Data** | `lib/features/*/data/` | Repository implementations calling `ApiClient` |
| **Core** | `lib/core/` | Cross-cutting: HTTP, routing, DI, notifications, media, workers |

### 2.2 Composition root

- **`main.dart`**: `WidgetsFlutterBinding`, optional **dev HTTP overrides**, **Firebase** + **Crashlytics** error hooks, **notifications**, **MediaSyncService**, **HlsProxyService**, **PiP** init, **Workmanager** callback registration, **`ClarityWidget`** wrapper, `runApp(HiffiApp)`.
- **`app.dart`**: `MultiProvider` from `buildAppProviders()`, **ScreenUtil** sizing, **MaterialApp.router** with **global upload overlay**, **AppLinks** deep linking to `/watch/:videoId`.
- **`lib/core/di/app_providers.dart`**: Single place wiring **services**, **repositories**, **view models**, and **`AppRouter`**.

### 2.3 Navigation & auth gating

- **`AppRouter`** (`lib/core/routes/app_router.dart`): **GoRouter** with `refreshListenable` tied to **`RouterRefreshStream`** on `AuthRepository.authStateChanges()`, **Firebase Analytics** observer, **Umami** navigation observer, **redirect** rules for guest vs signed-in users (e.g. playlists / liked / watch-history require login with `returnTo`).
- **Deep links**: `hiffi.com` / `www.hiffi.com` watch URLs resolve to internal **`/watch/:videoId`**.

### 2.4 State management

- **Provider** for app-wide singletons and **`ChangeNotifierProvider`** for screens that need reactive updates.
- Repositories are **`Provider`**-scoped; view models receive dependencies via `context.read` in `create` closures.

---

## 3. Scalability-oriented design

### 3.1 API boundary & repositories

- **`ApiClient`** centralizes **GET/POST/PUT/DELETE**, **JWT** attachment from **`TokenStorageService`**, optional vs required auth, and **structured logging** (`developer.log` + `hiffi.api` channel).
- **Feature repositories** (`VideoRepository`, `UserRepository`, `PlaylistRepository`, `SearchRepository`, `AuthRepository`) keep HTTP details out of widgets and allow the backend contract to evolve behind stable Dart APIs.

### 3.2 Pagination & discovery

- **`VideoRepositoryImpl`** uses **offset/limit** pagination with an optional **`seed`** for deterministic randomized feeds (see `getVideos` in `video_repository.dart`), which helps scale **feed randomness** without overloading a single sort key.

### 3.3 Upload pipeline (large payloads)

- **`VideoUploadService`**: staged flow — **bridge** (`/videos/upload`) → **presigned gateway PUT** for video → thumbnail upload → **`/videos/upload/ack/:bridgeId`**. Uses **`Idempotency-Key`** header (`payload.taskId`) to support **safe retries** at the API layer.
- **`ApiClient.uploadFileToGateway`**: **64 KiB chunked streaming**, **progress callbacks**, **exponential backoff retries** for **handshake**, **connection reset**, and generic failures, **5-minute response timeout** — appropriate for **large files** and flaky mobile networks.

### 3.4 Background execution

- **`Workmanager`** + **`video_upload_worker.dart`**: uploads can continue **off the UI isolate**; worker re-initializes **Firebase**, validates **file still exists**, checks **connectivity**, runs **`VideoUploadService`**, updates **notifications**, and uses **`IsolateNameServer`** port for **progress signals** back to the app when registered.
- **`main.dart`** intentionally does **not** cancel all WorkManager tasks on startup so **in-progress uploads** survive process death; worker handles **stale** work by checking file existence.

### 3.5 HLS at scale (client-side)

- **`HlsProxyService`**: local **Shelf** server proxies **`prod.hiffi.workers.dev`**, injects **`x-api-key`**, and **rewrites segment paths** to match CDN layout — addressing **iOS AVPlayer header/segment path limitations** without changing every playlist server-side for each client experiment.

### 3.6 Vendor SDK isolation

- **`third_party/dospace`**: vendored **DigitalOcean Spaces** client (`path: third_party/dospace`), **`SpacesService`** wraps uploads — keeps third-party churn **isolated** from app code and excluded from primary lint scope via **`analysis_options.yaml`** `exclude: third_party/**`.

---

## 4. Stability, resilience & UX safeguards

### 4.1 Crash & error reporting

- **Firebase Crashlytics**: **`FlutterError.onError`** and **`PlatformDispatcher.instance.onError`** forward fatals to Crashlytics in **`main.dart`**.

### 4.2 Network awareness

- **`NetworkConnectivityService`**: **`connectivity_plus`** with **broadcast stream**, **sync snapshot** for `ApiClient._checkConnectivity`, **`ensureInitialized()`** to avoid false offline on cold start, proper **dispose**.
- **`NoInternetException`** path in **`ApiClient`** prevents pointless calls when offline.
- **`VideoUploadViewModel`**: listens for connectivity loss during active work and can **cancel** WorkManager task + surface user messaging.

### 4.3 Graceful degradation

- **`VideoRepository.postWatchHoursSignal`**: documented as **best-effort** (failures swallowed) so analytics never blocks playback.
- **`WatchScreen._hydratePlaylistContext`**: playlist fetch failures **do not block** watching a single video.
- **`PlaylistSessionStorage`**: **best-effort** JSON persistence to **`SharedPreferences`**.
- **Invalid deep link** on `/watch/:videoId` redirects to **home** instead of throwing.

### 4.4 Upload edge cases

- Worker treats **ack failure after successful video upload** as **success with user-visible caveat** to avoid **duplicate uploads** when the binary is already on object storage.

### 4.5 Media lifecycle

- **`MediaSyncService`**: coordinates **foreground video** vs **background audio** via **`audio_service`** + **`just_audio`** + **`audio_session`** (interruptions, “becoming noisy”, lock-screen controls, next/previous registration).
- **`PipService`**: **MethodChannel** to native PiP; **does not pause** on PiP enter (YouTube-style); handles **post-PiP lifecycle** and coordinates with **`MediaSyncService.playFromNotification`** when appropriate; **guards** against orientation-driven fullscreen glitches after PiP.

### 4.6 Developer vs production networking

- **`DevHttpOverrides`** in debug only in **`main.dart`**.
- **`ApiClient`** upload path includes **relaxed certificate handling** intended for **development** — production hardening should ensure this path is **not** used where it weakens TLS guarantees.

---

## 5. Product features implemented (client)

The following are **user-visible** or **major functional** areas evidenced in routing and feature modules:

| Area | Routes / modules | Notes |
|------|------------------|--------|
| **Home feed** | `/home` | `HomeViewModel`, `HomePage` |
| **Following** | `/following` | Following feed |
| **Liked videos** | `/liked` | Auth-gated |
| **Watch history** | `/watch-history` | Auth-gated |
| **Search** | `/search?q=` | Users + videos |
| **Video detail (in-app)** | `/video/:videoId` | Requires `VideoModel` or cache |
| **Watch / share / deep link** | `/watch/:videoId` | Loads by id; playlist query params |
| **Playlists** | `/playlists`, `/playlists/:id` | CRUD-style flows via `PlaylistRepository` |
| **Upload** | `/upload/video` | Form, tags, thumbnail, foreground/background upload |
| **Auth** | `/login`, `/signup` | Backend JWT + OTP / password reset flows in `AuthRepository` |
| **Profile** | `/users/:username` | User profiles; routing rules differ for guests |
| **Become creator** | `/become-creator` | Onboarding-style screen |
| **Video player** | Embedded in watch/detail | HLS, Chewie, custom controls, comments, votes, follow |
| **Global upload feedback** | App-level overlay | `GlobalUploadOverlay` |

**Player / UX** (from `RELEASE_NOTES_PLAYSTORE.md` and code): redesigned controls (center play/pause, prev/next), **double-tap seek**, **swipe-up fullscreen**, **safe area / letterboxing**, **blurred thumbnail** while loading, thumbnail badge rules.

**Platform extras**: **Google Play in-app updates** (`home_page.dart`), **wakelock**, **share_plus**, **url_launcher**, **cached_network_image**, **shimmer** loading states.

---

## 6. Observability & growth tooling

- **Firebase Analytics** + **navigation observer** on `GoRouter`.
- **Umami** (`flutter_estatisticas`) for web-style analytics with configured endpoint / website id in `AppRouter`.
- **Microsoft Clarity** via `ClarityWidget` in `main.dart`.
- **Screen / event API** in **`AnalyticsService`** (dual-fire to Firebase + Umami).

---

## 7. Security & configuration (recommendations)

- **JWT** persisted via **`TokenStorageService`** (`SharedPreferences`) — acceptable for many apps; consider **secure storage** on device for higher threat models.
- **API base URL** in `ApiConstants` (currently **`api.dev.hiffi.com`** with production URL commented) — use **flavors** or **dart-define** for clean **dev/stage/prod** separation.
- **Spaces credentials** are currently passed in **`app_providers.dart`** — **should be moved** to CI secrets + `--dart-define`, native obfuscation, or remote config **never committed to git**.
- **HLS proxy** injects API key from **`ImageUtils.profileImageApiKey`** — ensure keys are **rotatable** and **scoped** server-side.

---

## 8. Testing & code quality

- **Analyzer**: `flutter_lints` with **`third_party/**` excluded**.
- **Tests present**: `test/widget_test.dart`, **`test/playlist_models_test.dart`** (playlist JSON sorting / parsing).
- **Versioning**: `pubspec.yaml` **`1.0.0+37`** (semantic version + build number for stores).

---

## 9. Repository map (quick reference)

```
lib/
  app.dart                 # Root widget: providers, theme, router, overlays, deep links
  main.dart                # Bootstrap: Firebase, Crashlytics, services, Workmanager
  firebase_options.dart    # Firebase configuration
  core/
    constants/             # API paths, WebRTC ICE config
    di/app_providers.dart  # Provider graph
    exceptions/            # Typed failures (e.g. API, auth)
    routes/app_router.dart # GoRouter + auth redirect + analytics observers
    services/              # ApiClient, connectivity, notifications, HLS proxy, PiP, media, analytics, …
    utils/                 # Responsive helpers, image utils, file validation, fullscreen
    widgets/               # Shared UI (sidebar, logo, shimmer, global overlay)
    workers/               # Workmanager entry + upload orchestration glue
  features/
    auth/                  # Repository + VM + auth UI
    home/                  # Feed + WebRTC service + home VM
    video/                 # Models, repository, player, watch screen, comments
    upload/                # Upload VM, pages, Spaces + bridge upload service
    user/                  # Profile, become creator
    search/                # Search repository + results
    playlist/              # Playlist models, repo, pages, add-to-playlist UX
    following/, liked/, watch_history/
third_party/dospace/       # Vendored Spaces client
```

---

## 10. Summary table: engineering themes → evidence in code

| Theme | Where it shows up |
|--------|-------------------|
| **Modular features** | `lib/features/*` with data/domain/presentation split |
| **DI & lifecycle** | `app_providers.dart` `dispose` on router, API client, connectivity, Spaces |
| **Resilient uploads** | `VideoUploadService`, `ApiClient.uploadFileToGateway`, Workmanager worker |
| **Offline-first API guard** | `NetworkConnectivityService` + `ApiClient._checkConnectivity` |
| **Playback robustness** | `HlsProxyService`, `HlsPlayerController`, `MediaSyncService`, `PipService` |
| **Observability** | Crashlytics, Firebase Analytics, Umami, Clarity |
| **Store / growth** | In-app updates, deep links, share |

---

*Generated from repository structure and source review. Backend behavior is described only as implied by client endpoints and payloads.*
