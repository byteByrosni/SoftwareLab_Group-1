# Setup & Deployment Guide

KrishiBondhu runs in two modes:

- **Local mode (default):** works immediately with no configuration. Each device keeps its
  own data. Good for a quick demo on a single device.
- **Live sync mode:** with a free Firebase project connected, all data is stored in the
  cloud and **synced across every device in real time** — a price submitted on one phone
  appears on another instantly.

---

## 1. Deploy the app (static web)

After `flutter build web --release`, the folder `build/web/` is a complete static site.

**Option A — Netlify (no account setup, fastest)**
1. Open <https://app.netlify.com/drop>.
2. Drag the whole **`build/web`** folder onto the page.
3. In a few seconds you get a public link (e.g. `https://krishibondhu.netlify.app`) that
   opens on any phone or computer. On a phone, use the browser's **"Add to Home Screen"**
   to install it like an app.

**Option B — Firebase Hosting**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting      # choose the existing project, set public dir to: build/web
firebase deploy
```

---

## 2. Turn on live cross-device sync (Firebase)

1. Go to <https://console.firebase.google.com> and click **Add project** (free). Give it a
   name such as `krishibondhu` and finish the wizard (Google Analytics is optional).
2. In the left menu open **Build → Firestore Database → Create database**. Choose
   **Start in test mode** and pick a location, then **Enable**.
3. In **Project settings** (gear icon) → **Your apps**, click the **Web** icon `</>` and
   register an app (any nickname). Firebase shows a `firebaseConfig` block like:
   ```js
   const firebaseConfig = {
     apiKey: "AIza...",
     authDomain: "krishibondhu.firebaseapp.com",
     projectId: "krishibondhu",
     storageBucket: "krishibondhu.appspot.com",
     messagingSenderId: "1234567890",
     appId: "1:1234567890:web:abcdef"
   };
   ```
4. Open **`web/index.html`** (or, in the deployed site, `build/web/index.html`) and paste
   those six values into the `window.KB_FIREBASE = { ... }` block near the top.
5. If you edited `web/index.html`, run `flutter build web --release` again and redeploy.
   If you edited the deployed `build/web/index.html` directly, just re-upload the folder.

The app now stores everything in Firestore and syncs live across all devices. The first
time it runs it automatically seeds the demo markets, accounts and prices.

> **Security note:** Firestore *test mode* allows open read/write for a limited period,
> which is fine for a class demo. For production use, tighten the Firestore security rules.

---

## 3. Getting the Android APK

You do **not** need Android Studio.

**Automatic cloud build (recommended)**
1. Push this project to a GitHub repository.
2. GitHub Actions runs the workflow in `.github/workflows/build-apk.yml` automatically
   (you can also start it manually from the **Actions** tab → *Build Android APK* →
   *Run workflow*).
3. When the run finishes, open it and download **`KrishiBondhu-apk`** from the
   **Artifacts** section. Copy `app-release.apk` to an Android phone and install it
   (allow "install from unknown sources").

**Local build (if you have the Android SDK + JDK 17)**
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The APK runs fully in local mode. To make the installed app sync across devices too,
connect Firebase on mobile with `flutterfire configure` (see the FlutterFire docs) and
rebuild — the web build already supports live sync via the config in `web/index.html`.

## 4. iOS

The project is iOS-ready (an `ios/` folder is included and the Dart code is
cross-platform). Building an installable iOS app requires a **Mac with Xcode** and an
Apple Developer account — an Apple platform restriction, not a limit of the app. On a Mac:
```bash
flutter build ios --release   # then archive & sign in Xcode
```

## 5. Verifying live sync

1. Open the deployed link on two devices (or two browser windows).
2. Log in as **Trader** (`mehedi` / `1234`) on one and **Farmer** (`rosni` / `1234`) on the other.
3. Submit a crop price on the trader device — it appears on the farmer's market screen
   within a couple of seconds.
