# LIFE CITY cloud device testing setup

This workflow is separate from the APK build. It downloads a successful
`LIFE-CITY-Android-APK` artifact from `godot-migration` and runs both cloud services.

## 1. Configure GitHub repository settings

Open **Settings → Secrets and variables → Actions** in
`LifeCity2026Game/CITY`.

Add this repository variable:

- `FIREBASE_PROJECT_ID`: the Firebase / Google Cloud project ID (not its display name).

Add these repository secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: the full JSON key content for a dedicated Google
  Cloud service account in that Firebase project. Grant only the permissions needed
  to execute Firebase Test Lab and write test results. Do not commit this JSON or send
  it in chat.
- `APPETIZE_API_TOKEN`: create an API token in Appetize under **Organization → API
  Tokens**. Use the least-privileged role that can upload Android apps. Keep it in
  GitHub Secrets; never commit it.

Firebase setup reference:
https://firebase.google.com/docs/test-lab/android/get-started

Appetize token and upload references:
https://docs.appetize.io/account/api-tokens
https://docs.appetize.io/platform/app-management/uploading-apps
https://github.com/appetizeio/github-action-appetize

## 2. Run the cloud tests

After adding the credentials, open **Actions → LIFE CITY cloud device tests → Run
workflow**. Select branch `godot-migration`. Leave `build_run_id` empty to use the
latest successful Android APK build on that branch. You may enter a specific successful
build run ID to test an older artifact.

- Firebase Test Lab runs a Robo exploration on a Pixel 6 / Android 14 configuration
  and collects screenshots, video, logs and crash details.
- Appetize uploads the same APK and publishes an interactive browser preview URL in
  the workflow summary.

If credentials are not configured, the workflow reports which integration is waiting
for setup and skips that cloud job; it does not pretend a test passed.

## 3. What these services do and do not prove

Robo is useful for launch/crash/basic UI exploration, but Godot renders most game UI
inside a graphics surface. Robo cannot reliably assert game-specific actions such as
entering every floor, transferring ownership or issuing military commands.

Appetize is for visual/manual interaction and screenshots. It is not a substitute for
Firebase device coverage or the user's real phone.

For reliable game-specific verification, LIFE CITY still needs in-game automated
test scenarios and assertions (e.g. each of the 10 General Staff floors, wedding hall,
Presidential Palace, each vehicle, service actions and save/reload). Multiplayer must
also be tested with two separate clients. A cloud test passing is not proof that all
these features are implemented correctly.

## 4. Cost and privacy

Check Firebase Test Lab quotas/pricing and Appetize plan limits before running repeated
matrices. The test APK and any data it contains are uploaded to the respective providers.
Use test accounts and non-sensitive game data.
