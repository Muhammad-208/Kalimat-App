#!/usr/bin/env python3
"""
export_app_db.py — the BRIDGE from your research pipeline to the shipped app DB.

Your two builders produce their own SQLite files:
    build_quran_db.py  → roots / words / (morphology spine, Quranic Arabic Corpus)
    build_furuq.py     → furuq comparison pairs (al-Askari, Shamela #1736)

This script reads those, plus your reviewed explanation/lexicon content, and
writes a single READ-ONLY assets/db/kalimat.db in the schema the Flutter app
expects (assets/db/schema.sql). Ship that file inside the APK.

Fill in the SELECTs to match YOUR source table/column names — they're marked
TODO. The target INSERTs below are already correct for the app.

Two hard rules enforced here:
  1. Explanations (simple / maqayis / semitic) are PRE-GENERATED + human-reviewed.
     Never generate them at runtime. This script only COPIES stored text.
  2. Only furuq rows with verified = 1 are meaningful to users. Unverified rows
     may be exported (the app filters them), but prefer to gate here too.

Usage:
    python3 tools/export_app_db.py \
        --quran  /path/to/quran.db \
        --furuq  /path/to/furuq.db \
        --content /path/to/reviewed_content.db \
        --version 2
"""
import argparse
import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "..", "assets", "db", "schema.sql")
OUT = os.path.join(HERE, "..", "assets", "db", "kalimat.db")


def build(quran_db: str, furuq_db: str, content_db: str | None, version: int):
    if os.path.exists(OUT):
        os.remove(OUT)
    out = sqlite3.connect(OUT)
    with open(SCHEMA, encoding="utf-8") as fh:
        out.executescript(fh.read())
    out.execute("INSERT INTO meta VALUES ('db_version',?)", (str(version),))

    quran = sqlite3.connect(quran_db)
    furuq = sqlite3.connect(furuq_db)
    content = sqlite3.connect(content_db) if content_db else None

    # ── 1. ROOTS ────────────────────────────────────────────────
    # TODO: adjust to your corpus schema. Expected out: (root, spaced, freq)
    root_rows = quran.execute("""
        SELECT root, freq FROM roots            -- TODO your table
    """).fetchall()

    # Optional reviewed content keyed by root text.
    reviewed = {}
    if content:
        for root, simple, maqayis, semitic, note in content.execute("""
            SELECT root, simple, maqayis, semitic, semitic_note FROM root_content
        """):  # TODO your reviewed-content table
            reviewed[root] = (simple, maqayis, semitic, note)

    root_id = {}
    for i, (root, freq) in enumerate(root_rows, start=1):
        root_id[root] = i
        spaced = " ".join(root)  # "بحر" -> "ب ح ر"
        simple, maqayis, semitic, note = reviewed.get(root, (None, None, None, None))
        out.execute(
            "INSERT INTO roots(root_id,root,root_spaced,freq,simple,maqayis,"
            "semitic,semitic_note) VALUES (?,?,?,?,?,?,?,?)",
            (i, root, spaced, freq, simple, maqayis, semitic, note))

    # ── 2. WORDS / OCCURRENCES ──────────────────────────────────
    # TODO: expected (root, surface, surah, ayah, [verse_text])
    for root, surface, surah, ayah in quran.execute("""
        SELECT root, surface, surah, ayah FROM words        -- TODO your table
    """):
        if root in root_id:
            out.execute(
                "INSERT INTO words(root_id,surface,surah,ayah) VALUES (?,?,?,?)",
                (root_id[root], surface, surah, ayah))

    # ── 3. SURAH NAMES ──────────────────────────────────────────
    for surah, name in quran.execute("SELECT surah, name FROM surahs"):  # TODO
        out.execute("INSERT OR IGNORE INTO surahs VALUES (?,?)", (surah, name))

    # ── 4. LEXICON ENTRIES ──────────────────────────────────────
    if content:
        for root, source, ordinal, body in content.execute("""
            SELECT root, source, ordinal, body FROM lexicon    -- TODO your table
        """):
            if root in root_id:
                out.execute(
                    "INSERT INTO lexicon_entries(root_id,source,ordinal,body)"
                    " VALUES (?,?,?,?)", (root_id[root], source, ordinal, body))

    # ── 5. FURUQ (carry the verified flag straight through) ─────
    for row in furuq.execute("""
        SELECT root_a, root_b, maqayis_a, maqayis_b, quran_a, quran_b,
               count_a, count_b, semitic_a, semitic_b, difference, source, verified
        FROM furuq                                             -- TODO your table
    """):
        out.execute(
            "INSERT INTO furuq(root_a,root_b,maqayis_a,maqayis_b,quran_a,quran_b,"
            "count_a,count_b,semitic_a,semitic_b,difference,source,verified)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", row)

    out.commit()
    # Compact + speed up read-only access on device.
    out.execute("VACUUM")
    out.execute("PRAGMA optimize")
    out.close()
    print(f"✓ wrote {OUT}  ({os.path.getsize(OUT):,} bytes, v{version})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--quran", required=True)
    ap.add_argument("--furuq", required=True)
    ap.add_argument("--content", default=None)
    ap.add_argument("--version", type=int, default=1)
    a = ap.parse_args()
    build(a.quran, a.furuq, a.content, a.version)
