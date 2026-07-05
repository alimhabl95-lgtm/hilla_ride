# Hello Tuk-Tuk — Native iOS App

Native Swift/SwiftUI iPhone app for Hello Tuk-Tuk. Shares the same Firebase backend as the Flutter Android app in the parent repo.

## Requirements

- Xcode 16+
- iOS 16.0+ deployment target
- Apple Developer Team: `XAZ6V7UTYT`
- Bundle ID: `com.hillaride.hillaRide`

## Open in Xcode

```bash
open HelloTukTuk.xcodeproj
```

Select the **HelloTukTuk** scheme, choose a device or simulator, and run.

## Phase 0 (current)

- SwiftUI app shell
- Firebase Auth, Firestore, Messaging, Functions (SPM)
- Mode chooser (Customer / Driver)
- Login + customer signup (matches Flutter phone→email auth)
- Arabic / English toggle
- Placeholder home after login

## Firebase

- Project: `hello-tiktok-57dc5`
- Config: `HelloTukTuk/GoogleService-Info.plist`
- Auth pattern: Iraqi phone `7701234567` → `9647701234567@hello-tiktok.app`

## Codemagic / TestFlight

### One-time setup in Codemagic (required)

If you only see **"Default Workflow"** with Flutter options, Codemagic is using the **UI editor**, not this repo’s YAML.

1. Open [Codemagic](https://codemagic.io) → your **hilla_ride** app  
2. Click **App settings** (gear icon)  
3. Under **Build configuration**, choose **codemagic.yaml** (not Workflow Editor)  
4. Save  

### Start a native Swift build

1. Click **Start new build**  
2. Select workflow: **Hello Tuk-Tuk Native iOS**  
3. Branch: **master**  
4. Start build  

Pushes to `master` auto-trigger this workflow when YAML mode is enabled.

Expected TestFlight version: **2.0.0 (61)** — not 1.0.59 (Flutter).

The repo root `codemagic.yaml` contains **only** the native Swift workflow (Flutter iOS CI was removed to avoid wrong builds).

## Next phases

| Week | Focus |
|------|--------|
| 1 | Auth polish, forgot password, driver signup, TestFlight |
| 2 | Google Maps, customer home |
| 3 | Book ride, pricing |
| 4+ | Driver flow, chat, notifications |

## Notes

- The Flutter `ios/` folder in the parent repo is kept as backup — do not delete.
- Android remains Flutter in `../lib/`.
- Add a 1024×1024 app icon to `HelloTukTuk/Assets.xcassets/AppIcon.appiconset/` before App Store submission.
