# Release signing (Task 6) — copy-paste recipe

Do this **after** `bash bootstrap.sh` has generated `android/`. The keystore and
`key.properties` are **secrets** — they're already git-ignored (`*.jks`,
`*.keystore`, `key.properties`, `android/key.properties`). Never commit them.
Losing the upload key blocks all future updates on Play, so back it up somewhere
safe (password manager / offline).

---

## 1. Create the upload keystore (one-time)

```bash
keytool -genkey -v -keystore ~/kalimat-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Also grab this keystore's **SHA-1** and add it to Firebase (Project settings →
Android app → Add fingerprint) so Google Sign-In works on release builds:

```bash
keytool -list -v -keystore ~/kalimat-upload.jks -alias upload | grep SHA
```

---

## 2. `android/key.properties` (git-ignored — never commit)

Create it with your real values:

```properties
storePassword=<the store password you chose>
keyPassword=<the key password you chose>
keyAlias=upload
storeFile=/home/YOU/kalimat-upload.jks
```

`storeFile` must be an absolute path (or relative to `android/app/`). Keep the
`.jks` outside the repo.

---

## 3. Wire the signing config into gradle

`flutter create` emits **one** of two build files. Edit whichever you have.

### 3a. Kotlin DSL — `android/app/build.gradle.kts` (Flutter ≳ 3.29 default)

At the **top** of the file (before `plugins { … }`):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Inside `android { … }`, add a `signingConfigs` block and point `release` at it.
Also pin `minSdk` and the `applicationId`:

```kotlin
android {
    defaultConfig {
        applicationId = "com.kalimat.app"
        minSdk = 23                       // Firebase Auth needs >= 23
        // targetSdk / versionCode / versionName stay as flutter created them
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // isMinifyEnabled / shrinkResources optional
        }
    }
}
```

### 3b. Groovy — `android/app/build.gradle` (older Flutter)

At the **top**, above `android { … }`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside `android { … }`:

```groovy
android {
    defaultConfig {
        applicationId "com.kalimat.app"
        minSdkVersion 23                  // Firebase Auth needs >= 23
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

> `bootstrap.sh` already rewrites `applicationId` to `com.kalimat.app` and runs
> `tools/apply_signing.py`, which injects the block above automatically — the
> manual edit is only needed if you are wiring this by hand.
>
> **minSdk:** current Flutter already defaults `flutter.minSdkVersion` to 24,
> which clears Firebase Auth's floor of 23. Pinning it explicitly is optional.

---

## 3c. Signing in CI (GitHub Actions)

`.github/workflows/build-apk.yml` signs with the upload key when these three
repository secrets exist, and silently falls back to the debug key when they
don't. **A debug-signed APK cannot be installed over an upload-signed one** —
Android rejects it with "Package signature does not match the installed app" —
so set these if you want CI builds to update your phone in place.

Add at **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | output of `base64 -w0 ~/kalimat-upload.jks` |
| `KEYSTORE_PASSWORD` | the store/key password |
| `KEY_ALIAS` | `upload` |

The workflow logs which key it used — look for `Upload key configured` versus
the `signing with the DEBUG key` warning, and confirm the `Report signer` step
prints `CN=Kalimat` rather than `CN=Android Debug`.

> On a **public** repo, secrets are not exposed to pull requests from forks, but
> you are still storing signing-key material on a third party. That is a
> deliberate trade-off — the alternative is building releases locally only.

---

## 4. Build the release bundle

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Verify it's signed with your upload key, not the debug key:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab | head
```

Then upload the `.aab` to Play Console → internal testing first.

---

## 5. Before rollout

Settle the **licensing** decision (README §9): the morphology data is GPL, so the
app ships open-source under a GPL-compatible license. Confirm this before the
public Play rollout, and complete the Data-safety form (if sync is on: declare
account + synced settings; the dictionary stays on-device).
```
