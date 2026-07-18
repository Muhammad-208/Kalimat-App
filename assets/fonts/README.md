# Fonts (vendored, SIL Open Font License)

All four families are **SIL Open Font License 1.1** — free to bundle and
redistribute inside a Play app. They are committed here so the project builds
and CI passes on a fresh clone; each family's license ships alongside it
(`OFL-*.txt`), as the OFL requires.

| Family              | Files                                                                 | Source |
|---------------------|-----------------------------------------------------------------------|--------|
| ReemKufi            | `ReemKufi-Regular.ttf`, `ReemKufi-Bold.ttf`                           | Google Fonts (`ofl/reemkufi`) — static 400/700 instances from the `ReemKufi[wght]` variable font |
| Amiri               | `Amiri-Regular.ttf`, `Amiri-Bold.ttf`                                 | Google Fonts (`ofl/amiri`) |
| AmiriQuran          | `AmiriQuran-Regular.ttf`                                              | Google Fonts (`ofl/amiriquran`) |
| IBMPlexSansArabic   | `-Regular / -Medium / -SemiBold / -Bold.ttf`                          | Google Fonts (`ofl/ibmplexsansarabic`) |

Licenses: `OFL-ReemKufi.txt`, `OFL-Amiri.txt`, `OFL-AmiriQuran.txt`,
`OFL-IBMPlexSansArabic.txt`.

## Updating a font

Amiri, Amiri Quran and IBM Plex Sans Arabic are copied verbatim from
`github.com/google/fonts`. Reem Kufi is only published as a variable font there,
so the two static weights are generated from it:

```bash
pip install fonttools
python -c "from fontTools.ttLib import TTFont; \
from fontTools.varLib.instancer import instantiateVariableFont as I; \
[ (lambda f: (I(f,{'wght':w},inplace=True), f.save(n)))(TTFont('ReemKufi[wght].ttf')) \
  for n,w in [('ReemKufi-Regular.ttf',400),('ReemKufi-Bold.ttf',700)] ]"
```

The `pubspec.yaml` `fonts:` block references the exact filenames above — keep
them in sync if you swap a file.
