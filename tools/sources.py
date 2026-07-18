#!/usr/bin/env python3
"""
sources.py — the master registry of everything Kalimat should ingest.

This IS your "جامع لكل شيء" checklist. To make the app comprehensive you work
down this list: for each source, obtain the text, run ingest_lexicon.py, review.
`status` tracks progress: 'todo' | 'ingesting' | 'review' | 'done'.

`where` points at an open, machine-readable copy:
  - OpenITI/RELEASE (github.com/OpenITI/RELEASE) — mARkdown, from Shamela
  - arabiclexicon.hawramani.com — per-lexicon web pages
  - your own Shamela scrape (you already do this — e.g. al-Askari #1736)

All listed classical texts are public-domain works; note the specific digital
edition per source for clean attribution (the `sources` table stores it).
"""

SOURCES = [
    # ── Core skeleton (do these first) ─────────────────────────────
    dict(id=1, name="مقاييس اللغة", author="ابن فارس", death="395هـ",
         category="dictionary", license="public-domain",
         where="OpenITI: 0395IbnFaris.MuqayyisAlLugha", status="review",
         note="المعنى المحوري — عمودك الأساسي؛ ابنِ عليه أولًا."),
    dict(id=2, name="مفردات القرآن", author="الراغب الأصفهاني", death="502هـ",
         category="quran_lexicon", license="public-domain",
         where="OpenITI / Hawramani", status="review",
         note="أهم معجم قرآني مفرداتي."),
    dict(id=3, name="لسان العرب", author="ابن منظور", death="711هـ",
         category="dictionary", license="public-domain",
         where="OpenITI: 0711IbnManzur.LisanAlArab (~20 مجلدًا)", status="todo",
         note="الأوسع؛ منظّم بالجذر — مثالي للربط الآلي."),

    # ── Broaden coverage ───────────────────────────────────────────
    dict(id=4, name="الصحاح", author="الجوهري", death="393هـ",
         category="dictionary", license="public-domain",
         where="OpenITI / Hawramani", status="todo"),
    dict(id=5, name="العين", author="الخليل بن أحمد", death="170هـ",
         category="dictionary", license="public-domain",
         where="OpenITI / Hawramani", status="todo",
         note="أقدم معجم — منظّم صوتيًا لا بالجذر؛ قد يحتاج مُقسّمًا خاصًا."),
    dict(id=6, name="تاج العروس", author="الزبيدي", death="1205هـ",
         category="dictionary", license="public-domain",
         where="OpenITI / Hawramani", status="todo",
         note="شرح موسّع للقاموس المحيط."),
    dict(id=7, name="تهذيب اللغة", author="الأزهري", death="370هـ",
         category="dictionary", license="public-domain",
         where="OpenITI / Hawramani", status="todo"),
    dict(id=8, name="أساس البلاغة", author="الزمخشري", death="538هـ",
         category="dictionary", license="public-domain",
         where="OpenITI / Hawramani", status="todo",
         note="للاستعمال المجازي/البلاغي للكلمة."),

    # ── Quran-specific ─────────────────────────────────────────────
    dict(id=9, name="غريب القرآن", author="السجستاني", death="330هـ",
         category="quran_lexicon", license="public-domain",
         where="OpenITI / Hawramani", status="todo"),
    dict(id=10, name="عمدة الحفاظ", author="السمين الحلبي", death="756هـ",
         category="quran_lexicon", license="public-domain",
         where="OpenITI", status="todo"),
    dict(id=11, name="الكليات", author="أبو البقاء الكفوي", death="1094هـ",
         category="quran_lexicon", license="public-domain",
         where="OpenITI", status="todo",
         note="فيه فروق لغوية كثيرة أيضًا."),

    # ── Furuq (semantic differences) ───────────────────────────────
    dict(id=12, name="الفروق اللغوية", author="أبو هلال العسكري", death="395هـ",
         category="furuq", license="public-domain",
         where="Shamela #1736 (سحبك الحالي)", status="done",
         note="~2947 زوجًا، دقّة ~99.8% — مُنجَز."),

    # ── Comparative Semitic (present as محل خلاف) ──────────────────
    dict(id=13, name="Foreign Vocabulary of the Qur'an", author="Arthur Jeffery",
         death="1959", category="semitic", license="check-edition",
         where="reference work — manual entry", status="todo",
         note="قارن بحذر؛ وسم «محل خلاف علمي» إجباري."),
    dict(id=14, name="Comparative Semitic (CAL / Sefaria / Leslau)", author="—",
         death="—", category="semitic", license="check-terms",
         where="cal.huc.edu · sefaria.org · Leslau (Geez)", status="todo",
         note="للمقابلات العبرية/الآرامية/الأكادية/الحبشية."),
]


def summary():
    from collections import Counter
    by_status = Counter(s["status"] for s in SOURCES)
    by_cat = Counter(s["category"] for s in SOURCES)
    print(f"{len(SOURCES)} sources  |  status: {dict(by_status)}  |  category: {dict(by_cat)}")


if __name__ == "__main__":
    summary()
    for s in SOURCES:
        print(f"  [{s['status']:>9}] {s['name']} — {s['author']} ({s['category']})")
