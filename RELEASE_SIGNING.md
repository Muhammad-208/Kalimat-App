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

> `bootstrap.sh` already rewrites `applicationId` to `com.kalimat.app`. If you're
> on the Flutter template that reads `minSdk` from `flutter.minSdkVersion`, set
> the Flutter floor instead by leaving `minSdk = flutter.minSdkVersion` and
> ensuring your Flutter is recent enough — but the explicit `23` above is the
> safe, self-contained choice.

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
