#!/usr/bin/env python3
"""
test_apply_signing.py — guards tools/apply_signing.py against silent no-ops.

Regression this exists for: the idempotency check used to test for
"signingConfigs", which the *stock* flutter template already contains via
`signingConfig = signingConfigs.getByName("debug")`. Every fresh bootstrap
therefore reported "already present" and injected nothing, and CI quietly
produced debug-signed APKs that cannot install over an upload-signed build.

Run:  python3 tools/test_apply_signing.py
"""
import sys

import apply_signing as A

# Exactly what `flutter create` emits (Flutter 3.44, Kotlin DSL).
TEMPLATE = '''plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kalimat.kalimat"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.kalimat.app"
        minSdk = flutter.minSdkVersion
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
'''

failures = []


def check(name, ok):
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        failures.append(name)


print("pristine template must NOT look already-applied")
check("guard is false on the stock template", not A.already_applied(TEMPLATE))

print("injection")
out = A.inject(TEMPLATE)
check("loads key.properties", 'rootProject.file("key.properties")' in out)
check("declares a real signingConfigs block", "signingConfigs {" in out)
check("release can use the upload key", 'signingConfigs.getByName("release")' in out)
check("debug fallback retained", 'signingConfigs.getByName("debug")' in out)
check("applicationId preserved", 'applicationId = "com.kalimat.app"' in out)
check("flutter block preserved", 'source = "../.."' in out)
check("exactly one buildTypes block", out.count("buildTypes {") == 1)
check("braces balanced", out.count("{") == out.count("}"))

print("idempotency")
check("guard is true after injection", A.already_applied(out))
check("second run is a no-op", A.inject(out).count("signingConfigs {") == 1
      if not A.already_applied(out) else True)

if failures:
    print(f"\n{len(failures)} FAILED: {', '.join(failures)}")
    sys.exit(1)
print("\nall checks passed")
