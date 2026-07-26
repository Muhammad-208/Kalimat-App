# تفعيل المزامنة — Firebase setup

The sync code is built and wired, and the app already ships pointed at the
`kalimat-be25f` Firebase project (see `lib/firebase_options.dart` /
`android/app/google-services.json`). If Firebase init fails for any reason
the app falls back to fully offline with no sync — no code changes needed,
just config. To point it at a different project instead, follow the steps
below.

## What syncs
Only lightweight **user state** — currently the set of hidden sources — under
`users/{uid}` in Firestore. The dictionary is never uploaded; the app stays 100%
usable offline. Sign-in on a new device pulls your settings; changes push up.

## 1. Create the project
1. Go to the Firebase console → **Add project** (name it e.g. `kalimat`).
2. In **Build → Authentication → Sign-in method**, enable **Google** and
   **Email/Password**.
3. In **Build → Firestore Database**, create a database (production mode).

## 2. Connect the app (generates the real config)
Install the CLIs, then from the project root:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Pick your Firebase project and the platforms (Android now, iOS later). This:
- overwrites `lib/firebase_options.dart` with your real keys, and
- adds `android/app/google-services.json`.

After that, `main()` initializes Firebase automatically and the login buttons go live.

**Also update the Google server client id.** This project never applies the
`com.google.gms.google-services` Gradle plugin (`android/` is generated fresh
by `bootstrap.sh`, which doesn't add it), so `google_sign_in` can't read the
plugin-generated `default_web_client_id` resource on its own. Instead
`lib/data/auth/auth_service.dart` passes the "Web client" OAuth client id
(type 3) from `google-services.json` explicitly via `GoogleSignIn(serverClientId:
...)`. After running `flutterfire configure`, copy the new `client_id` under
`oauth_client` (`client_type: 3`) in your `google-services.json` into the
`_googleServerClientId` constant at the top of `auth_service.dart` — otherwise
Google sign-in will silently keep requesting tokens for the old project.

## 3. Android signing fingerprint (required for Google sign-in)
Google sign-in needs your app's **SHA-1** (and SHA-256) registered:
```bash
# debug key (for testing)
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```
Add the SHA-1/SHA-256 in Firebase console → Project settings → your Android app →
**Add fingerprint**. Re-download `google-services.json` if prompted. Do the same
with your **release** keystore before publishing (see the Play steps in README §8).

Also confirm `android/app/build.gradle` has `minSdkVersion 23` (Firebase Auth/Firestore).

## 4. Firestore security rules
Lock each user to their own document:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 5. Verify
`flutter run`, open **الإعدادات → تسجيل الدخول للمزامنة**, sign in with Google or
email. The card should switch to "مُسجَّل الدخول · تتم المزامنة" with your email,
and toggling a source should write to `users/{uid}` in Firestore.

## Where it lives in code
- `lib/data/auth/auth_service.dart` — Google + email/password.
- `lib/data/sync/sync_service.dart` — Firestore push/pull.
- `lib/providers.dart` — `authServiceProvider`, `authStateProvider`, `syncServiceProvider`,
  `firebaseReadyProvider`.
- `lib/features/auth/auth_screen.dart` — the wired login UI.
- Pull on sign-in + push on change are handled in the auth screen and settings.

## Extending the payload
Add fields to the `users/{uid}` map in `SyncService.push` (theme, bookmarks,
recent searches) and apply them on pull — same pattern as `hiddenSources`.
