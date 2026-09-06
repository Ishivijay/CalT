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

**Log a meal by photographing it. Get a coach that reads your diary and tells you something the numbers don't.**

CalT is an Android-first, open-source nutrition tracker. Underneath it is a complete, conventional food diary — search, barcodes, macros, recipes, weight and water. On top of that sit the two features CalT was actually built for, and the rest of this page is mostly about them.

> **CalT is built on [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)** by [@simonoppowa](https://github.com/simonoppowa) and its contributors, and remains licensed under the GPL-3.0. That project provides the entire foundation described below — the food databases, diary, calorie and macro engine, and encrypted local storage. See [Credits](#credits).

The Android package ID is `com.calt.tracker`, so it installs alongside OpenNutriTracker rather than replacing it.

---

## The two features CalT adds

Both are opt-in, both run on **your own** AI key, and both send data straight from your phone to the provider you picked — CalT operates no server. [Setup takes about a minute.](#turn-the-ai-features-on)

### 1. Log with photo

<img src="docs/screenshots/03_photo_log.png" width="230" align="right" alt="The Log with photo screen">

Photograph the plate instead of describing it.

From the `+` menu, choose **Log with photo**, take a picture or pick one from your gallery, and optionally add a hint — *"large portion"*, *"cooked in butter"* — for anything the camera can't see. Tap **Estimate nutrition** and the photo goes to your AI provider, which comes back with an identified dish, an estimated portion weight, and a macro breakdown.

Nothing is saved until you say so. The estimate lands in the normal meal editor, where you can correct the name, adjust the grams, or fix a macro before it goes in the diary — the model proposes, you decide.

The photo itself is kept with the entry, so a week later the diary shows what you actually ate, not just a row of numbers.

Needs a vision-capable model. `gemini-flash-latest` handles it on the free tier.

<br clear="right">

### 2. CalT Coach

<img src="docs/screenshots/05_coach.png" width="230" align="right" alt="The CalT Coach screen">

Most trackers can already tell you that you ate 40g of protein. That's a readout, not coaching — you can see it on the dashboard.

So the coach is explicitly instructed **not** to restate figures you can already read. Every point has to add something you couldn't get from glancing at the numbers: a pattern across meals, a food-choice tradeoff, or a consequence of how you ate that isn't obvious from the totals. It reviews only *today's* logged food and activity, in three short points — one non-obvious thing going well, one gap or risk, one realistic fix naming specific foods.

A one-line summary of that review sits on the Home dashboard, so you get the gist without opening the tab.

Two things worth calling out:

- **The prompt is yours.** The exact instructions the coach is given are visible in the app and editable in place. Don't like its tone, or want it to focus on fibre? Rewrite them.
- **You can argue with it.** Ask follow-up questions in the same screen; the conversation is kept locally on your device.

<br clear="right">

---

## Everything else it does

The conventional tracker underneath — all of it inherited from OpenNutriTracker and working without any AI key, offline:

- **Food logging** — text search across Open Food Facts and multi-source nutrition databases, barcode scanning, custom meals, and reusable recipes with ingredients
- **Dashboard** — daily calorie and macro targets as progress rings, derived from your age, height, weight, activity level and goal
- **Diary** — a month calendar tinted by how close each day landed to its goal, with per-day meal cards, macro breakdown and a micronutrient panel
- **Activity** — logged workouts with MET-based calorie burn, folded into the day's budget
- **Wellness** — weight tracking with a trend chart, water logging, and an intermittent-fasting timer
- **Your data** — AES-encrypted local storage, full export and import as a zip, and eight languages

## Screenshots

| Home | Add a meal | Diary | Profile |
|---|---|---|---|
| ![Home dashboard](docs/screenshots/01_home.png) | ![Add menu](docs/screenshots/02_add_menu.png) | ![Diary](docs/screenshots/04_diary.png) | ![Profile](docs/screenshots/06_profile.png) |

## Install on Android

1. Download the latest `CalT.apk` from [Releases](https://github.com/Ishivijay/CalT/releases/latest).
2. Open the downloaded file on your phone. If Android blocks it, allow installs from your browser or file manager under **Settings → Apps → Install unknown apps**, then open the file again.
3. Install and open CalT.

No Flutter setup, no build step — just download and install.

If Android reports that the package already exists with a different signature (e.g. you previously sideloaded a debug build), uninstall that old app first, then install this APK.

## Turn the AI features on

**Log with photo** and **CalT Coach** need an AI key, which you supply yourself — one connection powers both. Everything else in the app works without this. There's no CalT account and no subscription; you're talking to your own provider account, at your own cost, which for Gemini's free tier is nothing.

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

That's it — [Log with photo](#1-log-with-photo) and [CalT Coach](#2-calt-coach) are both live. The coach writes its first review as soon as you've logged something today.

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
