#!/usr/bin/env python3
"""
ingest_furuq.py — import الفروق اللغوية (أبو هلال العسكري) as comparison pairs.

Feeds the app's المقارنة screen, which reads the `furuq` table.

Content policy: every row is a VERBATIM quotation from al-Askari with the
edition recorded in `source`. Nothing is composed or summarised. The `verified`
flag exists to keep *unattributed or generated* comparisons away from readers;
faithful quotations of a published classical work carry attribution instead,
so they are imported as verified=1 (see --unverified to override).

Source shape (OpenITI mARkdown, Shamela 0001736):

    ### | الفرق بين الابن والولد:
    # </span>أن الابن يفيد الاختصاص ومداومة الصحبة PageV01P012
    ~~ولهذا يقال …

Usage:
    python3 tools/ingest_furuq.py --input furuq.txt --dry-run
"""
import argparse
import os
import re
import sqlite3

from normalize import RootIndex

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "..", "assets", "db", "kalimat.db")

SOURCE = "أبو هلال العسكري — الفروق اللغوية"
EDITION = "الشاملة #1736 (OpenITI)"

# Most articles put the beginning of the explanation on the heading line itself,
# after the colon:  "### $ 43 - الفرق بين الاثم والذنب: أن الاثم في أصل اللغة…"
# Capturing the whole line as a heading silently drops that opening, so the
# stored text would start mid-sentence. Group 2 keeps it.
_HEAD = re.compile(
    r"^###\s*[|$]\s*(?:\d+\s*-\s*)?(الفرق\s+بين\s+[^:：]*)[:：]?\s*(.*)$")
_PAIR = re.compile(r"الفرق\s+بين\s+(?:قولنا\s+)?([ء-ي]+)\s+و(?:قولنا\s+)?([ء-ي]+)")
_NOISE = re.compile(r"</?span[^>]*>|\bPageV\d+P\d+\b|\bms\d+\b|\(\d+\)")


def clean(text: str) -> str:
    text = _NOISE.sub(" ", text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def entries(raw: str):
    """Yield (heading, body) for each الفرق بين article."""
    head, paras = None, []
    for line in raw.splitlines():
        m = _HEAD.match(line)
        if m:
            if head and paras:
                yield head, "\n".join(paras)
            head = m.group(1)
            # the explanation usually starts on this same line
            paras = [m.group(2).strip()] if m.group(2).strip() else []
        elif head is None:
            continue
        elif line.startswith("~~"):
            if paras:
                paras[-1] += " " + line[2:].strip()
            else:
                paras.append(line[2:].strip())
        elif line.startswith("#") and not line.startswith("###"):
            paras.append(line.lstrip("#").strip())
    if head and paras:
        yield head, "\n".join(paras)


def main(input_path: str, dry_run: bool, verified: int):
    con = sqlite3.connect(DB)
    roots = con.execute("SELECT root_id, root, freq, maqayis FROM roots").fetchall()
    idx = RootIndex([(r[0], r[1]) for r in roots])
    info = {r[0]: (r[1], r[2], r[3]) for r in roots}

    raw = open(input_path, encoding="utf-8").read()
    # Never duplicate a pair the database already holds (e.g. the hand-curated
    # بحر × يمم), in either order.
    seen = {tuple(sorted(p)) for p in
            con.execute("SELECT root_a, root_b FROM furuq")}
    rows = []
    total = no_pair = unmapped = same = 0

    for head, body in entries(raw):
        total += 1
        m = _PAIR.search(head)
        if not m:
            no_pair += 1
            continue
        ida, _ = idx.match(m.group(1))
        idb, _ = idx.match(m.group(2))
        if ida is None or idb is None:
            unmapped += 1
            continue
        if ida == idb:
            same += 1
            continue
        ra, fa, ma = info[ida]
        rb, fb, mb = info[idb]
        key = tuple(sorted((ra, rb)))
        if key in seen:                      # keep the first, fullest article
            continue
        seen.add(key)
        text = clean(body)
        if len(text) < 40:                   # too thin to be useful
            continue
        rows.append((ra, rb, ma, mb, fa, fb, text,
                     f"{SOURCE} — {EDITION}", verified))

    print(f"=== الفروق اللغوية ({'DRY RUN' if dry_run else 'COMMITTED'}) ===")
    print(f"  articles found        : {total}")
    print(f"  no 'بين X وY' pattern : {no_pair}")
    print(f"  a term is not a Quranic root : {unmapped}")
    print(f"  both terms same root  : {same}")
    print(f"  IMPORTABLE PAIRS      : {len(rows)}   (verified={verified})")
    for ra, rb, *_ , text, src, v in rows[:4]:
        print(f"    {ra} × {rb}: {text[:80]}…")

    if not dry_run and rows:
        con.execute("INSERT OR IGNORE INTO sources(source_id,name,author,death_year,"
                    "category,edition,license) VALUES (7,?,?,?,?,?,?)",
                    (SOURCE, "أبو هلال العسكري", "395هـ", "furuq", EDITION,
                     "public-domain"))
        con.executemany(
            "INSERT INTO furuq(root_a,root_b,maqayis_a,maqayis_b,count_a,count_b,"
            "difference,source,verified) VALUES (?,?,?,?,?,?,?,?,?)", rows)
        con.commit()
        print(f"  ✓ inserted {len(rows)} pairs")
    con.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--unverified", action="store_true",
                    help="import hidden (verified=0) for manual review instead")
    a = ap.parse_args()
    main(a.input, a.dry_run, 0 if a.unverified else 1)
