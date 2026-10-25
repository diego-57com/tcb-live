# TCB Live

An Android app for the **TCB — Transportes Coletivos do Barreiro** bus network: stops, routes, timetables, next-departure boards, and a live map of vehicles on OpenStreetMap.

> Independent project, not affiliated with TCB.

## Features

- Map (OpenStreetMap, no API key) with all stops and live vehicle positions.
- Search stops by name/number, mark favourites, and see nearby stops.
- Next departures per stop, computed from the timetable with a countdown.
- Routes: one entry per line, with variant selection and the route drawn on the map.
- Live vehicles on each route map, and per-stop filtering of running vehicles.
- Tap a bus to highlight its route (all variants) and the path it follows.
- User location shown as a blue dot.
- Configurable refresh interval and a configurable JSON realtime source.

## Data and licensing

- Static GTFS (stops, routes, timetables, shapes): TCB, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  Official URL: `https://backend.tcbarreiro.pt/download-gtfs` — the app downloads and caches it.
- Map tiles: © OpenStreetMap contributors.
- Live positions: not part of the open dataset. The app exposes a configurable JSON source that the
  user can point at any compatible endpoint; no third-party endpoint is bundled or published.

## Project structure

```
lib/
  main.dart                 # entry point
  app.dart                  # MaterialApp + theme
  theme/app_theme.dart      # design system (light/dark)
  models/
    gtfs_models.dart        # Stop, Route, Trip, StopTime, ServiceCalendar, GtfsFeed
    vehicle.dart            # LiveVehicle
  services/
    csv.dart                # RFC 4180 CSV parser
    gtfs_parser.dart        # GTFS ZIP -> GtfsFeed
    gtfs_repository.dart    # download + cache
    departure_engine.dart   # next departures
    realtime_source.dart    # JSON realtime source
    location_service.dart   # GPS + distances
    settings_store.dart     # persisted preferences
  state/app_state.dart      # global state (provider)
  screens/                  # map, stops, routes, details, settings
  widgets/                  # markers, badges, tiles, empty states
```

## Architecture notes

- `GtfsFeed` indexes stops, routes, trips, stop times and shapes for O(1) lookups.
- `DepartureEngine` resolves the active service calendar for the current day and sorts upcoming
  departures; it handles trips that run past midnight.
- `JsonVehiclesSource` maps an arbitrary JSON payload into `LiveVehicle` objects. The array path and
  the field paths are configurable at runtime; defaults target a generic flat schema.
- State is centralised in `AppState` (ChangeNotifier) and consumed through `provider`.

## Building

**Without installing anything locally** — the included GitHub Actions workflow builds the APK in CI:

1. Push the project to a GitHub repository (the default branch must be `main` or `master`).
2. The `Build Android APK` workflow runs automatically (or manually from the Actions tab).
3. Download the `tcb-live-apk` artifact and install `app-release.apk` on the device.

The workflow generates the Android scaffolding (`flutter create`) and adds the required manifest
permissions before building.

**Locally** (requires Flutter 3.27+ and Android Studio):

```bash
flutter create --platforms=android --project-name tcb_live .
flutter pub get
flutter run
```

### Android permissions

- `INTERNET` — required for tiles and the GTFS download (added by the workflow for release builds).
- `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` — optional, used for the user position and
  nearest stops. The app still works without them.

## Realtime configuration

The Settings screen lets the user enter the endpoint URL, the array path, and the field paths
(latitude, longitude, bearing, headsign, colour). Values are stored on the device only. Nothing is
committed to the repository.

## Troubleshooting

- `flutter pub get` fails to resolve: update the versions in `pubspec.yaml`; run `flutter pub outdated`.
- Blank map: check the internet connection and the `INTERNET` permission.
- No location: check the Android location permissions and that GPS is enabled.
