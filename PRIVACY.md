# Privacy

This is a plain description of what CalT actually does with your data, written to match the current code — not a law firm's boilerplate. If you need a policy for a store listing or a formal compliance review, use this as the factual starting point and have it checked.

## What stays on your device

Your profile, meals, activities, weight and water logs, and recipes are stored locally in an AES-256 encrypted database. CalT has no server of its own — there is nothing for a "CalT backend" to see, because there isn't one.

Data export/import produces a `.zip` file you control; nothing is uploaded anywhere as part of that flow.

## Food search

Searching for food or scanning a barcode sends your query (or the barcode) to whichever food databases you've enabled in **Settings → Food databases** — Open Food Facts and/or a multi-source nutrition backend (USDA FoodData Central, BLS, and others). Those requests go to those services directly, under their own privacy terms; CalT doesn't see or log them.

## Optional AI features (BYOK)

Photo-based meal estimates and CalT Coach are both opt-in and bring-your-own-key: you connect your own OpenAI, Gemini, Anthropic, or OpenAI-compatible account in **Settings → AI Provider**. Your API key is stored in your device's encrypted secure storage. When you use these features, the relevant data — a meal photo for estimation, or today's logged meals for a coaching review — is sent directly from your device to the provider you chose. CalT does not run its own AI backend and never sees this traffic.

## Optional crash reporting

CalT can send anonymous crash reports via Sentry, but only in a release build and only if you opt in — the toggle is in **Settings → Privacy**, off by default. If you don't opt in, nothing is sent.

## What CalT never does

No accounts, no ads, no analytics or trackers beyond the crash-reporting opt-in above, and no data sold or shared for any purpose.

## Questions

Open an issue: https://github.com/Ishivijay/CalT/issues
