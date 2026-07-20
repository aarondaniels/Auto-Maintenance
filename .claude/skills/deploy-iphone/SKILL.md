---
name: deploy-iphone
description: Deploy the Flutter client as a release build to Aaron's physical iPhone. Use when asked to deploy, install, or update the app on the (physical) phone/device — not the simulator.
---

# Deploy to Aaron's iPhone

Deploys a **release** build of `client/` to the physical iPhone. Verified
working 2026-07-19 (first successful deploy).

## Known-good facts

| What | Value |
|---|---|
| Flutter device id | `00008150-001C048A36F0401C` |
| Device name | "Some guy's iphone" (iPhone 17 Pro) |
| Apple team id | `BCR8SWJV4B` (paid developer account) |
| Signing | Automatic, cert "Apple Development: Aaron Daniels" in login keychain |
| Bundle id | `com.automaint.autoMaintClient` |

## Procedure

1. **Confirm the phone is reachable** (must say `connected`, not `unavailable`):

   ```bash
   xcrun devicectl list devices | grep -i iphone
   ```

   If `unavailable`: phone must be **unlocked** and on the same Wi-Fi as the
   Mac; a USB cable forces the reconnect immediately and is the reliable
   fallback.

2. **Deploy** (MUST run from `client/` — from the repo root it fails with
   "No pubspec.yaml file found"):

   ```bash
   cd client && flutter run --release -d 00008150-001C048A36F0401C
   ```

   Run it in the background and watch the log for
   `Installing and launching` / `error` / `failed`. A release deploy stays
   valid for ~1 year (paid account). On-device app data survives redeploys
   of the same bundle id.

3. If the device id has changed (new phone), find it with `flutter devices`
   (look under "wirelessly connected devices").

## Troubleshooting (each of these actually happened)

| Symptom | Cause → fix |
|---|---|
| "enable Developer Mode in Settings" | Developer Mode off on the phone. Phone: Settings → Privacy & Security → Developer Mode → on → phone restarts → **must tap "Turn On" at the post-restart prompt** or it silently stays off. |
| Device `unavailable` in `devicectl` after the Developer Mode restart | Pairing hasn't re-established. Unlock phone; same Wi-Fi; or plug in USB. |
| `errSecInternalComponent` during codesign | CLI `codesign` lacks keychain access to the signing key (fresh keys start locked down). One-time fix: run once from Xcode GUI (▶ with the iPhone selected) and click **Always Allow** on the keychain prompt — this permanently adds codesign to that key's access list. Explain to Aaron what the prompt grants (see explain-prompts memory). |
| `0 valid identities found` / no `DEVELOPMENT_TEAM` in project.pbxproj | Xcode not signed in or team not selected. Xcode → Settings → Accounts → add Apple ID; then Runner target → Signing & Capabilities → Team. |
| "Untrusted Developer" on first launch | Phone: Settings → General → VPN & Device Management → trust the developer cert (applies only to team BCR8SWJV4B apps). |

## Verify

`xcrun devicectl device info apps --device CD05FB3B-78DB-5E10-93A4-F81DF87DB939 | grep -i automaint`
should list the bundle — or just ask Aaron to launch it from the home screen.
