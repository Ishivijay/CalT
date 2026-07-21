# CalT — a frictionless calorie tracker

CalT is an Android-first nutrition tracker built on top of the open-source OpenNutriTracker project. It adapts that foundation into a distinct, compact calorie-tracking experience with a searchable food diary, barcode lookup, photo-based meal estimates, and an optional personal AI coach.

This is a working Flutter application. The Android package ID is `com.calt.tracker`, so it installs separately from OpenNutriTracker.

## Challenge category

**Health & Fitness**

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
- CalT Coach: concise, profile-aware daily meal review and persistent local chat history
- Weight and water tracking, fasting timer, trends, data export/import, and offline-friendly local storage
- Optional **Load 7-day CalT test diary** action from the Add (`+`) menu for repeatable demo data; **Remove CalT test meals** removes only those generated samples

## Run on Android

### Requirements

- Flutter stable (the project currently uses Flutter 3.44.7)
- Android SDK and either an Android device with USB debugging enabled or an Android emulator

### Install dependencies and run

```sh
flutter pub get
flutter devices
flutter run --flavor full
```

To build a sideloadable debug APK instead:

```sh
flutter build apk --debug --flavor full
```

The resulting APK is at:

```text
build/app/outputs/flutter-apk/app-full-debug.apk
```

Install it on a connected device with:

```sh
adb install build/app/outputs/flutter-apk/app-full-debug.apk
```

If Android reports that the package already exists with a different signature, uninstall that old app from the device first, then install the APK again.

## Optional AI setup

CalT works without an AI provider. To enable the photo estimate and CalT Coach:

1. Open **Settings → AI Provider (BYOK)**.
2. Select the provider that issued your key.
3. Enter a model ID supported by that provider and save the key.
4. Use **Test connection** before trying photo analysis or coaching.

The provider account must have access to the chosen model and any required billing or quota. AI responses are suggestions, not medical advice; review food estimates before saving them.

## Sample data for a demo

Open the Add (`+`) menu and choose **Load 7-day CalT test diary**. It creates one week of clearly marked example meals for demonstrating the dashboard, diary, calendar, and coach. It never loads automatically. Choose **Remove CalT test meals** to clean it up.

## Built with Codex and GPT-5.6

CalT was built iteratively with Codex using GPT-5.6. Codex accelerated the work by turning product feedback into working Flutter changes, including the separate CalT Android identity, compact dashboard, profile-aware coach prompts, local chat history, photo logging flows, test-data seeding, and Android build troubleshooting.

Key implementation decisions were made directly in the project:

- Keep the core diary local and usable without an AI subscription.
- Make AI opt-in and BYOK, using encrypted local key storage.
- Keep coach output tied to the person's profile and today's meals rather than generic wellness copy.
- Focus the challenge submission on the separate CalT Android build, with repeatable in-app sample data for judging.

For the demo video, show the profile, meal logging, dashboard, seven-day test diary, CalT Coach, and the Android APK running on a phone. Explain that Codex and GPT-5.6 were used to iterate from the product requirements to the final Flutter implementation.

## Validation

```sh
flutter test test/features/home/presentation/widgets/intake_vertical_list_test.dart
flutter build apk --debug --flavor full
```

## License and attribution

CalT is a derivative of OpenNutriTracker and remains licensed under the [GNU General Public License v3.0](LICENSE). It uses Open Food Facts and optional food-data backends; see the in-app **Sources & References** screen for nutrition references. The project has been materially adapted into the CalT Android experience described above.

## Disclaimer

CalT is not a medical application. Nutrition estimates and AI-generated information may be inaccurate and should not replace advice from a qualified healthcare professional.
