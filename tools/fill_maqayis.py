#!/usr/bin/env python3
"""
fill_maqayis.py — derive the "المعنى المحوري" summary from Ibn Faris's own text.

The app shows a dedicated card «المعنى المحوري — ابن فارس». Ibn Faris opens
almost every article by naming the letters and stating the أصل, e.g.

    "الحاء والقاف أصل واحد، وهو يدل على إحكام الشيء وصحته. فالحق نقيض الباطل…"
     └────────────────── this opening IS the central meaning ──────────────┘

So this QUOTES that opening sentence rather than composing anything. Nothing is
generated: if the opening does not look like an أصل statement the field is left
empty and the reader still gets the full article from lexicon_entries.

Existing hand-reviewed values are never overwritten — `--force` is deliberately
not offered.

Usage:  python3 tools/fill_maqayis.py [--dry-run]
"""
import argparse
import os
import re
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "..", "assets", "db", "kalimat.db")

# Ibn Faris's formula: "<letters> أصل/أصول …" — require one of these markers so
# we only quote openings that actually state the core sense.
MARKERS = ("أصل", "أصول", "يدل على", "أصلان", "أصله")

# Strip his leading letter-spelling ("الحاء والقاف") — it is orthography, not meaning.
LETTERS_PREFIX = re.compile(
    r"^(?:ال[ء-ي]+(?:\s+و?ال[ء-ي]+){1,3})\s*[.،:]?\s*")


def first_sentence(body: str, limit: int = 320) -> str | None:
    head = body.strip()
    if not head:
        return None
    # take up to the first sentence end, but never a huge run-on
    m = re.search(r"[.؟!]", head[:limit])
    sent = head[: m.end()] if m else head[:limit].rstrip() + "…"
    if not any(k in sent for k in MARKERS):
        return None
    sent = LETTERS_PREFIX.sub("", sent).strip()
    # after stripping the letter-spelling it must still say something
    return sent if len(sent) >= 12 else None


def main(dry_run: bool):
    con = sqlite3.connect(DB)
    rows = con.execute("""
        SELECT r.root_id, r.root, r.maqayis, l.body
        FROM roots r
        JOIN lexicon_entries l ON l.root_id = r.root_id
        WHERE l.source = 'مقاييس اللغة'
    """).fetchall()

    filled = kept = skipped = 0
    samples = []
    for root_id, root, existing, body in rows:
        if existing:                      # human-reviewed — never touch
            kept += 1
            continue
        sent = first_sentence(body)
        if not sent:
            skipped += 1
            continue
        filled += 1
        if len(samples) < 5:
            samples.append((root, sent))
        if not dry_run:
            con.execute("UPDATE roots SET maqayis=? WHERE root_id=?", (sent, root_id))

    if not dry_run:
        con.commit()

    print(f"=== المعنى المحوري ({'DRY RUN' if dry_run else 'COMMITTED'}) ===")
    print(f"  filled from Ibn Faris : {filled}")
    print(f"  kept (hand-reviewed)  : {kept}")
    print(f"  skipped (no أصل stated): {skipped}")
    print("\n  samples:")
    for root, sent in samples:
        print(f"    {root}: {sent[:95]}")
    con.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    main(ap.parse_args().dry_run)
