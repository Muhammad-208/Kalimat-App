# كلمات · Kalimat — architecture & build

Offline-first Quranic-roots dictionary. Android APK for Google Play, Arabic-first,
RTL, light + night-reading themes. This repo is a **working Flutter starter** that
implements the Claude Design handoff (`Kalimat.dc.html`).

---

## 1. Why Flutter (the architecture recommendation)

Your app is a **content- and typography-heavy reader** over a **bundled read-only
SQLite** database, fully usable offline, with optional cloud sync. For that exact
shape, Flutter is the strongest fit:

- **One codebase → one signed `.aab`** for Play (and iOS later, free).
- **Total control of Arabic typography** — you need four families (Reem Kufi, Amiri,
  Amiri Quran, IBM Plex Sans Arabic) at precise sizes/letter-spacing. Flutter renders
  its own text, so a verse looks identical on every device.
- **First-class RTL** (`Directionality.rtl` app-wide) and light/dark theming.
- **Clean SQLite story** — bundle the prebuilt DB as an asset, copy once, query with
  `sqflite`. No ORM ceremony; your Python pipeline stays the source of truth.

Honest alternatives: **native Kotlin + Jetpack Compose + Room** gives the best raw
performance and tightest Play integration, but it's Android-only and more code for a
reading app. **React Native** works, but bundling/opening a prebuilt SQLite and pixel-
controlling custom Arabic fonts is fiddlier. If you're set on one of those, say so and
I'll re-target — but Flutter is my recommendation and what this starter is built in.

---

## 2. Layers

```
┌───────────────────────────────── UI (features/) ─────────────────────────────────┐
│  home_screen · word_result_screen · [comparison · verses · auth · admin — TODO]   │
│  Directionality.rtl · KTheme.light / KTheme.dark · shared/widgets.dart            │
├──────────────────────────────── State (Riverpod) ────────────────────────────────┤
│  providers.dart — repositoryProvider, themeModeProvider, FutureProviders          │
├───────────────────────────────── Domain (data/) ─────────────────────────────────┤
│  DictionaryRepository  (all reads; enforces furuq `verified = 1`)                 │
│  models: Root · LexiconEntry · WordOccurrence · Furuq                             │
├──────────────────────────────── Storage (sqflite) ───────────────────────────────┤
│  KalimatDb — copies assets/db/kalimat.db → app docs on first run, opens READ-ONLY │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Tablet & responsive layout

All screens adapt from phones up to 7"–13" tablets via `lib/theme/responsive.dart`:
content is centered and capped to a comfortable reading width (≈680dp; 820dp for the
two-column comparison; 460dp for the login form), so lines never stretch edge-to-edge on
large screens. Breakpoints: `tablet` = 600dp, `large` = 900dp. On phones it's a no-op.

### Editor tool (separate, local)

`tools/editor/` is a local Flask app for furuq review + `verified` toggling that exports
a clean `kalimat.db` (unverified stripped). It is **not** shipped in the APK. See
`tools/editor/README.md`.

**Read-only-on-device is deliberate.** The dictionary is authored offline and shipped
as a versioned artifact. To update content you rebuild `kalimat.db` and release; bump
`KalimatDb.bundledDbVersion` and the copy-if-newer check swaps it in.

---

## 3. What's built vs. scaffolded

| Design screen (in `Kalimat.dc.html`)      | Status |
|-------------------------------------------|--------|
| 1 · Home / search                         | ✅ built (`home_screen.dart`) |
| 2 · Word result (light)                   | ✅ built (`word_result_screen.dart`) |
| 4 · Word result (dark / night)            | ✅ built — same screen, `themeMode` toggle in the header |
| 3 · Comparison (بحر × يمّ)                 | ✅ built (`comparison_screen.dart`) |
| 5 · All occurrences (grouped by surah)    | ✅ built (`verses_screen.dart`) |
| 8 · Auth / login                          | ✅ UI built (`auth_screen.dart`); sync backend still TODO (see §5) |
| 6 · Admin / editor panel                  | ⬜ **should not ship in the public APK** (see §6) |
| 7 · Style tile                            | ✅ encoded as `theme/colors.dart` + `KFonts` |
| ➕ Source visibility (per-user settings)   | ✅ built (`settings_screen.dart`) — local show/hide of لexicon sources |

The two hero screens render the design's exact content because the seed DB carries it.

---

## 4. Hooking up your real data

The app never talks to `build_quran_db.py` / `build_furuq.py` directly. One bridge
script flattens your pipeline into the app schema:

```
build_quran_db.py ─┐
build_furuq.py    ─┼─►  tools/export_app_db.py  ─►  assets/db/kalimat.db  ─►  APK
reviewed content  ─┘        (schema.sql)                (versioned)
```

- `assets/db/schema.sql` — the app's contract (roots · lexicon_entries · words ·
  surahs · furuq · meta).
- `tools/build_sample_db.py` — already generated the seed `kalimat.db` you're running.
- `tools/export_app_db.py` — fill in the `TODO` SELECTs to match your source columns,
  then `python3 tools/export_app_db.py --quran … --furuq … --content … --version 2`.

Two invariants the code enforces: explanations are **pre-generated + reviewed** (copied,
never runtime-LLM), and **only `verified = 1` furuq** reaches users.

### Making it جامع — adding every source

There's no one-click way to pour a dozen 20-volume dictionaries into the app; the text
is huge and each edition is shaped differently. Instead there's an **engine** you run
once per source. "Add them all" = working down `tools/sources.py` (the master list —
14 sources across dictionaries / Quran-lexicons / furuq / Semitic).

```bash
python3 tools/sources.py                                   # the checklist + status
# get the source text (OpenITI mARkdown, Hawramani, or your Shamela scrape), then:
python3 tools/ingest_lexicon.py --source-id 3 --input lisan.txt --dry-run   # preview coverage
python3 tools/ingest_lexicon.py --source-id 3 --input lisan.txt             # commit
```

- `tools/normalize.py` — the matcher that files each entry under the right root
  (handles tashkeel, the ال article, and geminate roots like ربب/يمم). Tested.
- `tools/ingest_lexicon.py` — segments the text, matches, inserts, and writes a
  `review_source_N.tsv` listing FUZZY / UNMATCHED entries for you to check.
- Realistic expectations: not every root sits in every dictionary, and root-alignment
  isn't 100% — the review file is where the human step lives. Sources organized
  oddly (e.g. al-ʿAyn, phonetic order) need a small custom segmenter (marked in the file).
- Best source: **OpenITI** (github.com/OpenITI/RELEASE) — open-licensed, machine-readable,
  and many lexicons are root-organized, which is ideal for automatic matching.

Priority: build the skeleton first (مقاييس · الراغب · لسان العرب), then broaden. For
religious content, **accuracy beats breadth** — a reviewed source helps more than ten raw ones.

---

## 5. Auth & sync (offline-first)

The login screen says it plainly: *"الاستخدام متاح دون اتصال — الحساب للمزامنة فقط."*
So auth is **optional** and never blocks reading.

**Built (Firebase).** Google + email/password auth and Firestore sync of user state
(hidden sources) are implemented and wired to the login screen. They stay dormant — the
app runs fully offline — until you add your Firebase config. Turn it on by following
**SYNC_SETUP.md** (create project, `flutterfire configure`, add SHA-1, set Firestore
rules). Only user settings sync; the dictionary never leaves the device. Code:
`lib/data/auth/`, `lib/data/sync/`, `firebase_options.dart` (placeholder until configured).

---

## 6. The editor/admin panel — keep it out of the public app

Screen 6 manages users, roles (محرِّر / قارئ), settings, content editing and the furuq
`verified` toggles. **Do not bundle this into the APK every user installs.** Anything
that can flip `verified` or edit religious content is a privileged workflow. Options:

1. **Separate internal tool** (a small web app or a second "editor" build) that writes to
   your master DB, from which `export_app_db.py` produces the public artifact. Cleanest.
2. If it must live in-app, gate it behind server-verified editor roles and ship edits as
   a reviewed DB release — never let the shipped app mutate its own dictionary.

Either way, the public build is read-only; the review pipeline lives upstream.

---

## 7. App identity

- **Display name:** كلمات (Arabic) / "Kalimat". Set `android:label` per-locale
  (`values-ar/strings.xml` → كلمات, default → Kalimat).
- **Launcher icon:** the كلمات wordmark, Reem Kufi, teal `#0F5B52` on paper `#F4EEE1`,
  or a paper wordmark on a teal adaptive background. Put a 1024×1024 at
  `assets/icon/kalimat_icon.png` + a foreground at `assets/icon/kalimat_fg.png`, then
  `flutter pub run flutter_launcher_icons` (config already in `pubspec.yaml`).
- **applicationId:** e.g. `com.kalimat.app` (set in `android/app/build.gradle`). This is
  permanent on Play — choose carefully.

---

## 8. Ship to Google Play

```bash
flutter build appbundle --release        # produces app-release.aab
```

1. Create an **upload keystore**, set it in `android/key.properties` + `build.gradle`
   (keep the key safe — losing it means you can't update the app). Prefer Play App Signing.
2. Play Console → new app → upload the `.aab`.
3. **Data safety form:** if v1 has no account/backend, declare "no data collected."
   Once sync is added, declare account + synced fields.
4. Store listing in Arabic (+ English). Screenshots: the handoff's `screenshots/` are a
   starting point.
5. `minSdk` 23+, `targetSdk` = current Play requirement, test on a real RTL device.

---

## 9. ⚠️ Licensing — resolve before you publish

This is the one genuine blocker in your notes, and it affects whether you can ship at all:

- **Quranic Arabic Corpus morphology is GPL.** If your `roots`/`words` data is derived
  from it and you distribute it inside a closed-source Play app, the GPL's copyleft is a
  real problem. Paths: (a) open-source the app under a GPL-compatible license and comply
  with its terms, (b) source the morphology from a permissively-licensed dataset instead,
  or (c) get separate permission. **Confirm the provenance of every row before release.**
- **Fonts** — all four are SIL OFL: safe to bundle in a closed app (ship the OFL text).
- **Classical lexicon text** (al-Raghib, Lisan al-Arab, al-Askari via Shamela/OpenITI):
  the source works are public domain, but a *specific digital edition* may carry its own
  terms. Note your edition and keep attributions (`source` columns already do this).
- **Comparative-Semitic / loanword content** (Jeffery, Luxenberg debates): present as
  contested scholarship, which the design already does (◈ محل خلاف علمي). Keep that framing.

I'm not a lawyer and this isn't legal advice — but the GPL/corpus question is the item to
settle first, because it can force a licensing model on the whole app.

---

## 10. Run it

```bash
flutter pub get
# (optional) add the .ttf fonts — see assets/fonts/README.md
python3 tools/build_sample_db.py     # already run; regenerate anytime
flutter run
```

Search **بحر** to see the full word-result screen with the seed data, and tap the
moon/sun in its header for the night-reading theme.
