# ACUC Jobs — iOS & Android app

The ACUC store app is a native shell (Capacitor 8) around **https://acuc.jobs**. Every screen is the live website, so anything you change on the site is in the app immediately — no new app release needed. The shell adds what a website can't do:

| Feature | How it works |
|---|---|
| **Push notifications** | Every ACUC notification (messages, applications, job updates, friend requests…) is also sent to the phone via Firebase Cloud Messaging. Tapping one opens the right screen. |
| **Face ID / fingerprint sign-in** | After signing in, the app offers biometric sign-in. A device key (kept in the iOS Keychain / Android Keystore, rotated on every use, valid 90 days) signs the person back in. |
| **Native Google sign-in + Sign in with Apple** | Google blocks its sign-in inside apps, so the app signs in natively; WordPress verifies the token and links or creates the ACUC account. Apple sign-in on iPhone (required by Apple when Google sign-in is offered). |
| **acuc.jobs links open in the app** | Universal Links (iOS) and App Links (Android), served by WordPress at `/.well-known/`. |
| **Camera, photos & files** | CV and photo uploads use the phone's camera, gallery and Files. Downloads (CV PDFs) open the share sheet. Microphone for the voice agent. |
| **App settings** | In the menu: notifications, Face ID on/off, privacy policy, **Delete my account** (required by Apple). |
| **Instant, app-like** | White splash with the ACUC logo, no white flashes, Android back button, offline screen, forced-update prompt. |

Server side: `assets/mu-plugins/acuc-native-app.php` (+ `acuc-native-app/bridge.js|css`). Settings: **WP Admin → Settings → ACUC App**.

---

## 1. One-time setup (about 1–2 hours)

### A. WordPress
1. Upload the website zip (the `acuc.jobs/…` files) as usual; purge LiteSpeed and Cloudflare.
2. Open **Settings → ACUC App**. You'll fill it in as you go through B–D below.

### B. Firebase (push + Google sign-in) — console.firebase.google.com
1. Create a project **ACUC Jobs** (Analytics optional).
2. **Add an Android app**: package `jobs.acuc.app`. Add the SHA-1 and SHA-256 fingerprints of your **upload key** (step D2) and, after your first Play upload, of the **Play app signing key**. Download `google-services.json`.
3. **Add an iOS app**: bundle ID `jobs.acuc.app`. Download `GoogleService-Info.plist`.
4. **Cloud Messaging → Apple app configuration**: upload the APNs Auth Key (.p8) from step C2.
5. **Authentication → Sign-in method**: enable **Google** and **Apple**. Copy the Google provider's **Web client ID** and paste it into WordPress → *Google client IDs for the app*. (Also paste the `CLIENT_ID` from `GoogleService-Info.plist`.)
6. **Project settings → Service accounts → Generate new private key**. Paste the whole JSON into WordPress → *Firebase service account* and Save. (Or put the file outside the web root and define `ACUC_FCM_SERVICE_ACCOUNT_FILE` in wp-config.php.)

### C. Apple — developer.apple.com / appstoreconnect.apple.com
1. **Identifiers → App ID** `jobs.acuc.app` with capabilities: **Push Notifications**, **Associated Domains**, **Sign in with Apple**.
2. **Keys → +** with *Apple Push Notifications service (APNs)* → download the .p8 → upload it to Firebase (B4).
3. Copy your **Team ID** (Membership) into WordPress → *Apple Team ID*. This switches on iPhone app links.
4. **App Store Connect → My Apps → +**: new iOS app, bundle `jobs.acuc.app`, name *ACUC Jobs*.
5. **Users and Access → Integrations → App Store Connect API → +** (role *App Manager*). Keep the Key ID, Issuer ID and the .p8 for CI.

### D. Google Play — play.google.com/console
1. **Create app** *ACUC Jobs* (App, Free).
2. Create your **upload key** once, on your computer, and keep it safe (back it up — you need it for every update):
   ```bash
   keytool -genkeypair -v -keystore acuc-upload.jks -alias acuc -keyalg RSA -keysize 4096 -validity 10000
   keytool -list -v -keystore acuc-upload.jks -alias acuc   # shows the SHA-1 / SHA-256 for Firebase
   ```
3. After the first upload (step 3 below), **Setup → App signing**: copy the **App signing key SHA-256** into WordPress → *Android SHA-256 fingerprints* (one per line, the upload key's too) and into Firebase (B2). This switches on Android app links and Google sign-in.
4. For automatic uploads: **Setup → API access** → link a Google Cloud project → create a service account → grant it *Release manager* in Play Console → download its JSON key.

### E. GitHub (builds both apps in the cloud — no Mac needed)
1. Create a **private** repository and push this folder to it.
2. **Settings → Secrets and variables → Actions → New repository secret** for each:

| Secret | Value |
|---|---|
| `GOOGLE_SERVICES_JSON_B64` | `base64 -i google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST_B64` | `base64 -i GoogleService-Info.plist` |
| `ANDROID_KEYSTORE_B64` | `base64 -i acuc-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` | the passwords you chose |
| `ANDROID_KEY_ALIAS` | `acuc` |
| `PLAY_SERVICE_ACCOUNT_JSON` | contents of the Play service-account JSON (D4) |
| `APPLE_TEAM_ID` | your Team ID |
| `ASC_KEY_ID` / `ASC_ISSUER_ID` | from C5 |
| `ASC_KEY_P8_B64` | `base64 -i AuthKey_XXXX.p8` |

(On Windows: `certutil -encode file out.txt`, then copy the text between the BEGIN/END lines.)

## 2. Build
- **Actions → Android release → Run workflow** → produces the signed `.aab` (Play) and `.apk` (testing), and uploads to the *Internal testing* track.
  - The **very first** Play upload must be done by hand: download the `.aab` artifact and upload it in Play Console → *Testing → Internal testing*. After that the workflow uploads automatically.
- **Actions → iOS release → Run workflow** → archives, signs (automatic signing via the API key) and uploads to **TestFlight**.
- Pushing a tag like `v1.0.0` runs both.

## 3. Test before submitting
1. Install from TestFlight / Internal testing.
2. Open the app → sign-in screen appears instantly. Sign in with password, Google, and (iPhone) Apple.
3. Accept notifications; in WordPress → Settings → ACUC App → **Send test notification**. Tap it → the app opens on Notifications.
4. Turn on Face ID / fingerprint, sign out, reopen → "Sign in with Face ID".
5. Open an `https://acuc.jobs/...` link from WhatsApp/Notes → it opens in the app (Android needs step D3 done).
6. Upload a CV and a profile photo (camera + files); talk to the voice agent (microphone).
7. Menu → App settings → check every row (don't delete your real account!).

## 4. Store submission notes
- **Apple review**: give a **demo account** (a jobseeker test login) in *App Review Information*. Mention: native push, Face ID sign-in, Sign in with Apple, in-app account deletion (Menu → App settings → Delete my account), native file/camera upload.
- **Privacy**: App Store *App Privacy* and Play *Data safety* — the app collects name, email, phone (profile), CV/files, photos, messages, device push token; used for app functionality; not sold; not used for tracking. Account deletion: in-app, and say so in Play's data-safety form (link `https://acuc.jobs/privacy-policy/`).
- Screenshots: iPhone 6.9" and 6.5", iPad 13" (the app supports iPad), Android phone. Use the live app.

## 5. Updating
- **Website changes**: nothing to do — the app shows the live site.
- **App (native) changes**: bump `version` in `package.json`, run both workflows.
- **Force an update**: WordPress → Settings → ACUC App → *Oldest app version allowed*.

## 6. Local development (optional)
```bash
npm ci
bash scripts/configure-firebase.sh   # with firebase/google-services.json + firebase/GoogleService-Info.plist present
npx cap sync
npx cap open android   # Android Studio (JDK 21)
npx cap open ios       # Xcode 16.3+ on a Mac
```
Icons/splash are generated from `assets/` with `npm run assets`.
