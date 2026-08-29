# KrishiBondhu — Changes Since Last Push & Demo Guide

This covers everything done since the last pushed commit (`fd8e184 Delete SETUP.md`),
why it was done, how to run it, and how to demo it to your supervisor.

---

## 1. What changed, in one paragraph

The app no longer uses Firebase. It now talks to a small self-hosted backend
(`backend/`) that you run yourself, which stores data in a local SQLite
database. The login screen's "demo account" shortcut buttons are gone —
the app now showcases real registration and login, backed by real data that
persists in the database. A handful of real bugs found along the way (a
multi-minute stuck-on-boot issue, a false "already registered" error) are
fixed. The PWA now has a proper branded icon. The repo also got a proper
`.gitignore` so machine-generated files stop cluttering commits.

---

## 2. What changed, in detail

### 2.1 Backend: Firebase → self-hosted Node/Express/Prisma/SQLite

**Why**: Firebase requires a paid/cloud account and internet dependency for a
local classroom demo. A self-hosted backend runs entirely on your machine.

- New folder: `backend/` — an Express server (`server.js`) backed by SQLite
  via Prisma (`prisma/schema.prisma`, `prisma/migrations/`).
- Two generic REST endpoints mirror the app's old Firestore calls:
  - `GET /api/:collection` — list all records (`users`, `markets`, `prices`)
  - `PUT /api/:collection/:id` — create/update one record
- The backend **also serves the built Flutter web app itself** as static
  files, so the whole app (UI + API) is reachable from a single port/URL —
  this is what makes the ngrok tunnel and LAN access simple (one link, not
  two).
- `lib/firebase_boot.dart`, `firebase_boot_stub.dart`, `firebase_boot_web.dart`
  are deleted — no more Firebase SDK, config, or dependency
  (`firebase_core`, `cloud_firestore` removed from `pubspec.yaml`).

### 2.2 Folder structure unified

**Why**: you asked for frontend and backend in the same project folder
instead of two separate directories.

- `backend/` now lives inside `SoftwareLab_Group-1/` (it used to be a
  sibling folder). All paths were updated accordingly.

### 2.3 Fixed: app feeling "stuck" for minutes on login

**Root cause**: the app used to wait for the *entire* backend sync —
including, on a fresh database, up to ~32 sequential network requests to
seed demo data — before rendering anything at all. On a slow connection
this could take well over a minute with zero visual feedback.

**Fix** (`lib/state.dart`):
- The app now loads local/cached data instantly and is interactive
  immediately, every time.
- The backend sync runs in the background and upgrades the UI silently
  when it finishes.
- What used to be dozens of one-at-a-time requests now fire concurrently.
- A small "Connecting to server…" indicator shows on the login screen
  while that background sync is in flight.

### 2.4 Fixed: false "already registered" error

**Root cause**: the app was blindly *replacing* its in-memory user list
with whatever the backend returned, every 3 seconds. A brand-new
registration could get silently erased by the very next background refresh
if it landed a fraction of a second early — bouncing you back to the login
screen — and retrying then legitimately (but confusingly) tripped the
duplicate check.

**Fix**: background refreshes now *merge* new data in by id instead of
replacing the list outright (the app never deletes records, so this is
always safe). Registering — including re-registering the same number after
a database reset — now works correctly and reliably. This was verified by
actually driving the compiled app through a browser and confirming the
data lands in the database, not just by reading the code.

### 2.5 Removed the demo-account shortcut

**Why**: you wanted to demo real registration and login to your supervisor,
not a one-tap shortcut.

- The "Try a demo account" (Farmer/Trader/General user) buttons are gone
  from the login screen.
- The "under construction" popup's hint text now says "please register a
  new account" instead of "please log in with a demo account".
- Registering and logging in with a real phone number/email + password is
  now the only way in.

### 2.6 PWA icon now matches the app's branding

**Why**: the installed home-screen icon was still Flutter's default blue
logo, not KrishiBondhu.

- `web/icons/*.png` and `web/favicon.png` regenerated to match the app's
  actual branding: the green gradient (`#12633A` → `#16A34A`) and 🌾 emoji
  used on the splash screen.
- `web/manifest.json`'s theme/background colors updated to match (were
  Flutter's default blue, `#0175C2`).

### 2.7 Repo cleanup — proper `.gitignore`

**Why**: this repo never had a standard Flutter `.gitignore`, so a lot of
machine-generated, machine-*specific* files had been committed —
including `android/local.properties`, which bakes in a local SDK path that
would silently break a teammate's build on a different machine.

- Added a standard Flutter/Android/iOS `.gitignore`, plus entries for
  `backend/node_modules/`, the local database file, the `build/` output,
  and `.claude/`.
- Untracked (not deleted — still on your disk) 11 files that matched
  those new rules: `.flutter-plugins-dependencies`,
  `GeneratedPluginRegistrant.*`, `local.properties`,
  `ios/Flutter/ephemeral/*`, etc.
- **Nothing has been committed yet** — this is all staged, waiting for you
  to review and commit.

---

## 3. How to start everything

Recommended setup: use **one backend server and one ngrok tunnel**. The Node
server serves both the Flutter PWA (`build/web`) and the API (`/api`), so every
phone opens the same URL and talks to the same SQLite database.

### Environment variables

For the recommended one-tunnel setup, you do **not** need a `.env` file.

| Variable | Needed? | Use |
|---|---:|---|
| `PORT` | Optional | Backend port. Defaults to `4000`. |
| `KB_API_BASE` | Not needed for one-tunnel PWA | Only needed if the frontend is served from a different URL than the backend, or for APK/native builds. |
| `DATABASE_URL` | Not needed | Prisma currently uses `backend/prisma/dev.db` from `schema.prisma`. |

### One-time setup

```powershell
cd "C:\Users\Rosni Bente\Downloads\SoftwareLab_Group-1\backend"
npm install
npm run prisma:deploy
```

### Every time you want to run a mobile/PWA demo

**Terminal 1 - build the PWA after Dart/UI changes:**
```powershell
cd "C:\Users\Rosni Bente\Downloads\SoftwareLab_Group-1"
flutter build web --release
```

**Terminal 2 - start the backend + PWA server:**
```powershell
cd "C:\Users\Rosni Bente\Downloads\SoftwareLab_Group-1\backend"
npm start
```

This serves:
- App: `http://localhost:4000`
- API health check: `http://localhost:4000/api/health`
- Shared app data snapshot: `http://localhost:4000/api/snapshot`

**Terminal 3 - expose that same server with ngrok:**
```powershell
ngrok http --domain=bootlace-pacify-crisped.ngrok-free.dev 4000
```

Then everyone opens:

```text
https://bootlace-pacify-crisped.ngrok-free.dev
```

That one URL is the important part. Do not separately share `localhost`, and do
not ask mobile users to open a Flutter dev-server URL. On a phone, `localhost`
means the phone itself, not your laptop.

### If you insist on serving frontend and backend separately

Use this only if you are running the Flutter web app from another host/port.
In that case the frontend must be built with the backend ngrok URL baked in:

```powershell
flutter build web --release --dart-define=KB_API_BASE=https://bootlace-pacify-crisped.ngrok-free.dev
```

`KB_API_BASE` can be either the backend origin (`https://...ngrok-free.dev`) or
the API root (`https://...ngrok-free.dev/api`). The app normalizes both.

For APK/native builds, you also need `KB_API_BASE` because there is no browser
page origin:

```powershell
flutter build apk --release --dart-define=KB_API_BASE=https://bootlace-pacify-crisped.ngrok-free.dev
```

### Starting clean for a demo

If you want a guaranteed-fresh database before demoing:

```powershell
cd "C:\Users\Rosni Bente\Downloads\SoftwareLab_Group-1\backend"
del prisma\dev.db
npm run prisma:deploy
npm start
```

The app automatically seeds 3 baseline accounts (`rosni`, `mehedi`, `nafisa`,
password `1234`) the first time it connects to an empty database. Your live demo
can still register a brand-new account.

### What changed for slow server response

The app now checks `/api/health` with a short timeout before starting backend
sync, and then fetches `/api/snapshot` in a single request instead of making
three separate startup/polling requests. This is noticeably better over ngrok
and mobile data because each sync round-trip is smaller.
## 4. Demo script (suggested)

1. Open the app link on your phone or laptop browser.
2. Dismiss the "under construction" popup (**Continue**).
3. Tap **Register**, fill in a real name/phone/password, pick a role,
   set a location, pick a crop or two, tap **Done**.
4. You're immediately logged in — show the Home dashboard (weather,
   market prices, quick actions).
5. Log out (Profile → Log out), then log back in with the same
   credentials you just registered — proving the account actually
   persisted, not just an in-memory session.
6. Optional: on a second device/tab, show that a price you submit on one
   shows up on the other within a few seconds (real backend sync, not a
   local trick).
7. Optional: show `http://localhost:4000/api/users` in a browser tab —
   the raw data sitting in the database, proving it's a real backend, not
   a mock.

### Installing as an app (optional, no APK needed)

On the phone, open the link in the browser, then:
- **Android (Chrome)**: ⋮ menu → "Add to Home screen" / "Install app"
- **iPhone (Safari)**: Share icon → "Add to Home Screen"

This gives a home-screen icon (now correctly branded) that opens
full-screen, no browser bar — reads as a real installed app.

---

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| `node`/`ngrok` "not recognized" in a terminal | Open a new terminal, or refresh PATH with `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`. |
| ngrok says "endpoint already online" / stuck "reconnecting" | Another ngrok process (yours or a leftover one) is already holding that domain. Fully close/kill all ngrok processes, wait a few seconds, then start it again — only one can use the domain at a time. |
| Phones do not see each other's registrations/prices | Make sure everyone opened the **same ngrok URL served by `npm start`**, not `localhost` or a separate Flutter dev-server URL. |
| "Already registered" for a number you're sure is new | Clear the site storage or reinstall the PWA; the browser may still have old local data. |
| Backend port 4000 already in use | Something else (an old `node server.js`) is still running. Find and stop it before starting a new one. |

---

## 6. What's new on disk (file reference)

```
SoftwareLab_Group-1/
├── backend/                    ← NEW: the self-hosted API + static server
│   ├── server.js               ← Express app (GET/PUT + serves build/web)
│   ├── package.json
│   └── prisma/
│       ├── schema.prisma       ← 3 tables: User, Market, Price (JSON blob rows)
│       └── migrations/
├── build/web/                  ← Flutter's compiled output, served by backend
├── lib/
│   ├── state.dart              ← CHANGED: backend sync, boot, auth logic
│   ├── main.dart                ← CHANGED: intro popup text
│   ├── screen_auth.dart         ← CHANGED: demo buttons removed
│   ├── screen_main.dart         ← CHANGED: sync-status label rename
│   └── strings.dart             ← CHANGED: a couple of string keys
├── web/
│   ├── icons/, favicon.png     ← CHANGED: new branded icons
│   └── manifest.json           ← CHANGED: theme colors
├── .gitignore                  ← NEW
└── DEMO_GUIDE.md                ← this file
```


