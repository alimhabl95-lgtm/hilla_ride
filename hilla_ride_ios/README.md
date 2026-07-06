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

1. Open [Codemagic](https://codemagic.io) → your **hilla_ride** app  
2. **App settings** → **Build configuration** → select **`codemagic.yaml`**  
3. **Team settings** → **Integrations** → **Developer Portal** → confirm API key named **`codemagic`** is connected  

### Code signing (required one-time setup)

The workflow uses **certificates and profiles stored in Codemagic Team settings** (not live fetch from Apple during the build). Your Flutter iOS builds already used `com.hillaride.hillaRide` — reuse the same signing files.

**In Codemagic → Team settings → Code signing identities:**

#### Option A — Generate new certificate in Codemagic (recommended if you have no .p12 file)

1. **iOS certificates** tab → **Generate certificate**
2. Type: **Apple Distribution**
3. API key: **codemagic**
4. Reference name: `hilla_ride_distribution`
5. Click **Create certificate** (download backup .p12 if offered)

#### Option B — Upload existing .p12 from your Mac

1. **iOS certificates** tab → **Upload certificate**
2. Upload your **Apple Distribution** `.p12` + password
3. Reference name: `hilla_ride_distribution`

#### Provisioning profile (keep in sync with certificate)

The **distribution certificate** and **provisioning profile** must match. If you regenerate the certificate, delete the old App Store profile and fetch a new one.

**Option A — automatic (recommended):** The Codemagic workflow refreshes the App Store profile on each build (`fetch-signing-files --create --delete-stale-profiles`). You only need the Team certificate `hilla_ride_distribution`.

**Option B — manual refresh in Codemagic UI:**

1. **iOS provisioning profiles** tab → delete the old `hilla_ride_appstore` profile if present
2. **Fetch profiles** → select **App Store** profile for **`com.hillaride.hillaRide`**
3. Reference name: `hilla_ride_appstore` → **Download selected**

If archive fails with *"Provisioning profile doesn't include signing certificate"*, the profile was created before your current distribution certificate — repeat Option B or re-run the build after commit that auto-refreshes profiles.

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
