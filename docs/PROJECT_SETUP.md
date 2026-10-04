# CampusLoop – Project Structure & Networking Layer

This document records everything done in this first task, written for someone
new to Flutter. Scope of the task: **project structure + networking layer
only.** No screens, login logic or state management yet.

---

## 1. Step-by-step log

| # | What I did | Why |
|---|-----------|-----|
| 1 | Inspected the existing `campus_loop` folder and ran `flutter --version` | Confirmed a Flutter project already existed (Flutter 3.47.6, Dart 3.13.5) so I did not re-create it. |
| 2 | Ran `flutter pub add dio flutter_secure_storage uuid` | Added the 3 packages the networking layer needs (see section 3). Edits `pubspec.yaml`. |
| 3 | Created the folder structure under `lib/` (section 2) | Gives every future feature a place to live. |
| 4 | Wrote the networking files in `lib/core/` (section 4) | The actual networking layer. |
| 5 | Replaced the demo counter app in `lib/main.dart` with a minimal placeholder that builds the `ApiClient` | The demo app was template code unrelated to CampusLoop. |
| 6 | Replaced `test/widget_test.dart` and added `test/core/network/api_client_test.dart` | The old test tested the counter demo, which no longer exists. New tests prove the networking layer works. |
| 7 | Ran `flutter analyze` (no issues) and `flutter test` (7 tests pass) | Verification. |

## 2. Folder structure

```
lib/
├── main.dart                  App entry point
├── core/                      Code shared by ALL features
│   ├── config/
│   │   └── app_config.dart    API base URL + timeouts
│   └── network/
│       ├── api_client.dart        The one class features use to call the API
│       ├── api_exception.dart     One error type for every failure
│       ├── auth_interceptor.dart  Adds token + refreshes it on 401
│       └── token_storage.dart     Where tokens are saved
├── features/                  One folder per area of the app
│   ├── auth/                  (J1) register, sign in, reset, sign out
│   ├── events/                (J2) browse, search, filter, detail
│   ├── registrations/         (J3, J4) register, waitlist, ticket, check-in
│   ├── my_events/             (J5) saved + registered
│   ├── notifications/         (J7) alerts + preferences
│   ├── profile/               profile, preferences, privacy
│   └── organizer/             (J6) create/edit/publish, roster, scanner
│       └── each has: data/ domain/ presentation/
└── shared/
    └── widgets/               Reusable UI pieces (event card, chips, ...)
```

**Feature-first** means code is grouped by *what it is for* (events, auth, ...)
rather than by *type* (all screens together, all models together). Each
feature folder has three layers:

- `data/` – talks to the API (uses `ApiClient`), turns JSON into objects.
- `domain/` – the plain Dart objects/rules (e.g. an `Event` class).
- `presentation/` – screens and widgets.

The sub-folders are empty for now; each holds a `.gitkeep` file only so the
folder survives in Git. Delete the `.gitkeep` once a folder has real files.

`test/` mirrors `lib/` (e.g. `test/core/network/` tests `lib/core/network/`).

## 3. Packages added (in `pubspec.yaml`)

| Package | Used for |
|---------|----------|
| `dio` | HTTP client. Chosen over Flutter's basic `http` package because it has *interceptors* (code that runs on every request), which we need for auth tokens and token refresh. |
| `flutter_secure_storage` | Saves the tokens in Android Keystore / iOS Keychain (encrypted). Spec: "session survives app restart". |
| `uuid` | Generates random IDs for the `Idempotency-Key` header. |

## 4. The networking layer, file by file

### `core/config/app_config.dart`
Holds the API base URL and timeouts. The URL comes from a **dart-define** so it
is not hard-coded:

```
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/v1
```

Default: `http://10.0.2.2:3000/v1`. `10.0.2.2` is how the **Android emulator**
reaches your computer. On the **iOS simulator** use `http://localhost:3000/v1`.
(The spec requires secrets stay out of the repository; this file has none.)

### `core/network/api_exception.dart`
The spec defines the error format `{"error":{"code","message","requestId"}}`
and status codes (400, 401, 403, 404, 409, 429). `ApiException.fromDioException`
converts any failure into an `ApiException` with:
`type` (an enum such as `conflict`, `unauthorized`, `network`), `code`
(e.g. `EVENT_FULL`), `message`, `statusCode`, `requestId`.
`isOffline` is true for no-connection/timeouts, which later drives the
"You are offline" UI. Screens only ever catch `ApiException`.

### `core/network/token_storage.dart`
- `TokenStorage` – an interface (what storage must be able to do).
- `SecureTokenStorage` – real, encrypted implementation.
- `MemoryTokenStorage` – in-memory version used in tests.

### `core/network/auth_interceptor.dart`
Runs on every request:
1. **Before sending:** adds `Authorization: Bearer <token>` (unless the call is
   marked `auth: false`, as login/register will be).
2. **On a 401 reply:** the access token has probably expired. It calls
   `POST /auth/refresh` with the refresh token, saves the new (rotated) pair,
   and repeats the original request **once**.
3. **If refresh fails:** deletes the stored tokens and calls `onSessionExpired`
   so the app can show "Please sign in again to continue."

It uses a separate Dio for the refresh call so refreshing can't trigger itself,
and `QueuedInterceptor` so several simultaneous 401s cause a single refresh.

### `core/network/api_client.dart`
The class every feature will use:

```dart
final events = await apiClient.get<Map<String, dynamic>>(
  '/events', query: {'q': 'design', 'topic': 'arts'});

await apiClient.post<Map<String, dynamic>>(
  '/events/evt_104/registrations',
  idempotencyKey: ApiClient.newIdempotencyKey(), // required by the spec
);
```

Methods: `get`, `post`, `put`, `patch`, `delete`. Anything that goes wrong is
thrown as an `ApiException`. `ApiClient.newIdempotencyKey()` makes the key for
registration requests – create one per user tap and **reuse it if you retry**.

### `main.dart`
Creates one `ApiClient` (with `SecureTokenStorage`) and passes it to the app.
Shows a placeholder screen only; no UI work was part of this task.

## 5. Tests

`test/core/network/api_client_test.dart` uses a fake HTTP adapter (no real
server) to check: bearer token added, `auth: false` skips it, Idempotency-Key
sent, error envelope → `ApiException`, 401 → refresh → retry succeeds, and
failed refresh → tokens cleared + session-expired callback.
Run them with `flutter test`.

## 6. Assumptions & things to confirm with the team

1. **Refresh endpoint body** – the spec lists `POST /v1/auth/refresh` but not
   its payload. I assumed request `{"refreshToken": "..."}` and response
   `{"accessToken": "...", "refreshToken": "..."}`. If the backend differs,
   change `_refreshTokens()` in `auth_interceptor.dart` (one place).
2. **Base URL** – assumed the backend runs on port 3000 with the `/v1` prefix.
3. **No JSON models yet** – the client returns raw decoded JSON. Models (Event,
   Registration, ...) belong to each feature's `domain/` and come later.
4. **No offline caching yet** – spec requires cached reads; that is a later task.
5. **Windows Developer Mode** – `flutter pub add` printed *"Building with
   plugins requires symlink support. Please enable Developer Mode"*. Run
   `start ms-settings:developers`, turn on Developer Mode, otherwise
   `flutter run` for Windows/Android may fail to build plugins such as
   `flutter_secure_storage`.

## 7. Commands cheat-sheet

```
flutter pub get      # download packages listed in pubspec.yaml
flutter analyze      # static checks for mistakes
flutter test         # run all tests
flutter run          # run the app on a connected device/emulator
```
