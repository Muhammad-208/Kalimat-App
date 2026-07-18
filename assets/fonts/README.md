# Fonts (drop the .ttf files here)

All four families are **SIL Open Font License** — free to bundle and
redistribute inside a closed-source Play app. Download and place the exact
filenames referenced in `pubspec.yaml`:

| Family              | Files                                                                 | Source |
|---------------------|-----------------------------------------------------------------------|--------|
| ReemKufi            | `ReemKufi-Regular.ttf`, `ReemKufi-Bold.ttf`                           | Google Fonts / GitHub: alif-type/reem-kufi |
| Amiri               | `Amiri-Regular.ttf`, `Amiri-Bold.ttf`                                 | Google Fonts / aliftype.com |
| AmiriQuran          | `AmiriQuran-Regular.ttf`                                              | Amiri project (Quran variant) |
| IBMPlexSansArabic   | `-Regular / -Medium / -SemiBold / -Bold.ttf`                          | Google Fonts / IBM Plex |

Quick fetch (Google Fonts mirrors):
    # example — verify the license file ships too
    curl -L -o Amiri-Regular.ttf   https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf
    curl -L -o AmiriQuran-Regular.ttf https://github.com/google/fonts/raw/main/ofl/amiriquran/AmiriQuran-Regular.ttf

After adding them, run `flutter pub get`. Until they're present, text falls
back to the system font (the app still runs).
