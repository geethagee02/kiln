# Kiln

Kiln is the shared schedule and glaze book for East River Clay. Potters book firings and keep batch recipes on the phone. The phone keeps working when the studio wifi drops. A small API is the shared copy for the rest of the studio.

The app is Flutter. The API is Node, with SQLite and no npm dependencies. Both sides read the same seed file, `assets/seed/studio.json`.

## Run

Use Flutter 3.50 (Dart 3.14) and Node 22.13 or newer.

Start the API:

```bash
cd server
npm start
```

It listens on `http://127.0.0.1:8787` and creates `server/data/kiln.sqlite`. `HOST`, `PORT`, and `KILN_DB` override the bind address, port, and database file.

Start the app from the project root:

```bash
flutter pub get
flutter run -d linux
```

`flutter run` also targets an Android device or an iOS simulator. The app calls `http://127.0.0.1:8787` unless you pass another origin:

```bash
flutter run --dart-define=KILN_API=http://10.0.2.2:8787
```

`10.0.2.2` is the host machine as seen from the Android emulator. A physical phone needs the computer's LAN address, and the API has to be started with `HOST=0.0.0.0`.

Check the API:

```bash
curl http://127.0.0.1:8787/health
```

Tests:

```bash
cd server && npm test
flutter test
flutter analyze
```

## What you can do in the app

The schedule opens on the current week. A firing that is loading, firing, or cooling is pinned under "In the kiln". Book a firing from the button on that tab.

The glaze book searches and filters by kind, cone band, and atmosphere. A recipe page shows the color on clay at thin, dip, and thick, plus the batch. New recipes and edits go through the same form. Base materials have to total 100 percent. Colorants, opacifiers, and additives sit on top of that 100, which is how a bucket recipe is written on the studio wall. It is a batch total, separate from a Seger unity calculation.

A banner shows when the phone is offline and how many edits are still local.

## Architecture

Screens read SQLite. Repositories write SQLite and append the outbox. `SyncService` is the only type that calls the network.

```
schedule / glaze book / forms
        |
   repositories
        |
   kiln.sqlite  ---- outbox ----  SyncService  ---- POST /sync ----  Node API
        ^                                                              |
        |                         pull delta                           sqlite
        +------------------------------<-------------------------------+
```

A write updates the local row and replaces the outbox row for that entity id, so ten edits to one recipe become one push. Sync is a single `POST /sync`:

1. The client sends every outbox payload.
2. The server keeps the row whose `updatedAt` is newer. When the timestamps are equal, the incoming row wins, so a retry is safe.
3. The server returns `serverTime`, the rows it rejected, and every change with `synced_at` after the client's cursor.
4. The client drops outbox rows it just sent, writes the rejected server copies, and applies the delta. An id that is still queued is left alone. A local row with a newer `updatedAt` is left alone.

`synced_at` is the server's receive time. It is the pull cursor. `updatedAt` is the client's edit time and the conflict clock. Those are different clocks on purpose: a phone with a slow clock can still be pulled past, and a phone with a fast clock does not get stuck ahead of the cursor.

Deletes set `deleted_at` and travel in the delta. A pull with no `since` returns live rows only.

Seed rows use `updatedAt` of `2026-01-01T00:00:00.000Z` and are never queued. Member edits stick. Seed firing status is derived when the board is read (`scheduled`, `loading`, `firing`, `cooling`, `unloaded`), so the board follows the clock and the sync timestamp stays put. Firing ids are `firing-<iso week>-<kiln>`, so the same template lands on a stable id each week.

The client and the server share `statusForWindow` and the ISO-week rule. The widget tests pin the clock at 16 November 2026, 09:00, when the members' bisque is in the loading window.

## API

JSON is camelCase. SQL is snake_case.

| Method | Path | Role |
| --- | --- | --- |
| GET | `/health` | Studio name and server time |
| GET, POST | `/recipes` | List, or create a member recipe |
| GET, PUT, DELETE | `/recipes/:id` | Read, replace, or soft-delete |
| GET, POST | `/firings` | List, or create |
| GET, POST | `/sync?since=` | Push outbox rows and pull the delta |

The phone uses `/health` as a reachability check and `/sync` for every write. The other routes are there so a person can try the API with curl. A base that is not 100 percent (within 0.15) is rejected. Cone order, enums, and `#RRGGBB` colors are checked on the server as well as in the form.

## What to notice in an interview

- The read model is the local database. Losing the network changes the banner, and the lists stay up.
- The outbox is coalesced on `(entity, entity_id)`. A failed HTTP call leaves the queue in place.
- The pull cursor and the conflict clock are different columns.
- Seed data is idempotent: missing ids are inserted, member rows are left alone, and derived firing status does not dirty `updatedAt`.
- One seed document feeds the app and the API, and both test that every base batch totals 100.
- The clock is injected. The Monday board in the widget test is deterministic.
- Widget tests open SQLite with `databaseFactoryFfiNoIsolate`. The ffi worker isolate deadlocks Flutter's test binding on the next `pump`. The running app keeps the background isolate so queries stay off the UI isolate.
- Flutter 3.50 moved Material into `package:material_ui`. The app imports that library.
- Cleartext HTTP is allowed only for `localhost`, `127.0.0.1`, and `10.0.2.2` (see `android/app/src/main/res/xml/network_security_config.xml` and `NSAllowsLocalNetworking` on iOS).
- Fraunces and Outfit are SIL Open Font License, in `assets/fonts/OFL.txt`.

Deliberate limits: no accounts, no CRDT, no photos. The schedule UI creates firings. Recipes can be created, edited, and removed.

## Layout

```
lib/                 Flutter app
  core/db            SQLite, outbox, sync apply
  core/sync          the only network caller
  core/seed          expands assets/seed/studio.json into rows
  features/schedule  week board and booking form
  features/recipes   book, detail, batch form
server/              Node API, node:sqlite, zero dependencies
assets/seed          shared studio document
test/                domain tests and a widget flow
```

## Checked here

With Flutter 3.50.0 (Dart 3.14.0) and Node 22:

- `flutter analyze` reported no issues.
- `flutter test` passed 7 tests.
- `npm test` in `server/` passed 4 tests.
- `GET /health` returned `ok: true` and studio `East River Clay`.
