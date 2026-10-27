# ResQMesh AI — Flutter App (Phase 1)

Phase 1 scaffold: theme, navigation shell, API layer, models, and the
Home/Splash screens. No SOS form, dashboard, map, Bluetooth, location,
or battery logic — those are later phases.

## Project structure

```
lib/
  main.dart              App entrypoint, MultiProvider + MaterialApp
  constants/
    constants.dart       Base URL, timeouts, app name — single source
  theme/
    theme.dart            Material 3 dark theme, colors, typography
  utils/
    routes.dart            Route table (splash, home)
    api_exception.dart      Normalizes DioException -> ApiException
  models/
    enums.dart               InjuryType, EmergencyLevel, PriorityLevel, SosStatus
    sos_request.dart         SosRequest + SosRequestCreate
  services/
    api_service.dart         Dio client — the 5 frozen endpoints only
  providers/
    sos_provider.dart        Latest SOS status state for Home screen
    connection_provider.dart Placeholder mesh connection state
  screens/
    splash_screen.dart       Animated logo, 2s delay, navigates to Home
    home_screen.dart         SOS button, status cards, nav placeholders
  widgets/
    glass_card.dart           Shared glassmorphism container
    sos_button.dart            Large circular SOS button
    connection_status_card.dart
    latest_sos_status_card.dart
    nav_placeholder_button.dart
```

## Run it

```bash
flutter pub get
flutter run
```

Point the app at your backend by editing exactly one line —
`AppConstants.baseUrl` in `lib/constants/constants.dart`. It defaults
to `http://127.0.0.1:8000/api`, matching the backend's local dev
server and the frozen OpenAPI contract's `/api` prefix.

## API layer

`ApiService` implements exactly the 5 endpoints in the frozen
contract — no more, no less:

- `POST /api/sos` → `createSos`
- `GET /api/sos` → `listSos`
- `GET /api/sos/{uuid}` → `getSos`
- `PUT /api/sos/{uuid}/status` → `updateSosStatus`
- `DELETE /api/sos/{uuid}` → `deleteSos`

`getSos`, `updateSosStatus`, and `deleteSos` aren't called by any
Phase 1 screen yet (there's no SOS form or dashboard to call them
from), but they're implemented now so Phase 2 doesn't need to touch
the API layer at all — only new screens/widgets that call it.

## Provider architecture

- `SosProvider` — the only thing that talks to `ApiService` for SOS
  data. Exposes `state` (idle/loading/loaded/error), `latestSos`, and
  `errorMessage`. Backs the Home screen's Latest SOS Status card.
- `ConnectionProvider` — placeholder shape for mesh connection state
  (`isConnected`, `nearbyDeviceCount`). No Bluetooth/Nearby
  Connections logic behind it yet — that's a later phase.

No widget calls Dio or touches JSON directly; all of that lives in
`services/` and `models/`.

## Note on verification

This environment has no Flutter/Dart SDK and no network access to
pub.dev, so I could not run `flutter pub get`, `flutter analyze`, or
`flutter build` to compile-check this project. Instead I manually
verified, across all 17 Dart files:

- Every file's braces and parentheses balance.
- Every relative import (`../...`) resolves to a real file in the
  project — no typo'd paths.
- Every `AppColors.*`, `AppConstants.*`, and `AppRoutes.*` reference
  matches a member that's actually defined.
- Every enum case referenced (`SosStatus.*`, `PriorityLevel.*`,
  `EmergencyLevel.*`, `InjuryType.*`, `SosLoadState.*`) matches
  exactly what's defined — including exhaustive `switch` coverage.

That catches the most common hand-written-Dart failure classes, but
it is not a substitute for `flutter analyze` / `flutter build`. Please
run those once you have the SDK available, before treating this as
final.
