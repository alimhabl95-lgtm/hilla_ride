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

#### Provisioning profile (must match your certificate)

The **distribution certificate** and **App Store provisioning profile** must include the **same** Apple Distribution cert. If you see *"Provisioning profile doesn't include signing certificate"*, do this **once**:

**Step 1 — Apple Developer (fix the profile on Apple’s side)**

1. Open [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Find the **App Store** profile for **`com.hillaride.hillaRide`** (e.g. *Hello Tuk-Tuk ios_app_store*)
3. Either **Edit** it and check the box for **Apple Distribution: Ali Al-Isawi (XAZ6V7UTYT)**, then **Save**  
   **OR** delete the old profile and click **+** → **App Store Connect** → select app **`com.hillaride.hillaRide`** → select certificate **`Apple Distribution: Ali Al-Isawi`** → **Generate**
4. Download the new `.mobileprovision` if Apple offers a download (optional)

**Step 2 — Codemagic (download the updated profile)**

1. **Team settings → Code signing identities → iOS provisioning profiles**
2. **Delete** the old `hilla_ride_appstore` entry
3. **Fetch profiles** → select the **App Store** profile for **`com.hillaride.hillaRide`**
4. Reference name: `hilla_ride_appstore` → **Download selected**

**Step 3 — Rebuild** on branch `master` (workflow **Hello Tuk-Tuk Native iOS**)

Do **not** use `fetch-signing-files --create` in CI unless you also store `CERTIFICATE_PRIVATE_KEY` in Codemagic environment variables — it will fail with *"Cannot save Signing Certificates without certificate private key"*.

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
