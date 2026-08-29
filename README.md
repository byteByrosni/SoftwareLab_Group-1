# KrishiBondhu

**Weather-Based Crop Advisory and Smart Market Price Comparison App for Farmers**

KrishiBondhu is a Flutter PWA/mobile app for farmers. It combines weather
forecasts, crop advice, nearby market prices, price reporting, and reminders in
a bilingual English/Bangla interface.

## Features

- User registration and login with phone/email, role, location, and crops.
- Demo and live weather modes using Open-Meteo for live forecasts.
- Crop-specific weather advisory and severe-weather alerts.
- Nearby market price comparison and crowd-sourced price reporting.
- Target price alerts and smart reminders.
- Cross-device sync through the local Node/Express/Prisma backend.
- PWA install support for mobile browsers.

## Technology

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), Material 3, PWA web build |
| Backend/API | Node.js, Express |
| Database | SQLite through Prisma |
| Local cache | shared_preferences |
| Weather API | Open-Meteo, no API key required |
| Demo tunnel | ngrok to the local backend server |

## Recommended Demo Setup

Build the Flutter web app, start the backend, then expose that same backend with
ngrok. The backend serves both `build/web` and `/api`, so all phones use one URL
and share the same SQLite database.

```powershell
cd "C:\Users\Rosni Bente\Downloads\SoftwareLab_Group-1"
flutter build web --release

cd backend
npm install
npm run prisma:deploy
npm start
```

In another terminal:

```powershell
ngrok http --domain=bootlace-pacify-crisped.ngrok-free.dev 4000
```

Open `https://bootlace-pacify-crisped.ngrok-free.dev` on every device.

For the one-tunnel setup, no `.env` file is required. Use `KB_API_BASE` only if
you serve the frontend from a different URL than the backend, or for native APK
builds.

See [DEMO_GUIDE.md](DEMO_GUIDE.md) for the full runbook and troubleshooting.
