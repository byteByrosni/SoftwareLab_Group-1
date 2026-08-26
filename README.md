# KrishiBondhu

**Weather-Based Crop Advisory and Smart Market Price Comparison App for Farmers**

KrishiBondhu is a cross-platform **Flutter** application that helps small and marginal
farmers make better daily decisions by combining weather forecasts and nearby market
price information into one simple, localized, bilingual (English / বাংলা) tool.

---

## Features

- **User authentication & profile** — register with phone/email, choose role
  (Farmer / Trader / General user), location and the crops you grow.
- **Weather forecast** — live 5-day forecast from the Open-Meteo API (free, no key).
- **Crop-specific advisory** — rule-based mapping of weather into plain-language,
  crop-aware farming actions.
- **Severe-weather emergency alerts** — storm / heavy-rain warnings.
- **Nearby market locator** — markets within a chosen radius, each with its distance.
- **Crowd-sourced price reporting** — any user can submit today's price for a crop at a
  market; every entry is tagged with the contributor and time.
- **Smart price comparison** — average / best price, sort by distance or price.
- **Target price & price alerts** — get notified when a nearby market reaches your target.
- **Smart task reminders** — irrigation / spraying reminders that **auto-reschedule**
  when the weather turns bad on their scheduled day.
- **Live cross-device sync** — with Firebase enabled, data submitted on one device
  appears on every other device in real time.
- **Bilingual, icon-based interface** — English and Bangla, switchable any time.

---

## Technology

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart), Material 3 |
| Live database / sync | Cloud Firestore (Firebase) |
| Local storage | shared_preferences |
| Weather API | Open-Meteo (no API key required) |
| Hosting | Firebase Hosting / Netlify (static web build) |

---

## Demo accounts

Three accounts in Chattogram come pre-loaded so every role can be shown. On the login
screen tap **Farmer**, **Trader** or **General user**, or type the ID / password:

| Role | Login ID | Password |
|------|----------|----------|
| Farmer | `rosni` | `1234` |
| Trader | `mehedi` | `1234` |
| General user | `nafisa` | `1234` |

---

## Running from source

```bash
flutter pub get
flutter run -d chrome      # or any connected device
```

## Building the web app

```bash
flutter build web --release
```

The output is written to `build/web/`, ready to deploy as a static site.

See **SETUP.md** for enabling live cross-device sync (Firebase) and for deployment steps.

---

## Team

- Nafisa Jahan — App UI/UX design and frontend development
- Rosni Akter — System architecture, backend development and API integration
- Md. Mehedi Hasan — Database design
