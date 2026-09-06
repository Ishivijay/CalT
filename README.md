<p align="center">
  <img src="docs/logo.png" width="128" alt="CalT logo">
</p>

<h1 align="center">CalT</h1>

<p align="center"><em>A frictionless calorie tracker</em></p>

<p align="center">
  <a href="https://github.com/Ishivijay/CalT/releases/latest"><img src="https://img.shields.io/github/v/release/Ishivijay/CalT?label=download%20apk&color=C7401F" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/platform-Android-141210" alt="Android">
  <img src="https://img.shields.io/badge/license-GPL--3.0-141210" alt="GPL-3.0">
</p>

CalT is an Android-first, open-source nutrition tracker with a searchable food diary, barcode lookup, photo-based meal estimates, and an optional personal AI coach.

> **CalT is built on [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)** by [@simonoppowa](https://github.com/simonoppowa) and its contributors. That project provides the foundation CalT is built from — the food databases, diary, calorie and macro engine, and local encrypted storage. CalT adds a redesigned interface, photo-based logging, and the AI coach on top of it, and remains licensed under the GPL-3.0. See [Credits](#credits).

This is a working Flutter application. The Android package ID is `com.calt.tracker`, so it installs separately from OpenNutriTracker.

## How it works

1. Create a profile with your age, height, weight, activity level, and goal.
2. Log meals by searching, scanning a barcode, quick-adding, building a recipe, or reviewing an AI photo estimate.
3. Follow calories and macro targets from the compact home dashboard.
4. Optionally connect your own OpenAI, Gemini, Anthropic, or OpenAI-compatible provider in **Settings → AI Provider**. CalT Coach uses the profile and today's logged meals to give a concise, non-medical review and answer follow-up questions.

Your diary is stored locally on-device. API keys are kept in encrypted platform storage and are only used when you choose an AI feature.

## Features

- Daily calorie and macro targets with progress rings
- Meal diary with edit, delete, calendar, recipes, and activities
- Food search, custom meals, barcode lookup, and photo meal logging
- CalT Coach: concise, profile-aware daily meal review, an editable prompt, and a persistent local chat
- Weight and water tracking, fasting timer, trends, data export/import, and offline-friendly local storage

## Screenshots

| Home | Add a meal | Log with photo |
|---|---|---|
| ![Home dashboard](docs/screenshots/01_home.png) | ![Add menu](docs/screenshots/02_add_menu.png) | ![Log with photo](docs/screenshots/03_photo_log.png) |

| Diary | CalT Coach | Profile |
|---|---|---|
| ![Diary](docs/screenshots/04_diary.png) | ![CalT Coach](docs/screenshots/05_coach.png) | ![Profile](docs/screenshots/06_profile.png) |

## Install on Android

1. Download the latest `CalT.apk` from [Releases](https://github.com/Ishivijay/CalT/releases/latest).
2. Open the downloaded file on your phone. If Android blocks it, allow installs from your browser or file manager under **Settings → Apps → Install unknown apps**, then open the file again.
3. Install and open CalT.

No Flutter setup, no build step — just download and install.

If Android reports that the package already exists with a different signature (e.g. you previously sideloaded a debug build), uninstall that old app first, then install this APK.

## Optional AI setup

CalT works fully without AI — search, barcodes, the diary and the dashboard all run offline. Two features are opt-in and need a key you supply yourself: **Log with photo** and **CalT Coach**. One connection powers both.

### Worked example: Gemini

1. **Get a key.** Go to [Google AI Studio](https://aistudio.google.com/apikey) and create an API key. Gemini has a free tier that's enough for daily use.
2. **Open the settings.** In the app, go to the **You** tab → **AI features** → **AI Provider (BYOK)**. (The same screen is reachable from Settings, or from the provider tile inside CalT Coach.)
3. **Fill in three fields:**

   | Field | Value |
   |---|---|
   | Provider | `Gemini` |
   | Model ID | `gemini-flash-latest` |
   | API key | paste the key from step 1 |

   Leave **Base URL** alone — it only appears for *Custom OpenAI-compatible* providers.
4. **Tap "Test connection".** You should get a success message within a couple of seconds. If it fails, the message says why — usually a mistyped key or a model your account can't reach.
5. **Tap "Save securely".** The key is written to encrypted device storage, never to the diary database, logs, or crash reports.

### What that unlocks

- **Log with photo** — the `+` menu → **Log with photo** → take or pick a photo → **Estimate nutrition**. The photo is sent to Gemini, which returns an estimated meal and macros; you review and edit before anything is saved.
- **CalT Coach** — the Coach tab shows a three-point review of *today's* food and activity, and a one-line summary on the Home card. You can ask follow-up questions, and edit the instructions the coach is given from the same screen.

### Other providers

| Provider | Example Model ID |
|---|---|
| Gemini | `gemini-flash-latest` |
| OpenAI | `gpt-4o-mini` |
| Anthropic | `claude-haiku-4-5-20251001` |
| Custom OpenAI-compatible | your server's model name, plus a **Base URL** like `https://host/v1` |

Requests go directly from your phone to the provider you picked — CalT has no server in between. Your account needs access to the chosen model and any billing or quota it requires. Vision-capable models are needed for photo estimates; text-only models will still work for the coach.

AI responses are suggestions, not medical advice — review food estimates before saving them.

## Building from source (contributors)

Most people should just [install the APK](#install-on-android) above. If you're contributing code:

```sh
flutter pub get
flutter test test/features/home/presentation/widgets/intake_vertical_list_test.dart
flutter run --flavor full
```

## Credits

**[OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)** — the project CalT is built on, created by [@simonoppowa](https://github.com/simonoppowa) and its contributors. The unglamorous, correctness-critical half of a food tracker was already solved there: barcode scanning, the multi-source food database, TDEE and macro maths, AES-encrypted local storage, data export/import, and eight-language support. CalT would not exist without it, and every one of those subsystems is still doing the heavy lifting underneath.

What CalT adds on top: a rebuilt visual identity, photo-based meal logging, the CalT Coach (daily review, editable instructions, bring-your-own-key AI), and a reorganised dashboard and diary.

Also credited:

- **[Open Food Facts](https://world.openfoodfacts.org/)** — the collaborative food database behind search and barcode lookup.
- **USDA FoodData Central** and the other nutrition sources — see the in-app **Sources & References** screen for the full citation list.

## License

CalT is a derivative work of OpenNutriTracker and remains licensed under the [GNU General Public License v3.0](LICENSE), the same licence as the upstream project. If you distribute CalT or a modified version, the GPL-3.0 requires that you keep it under the same licence, credit the upstream project, and make your source available.

## Disclaimer

CalT is not a medical application. Nutrition estimates and AI-generated information may be inaccurate and should not replace advice from a qualified healthcare professional.
