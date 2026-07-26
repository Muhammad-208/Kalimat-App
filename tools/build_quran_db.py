#!/usr/bin/env python3
"""
build_quran_db.py — build the full Quranic morphology spine for the app DB.

This is the missing builder that export_app_db.py always referenced. It reads
the Quranic Arabic Corpus morphology file (GPL, corpus.quran.com) and writes
roots / words / ayahs / surahs straight into assets/db/kalimat.db.

Curated content is PRESERVED, never regenerated: the hand-reviewed
simple/maqayis/semitic fields on roots, lexicon_entries, furuq, sources and
meta are carried over from the existing DB and re-keyed to the new root ids.

Morphology line format (tab separated):
    1:1:3:2   رَّحْمَٰنِ   N   ROOT:رحم|LEM:رَحْمٰن|MS|GEN|ADJ
    ^loc      ^form       ^tag ^features

Usage:
    python3 tools/build_quran_db.py --morphology /path/to/quran-morphology.txt
"""
import argparse
import os
import re
import sqlite3
import sys
import unicodedata
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "..", "assets", "db", "schema.sql")
OUT = os.path.join(HERE, "..", "assets", "db", "kalimat.db")

# ── normalization (kept identical to normalize.py; mirrored in Dart) ────────
_TASHKEEL = re.compile(r"[ً-ٰٟ]")
_TATWEEL = re.compile(r"ـ")
_NON_ARABIC = re.compile(r"[^ء-ي\s]")
_SUBS = (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"),
         ("ؤ", "و"), ("ئ", "ي"), ("ء", ""), ("ى", "ي"), ("ة", "ه"))


def normalize(text: str) -> str:
    t = unicodedata.normalize("NFC", text)
    t = _TASHKEEL.sub("", t)
    t = _TATWEEL.sub("", t)
    for a, b in _SUBS:
        t = t.replace(a, b)
    t = _NON_ARABIC.sub("", t)
    return re.sub(r"\s+", " ", t).strip()


def normalize_dagger_alef(text: str) -> str:
    """Like normalize(), but the dagger alef (U+0670) becomes a real ا.

    The corpus writes long ā as a dagger alef (ٱلْكِتَٰب); users type الكتاب.
    Stripping it as a diacritic loses the letter, so we index both spellings.
    """
    return normalize(text.replace("ٰ", "ا"))


def collapse_doubles(n: str) -> str:
    out = []
    for ch in n.replace(" ", ""):
        if not out or out[-1] != ch:
            out.append(ch)
    return "".join(out)


_LONG_VOWELS = str.maketrans("", "", "اوي")


def skeleton(n: str) -> str:
    """Consonantal skeleton: drop long vowels so الصلوه == الصلاه, كتب == كتاب.

    Lossy on purpose — only ever used as the last matching tier.
    """
    s = n.translate(_LONG_VOWELS)
    return s if len(s) >= 2 else n


def prefix_variants(forms: list[str], root_idx: int):
    """Readings of a word with its leading morphemes progressively dropped.

    Driven by the corpus's own segmentation, never by guessing letters. Peeling
    proclitics heuristically is unsafe: كُلَّمَا (root كلل) is a SINGLE segment,
    so treating its initial ك as the "like" proclitic invents the reading لما
    and files a common particle under كلل.
    """
    out = {"".join(forms[k:]) for k in range(root_idx + 1)}
    out.add(forms[root_idx])          # bare stem, without any suffixes
    return {x for x in out if x}


SURAH_NAMES = [
    "الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف",
    "الأنفال", "التوبة", "يونس", "هود", "يوسف", "الرعد", "إبراهيم", "الحجر",
    "النحل", "الإسراء", "الكهف", "مريم", "طه", "الأنبياء", "الحج", "المؤمنون",
    "النور", "الفرقان", "الشعراء", "النمل", "القصص", "العنكبوت", "الروم",
    "لقمان", "السجدة", "الأحزاب", "سبأ", "فاطر", "يس", "الصافات", "ص",
    "الزمر", "غافر", "فصلت", "الشورى", "الزخرف", "الدخان", "الجاثية",
    "الأحقاف", "محمد", "الفتح", "الحجرات", "ق", "الذاريات", "الطور", "النجم",
    "القمر", "الرحمن", "الواقعة", "الحديد", "المجادلة", "الحشر", "الممتحنة",
    "الصف", "الجمعة", "المنافقون", "التغابن", "الطلاق", "التحريم", "الملك",
    "القلم", "الحاقة", "المعارج", "نوح", "الجن", "المزمل", "المدثر", "القيامة",
    "الإنسان", "المرسلات", "النبأ", "النازعات", "عبس", "التكوير", "الانفطار",
    "المطففين", "الانشقاق", "البروج", "الطارق", "الأعلى", "الغاشية", "الفجر",
    "البلد", "الشمس", "الليل", "الضحى", "الشرح", "التين", "العلق", "القدر",
    "البينة", "الزلزلة", "العاديات", "القارعة", "التكاثر", "العصر", "الهمزة",
    "الفيل", "قريش", "الماعون", "الكوثر", "الكافرون", "النصر", "المسد",
    "الإخلاص", "الفلق", "الناس",
]

ROOT_RE = re.compile(r"ROOT:([^|\s]+)")


def parse_morphology(path):
    """-> (words, ayah_text). words: list of (root, surface, surah, ayah, pos)."""
    seg_forms = defaultdict(list)   # (s,a,w) -> [(seg, form)]
    seg_root = {}                   # (s,a,w) -> root
    seg_root_no = {}                # (s,a,w) -> segment number carrying the root

    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 4:
                continue
            loc, form, _tag, feats = parts[0], parts[1], parts[2], parts[3]
            loc = loc.strip("()")
            bits = loc.split(":")
            if len(bits) != 4:
                continue
            try:
                s, a, w, seg = (int(x) for x in bits)
            except ValueError:
                continue
            key = (s, a, w)
            seg_forms[key].append((seg, form))
            m = ROOT_RE.search(feats)
            if m and key not in seg_root:
                seg_root[key] = m.group(1)
                seg_root_no[key] = seg

    words, ayah_words = [], defaultdict(list)
    for (s, a, w), segs in seg_forms.items():
        ordered = sorted(segs)
        forms = [f for _, f in ordered]
        surface = "".join(forms)
        ayah_words[(s, a)].append((w, surface))
        root = seg_root.get((s, a, w))
        if root:
            # Position of the stem within this word's segments, so prefixes can
            # be peeled by morphology rather than by guessing letters.
            root_no = seg_root_no[(s, a, w)]
            root_idx = next(
                (i for i, (no, _) in enumerate(ordered) if no == root_no), 0)
            words.append((root, surface, s, a, w, forms, root_idx))

    ayah_text = {
        loc: " ".join(sur for _, sur in sorted(ws))
        for loc, ws in ayah_words.items()
    }
    return words, ayah_text


def read_curated(db_path):
    """Pull hand-reviewed content out of the existing DB before we replace it."""
    curated = {"roots": {}, "lexicon": [], "furuq": [], "sources": [], "meta": []}
    if not os.path.exists(db_path):
        return curated
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    try:
        for r in con.execute(
                "SELECT root, simple, maqayis, semitic, semitic_note FROM roots"):
            if any(r[k] for k in ("simple", "maqayis", "semitic", "semitic_note")):
                curated["roots"][r["root"]] = (
                    r["simple"], r["maqayis"], r["semitic"], r["semitic_note"])
        # lexicon entries are keyed by root_id -> re-key by root TEXT
        for r in con.execute(
                "SELECT r.root, l.source, l.category, l.ordinal, l.body "
                "FROM lexicon_entries l JOIN roots r ON r.root_id = l.root_id"):
            curated["lexicon"].append(tuple(r))
        for r in con.execute(
                "SELECT root_a,root_b,maqayis_a,maqayis_b,quran_a,quran_b,"
                "count_a,count_b,semitic_a,semitic_b,difference,source,verified "
                "FROM furuq"):
            curated["furuq"].append(tuple(r))
        for r in con.execute("SELECT * FROM sources"):
            curated["sources"].append(tuple(r))
        for r in con.execute("SELECT key,value FROM meta"):
            curated["meta"].append(tuple(r))
    except sqlite3.Error as e:
        print(f"  ! could not read curated content: {e}", file=sys.stderr)
    con.close()
    return curated


def build(morphology_path, version):
    print("→ parsing morphology ...")
    words, ayah_text = parse_morphology(morphology_path)
    if not words:
        sys.exit("no words parsed — is the morphology file the right format?")

    freq = defaultdict(int)
    for root, *_ in words:
        freq[root] += 1
    print(f"  {len(freq):,} roots, {len(words):,} rooted words, "
          f"{len(ayah_text):,} ayahs")

    print("→ preserving curated content ...")
    curated = read_curated(OUT)
    print(f"  {len(curated['roots'])} curated roots, "
          f"{len(curated['lexicon'])} lexicon entries, "
          f"{len(curated['furuq'])} furuq, {len(curated['sources'])} sources")

    if os.path.exists(OUT):
        os.remove(OUT)
    out = sqlite3.connect(OUT)
    with open(SCHEMA, encoding="utf-8") as fh:
        out.executescript(fh.read())

    # ── roots (most frequent first, so root_id order is meaningful) ──
    root_id = {}
    ordered = sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))
    for i, (root, f) in enumerate(ordered, start=1):
        root_id[root] = i
        simple, maqayis, semitic, note = curated["roots"].get(
            root, (None, None, None, None))
        n = normalize(root)
        out.execute(
            "INSERT INTO roots(root_id,root,root_spaced,root_norm,root_fuzzy,"
            "freq,simple,maqayis,semitic,semitic_note)"
            " VALUES (?,?,?,?,?,?,?,?,?,?)",
            (i, root, " ".join(root), n, collapse_doubles(n), f,
             simple, maqayis, semitic, note))

    # ── words ──
    out.executemany(
        "INSERT INTO words(root_id,surface,surface_norm,surah,ayah,position)"
        " VALUES (?,?,?,?,?,?)",
        [(root_id[r], sur, normalize(sur), s, a, p)
         for r, sur, s, a, p, _forms, _ridx in words])

    # ── search keys ──
    # Highest-frequency root wins a contested key, so الكتاب lands on كتب
    # rather than on some rare homograph.
    keys: dict[tuple[int, str], tuple[int, int]] = {}   # (kind,key) -> (freq,root_id)

    def add_key(kind, key, root, rid):
        if len(key) < 2:
            return
        prev = keys.get((kind, key))
        if prev is None or freq[root] > prev[0]:
            keys[(kind, key)] = (freq[root], rid)

    for root, rid in root_id.items():
        n = normalize(root)
        add_key(0, n, root, rid)
        add_key(1, skeleton(n), root, rid)

    for root, _surface, _s, _a, _p, forms, root_idx in words:
        rid = root_id[root]
        for piece in prefix_variants(forms, root_idx):
            for cand in (normalize(piece), normalize_dagger_alef(piece)):
                add_key(0, cand, root, rid)
                add_key(1, skeleton(cand), root, rid)

    out.executemany(
        "INSERT INTO word_keys(kind,key,root_id) VALUES (?,?,?)",
        [(k, key, rid) for (k, key), (_f, rid) in keys.items()])
    print(f"  {len(keys):,} search keys")

    # ── ayahs + surahs ──
    out.executemany("INSERT INTO ayahs(surah,ayah,text) VALUES (?,?,?)",
                    [(s, a, t) for (s, a), t in sorted(ayah_text.items())])
    max_surah = max(s for s, _ in ayah_text)
    out.executemany("INSERT INTO surahs(surah,name) VALUES (?,?)",
                    [(i, SURAH_NAMES[i - 1]) for i in range(1, max_surah + 1)])

    # ── carried-over content ──
    out.executemany(
        "INSERT INTO sources VALUES (?,?,?,?,?,?,?)", curated["sources"])
    kept = dropped = 0
    for root, source, category, ordinal, body in curated["lexicon"]:
        if root in root_id:
            out.execute(
                "INSERT INTO lexicon_entries(root_id,source,category,ordinal,body)"
                " VALUES (?,?,?,?,?)",
                (root_id[root], source, category, ordinal, body))
            kept += 1
        else:
            dropped += 1
    out.executemany(
        "INSERT INTO furuq(root_a,root_b,maqayis_a,maqayis_b,quran_a,quran_b,"
        "count_a,count_b,semitic_a,semitic_b,difference,source,verified)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", curated["furuq"])

    meta = dict(curated["meta"])
    meta["db_version"] = str(version)
    meta["built_by"] = "build_quran_db.py (Quranic Arabic Corpus)"
    out.executemany("INSERT INTO meta(key,value) VALUES (?,?)", sorted(meta.items()))

    out.commit()
    out.execute("VACUUM")
    out.close()
    if dropped:
        print(f"  ! {dropped} lexicon entries dropped (root absent from corpus)")
    print(f"  kept {kept} lexicon entries")
    print(f"✓ wrote {OUT}  ({os.path.getsize(OUT):,} bytes, v{version})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--morphology", required=True)
    ap.add_argument("--version", type=int, default=2)
    a = ap.parse_args()
    build(a.morphology, a.version)
