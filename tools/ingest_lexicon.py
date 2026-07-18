#!/usr/bin/env python3
"""
ingest_lexicon.py — the engine that adds ANY lexicon to the app database.

"Add them all" = run this once per source in sources.py.

Flow:
  1. Build a RootIndex from the roots already in kalimat.db.
  2. Read the source's raw text and split it into (headword, body) entries.
  3. Match each headword to a root_id (exact/fuzzy). Insert matched entries into
     lexicon_entries with the source name + category.
  4. Write a coverage report and a review file for fuzzy / unmatched entries.

Entry SEGMENTATION differs per dictionary. This ships a generic segmenter for
the common "headword line, then article body" shape (works for many OpenITI
mARkdown lexicons that are organized by root). Sources organized differently
(e.g. al-ʿAyn, phonetic order) need a small custom `segment_*` function — the
plug-in point is marked below.

Usage:
  # dry run — see coverage before writing anything
  python3 tools/ingest_lexicon.py --source-id 3 --input lisan.txt --dry-run
  # commit
  python3 tools/ingest_lexicon.py --source-id 3 --input lisan.txt
"""
import argparse
import os
import re
import sqlite3

from normalize import RootIndex
from sources import SOURCES

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "..", "assets", "db", "kalimat.db")


def load_root_index(con) -> RootIndex:
    rows = con.execute("SELECT root_id, root FROM roots").fetchall()
    return RootIndex([(r[0], r[1]) for r in rows])


# ── Segmenters ────────────────────────────────────────────────────────
# Each yields (headword, body). Add a new one for oddly-structured sources.

def segment_generic(raw: str):
    """
    Generic root-organized segmenter.

    Treats a short line (1–4 Arabic words, no sentence punctuation) as a new
    headword, and the following lines up to the next headword as its body.
    Good default for many OpenITI dictionary texts. Tune the HEADWORD regex
    for your specific edition.
    """
    HEADWORD = re.compile(r"^\s*([\u0621-\u064A]{2,}(?:\s[\u0621-\u064A]{1,3}){0,3})\s*$")
    headword, buf = None, []
    for line in raw.splitlines():
        m = HEADWORD.match(line)
        if m and len(line.strip()) <= 20:
            if headword and buf:
                yield headword, "\n".join(buf).strip()
            headword, buf = m.group(1).strip(), []
        else:
            buf.append(line)
    if headword and buf:
        yield headword, "\n".join(buf).strip()


SEGMENTERS = {"generic": segment_generic}
# e.g. SEGMENTERS["ayn"] = segment_ayn   # <- custom for al-ʿAyn, etc.


def ingest(source_id: int, input_path: str, segmenter: str, dry_run: bool):
    src = next((s for s in SOURCES if s["id"] == source_id), None)
    if not src:
        raise SystemExit(f"source id {source_id} not in sources.py")

    con = sqlite3.connect(DB)
    idx = load_root_index(con)

    # register the source in the catalog (idempotent)
    if not dry_run:
        con.execute(
            "INSERT OR IGNORE INTO sources(source_id,name,author,death_year,category,edition,license)"
            " VALUES (?,?,?,?,?,?,?)",
            (src["id"], src["name"], src["author"], src["death"],
             src["category"], src.get("where"), src["license"]))

    with open(input_path, encoding="utf-8") as fh:
        raw = fh.read()

    matched = fuzzy = unmatched = 0
    review = []
    ordinal_by_root: dict[int, int] = {}

    for headword, body in SEGMENTERS[segmenter](raw):
        if not body:
            continue
        root_id, conf = idx.match(headword)
        if root_id is None:
            unmatched += 1
            review.append(("UNMATCHED", headword, body[:60]))
            continue
        if conf == "fuzzy":
            fuzzy += 1
            review.append(("FUZZY", headword, body[:60]))
        matched += 1
        if not dry_run:
            ordv = ordinal_by_root.get(root_id, 0)
            ordinal_by_root[root_id] = ordv + 1
            con.execute(
                "INSERT INTO lexicon_entries(root_id,source,category,ordinal,body)"
                " VALUES (?,?,?,?,?)",
                (root_id, src["name"], src["category"], ordv, body))

    covered = len(ordinal_by_root) if not dry_run else "—"
    if not dry_run:
        con.commit()

    # report
    print(f"\n=== {src['name']} ({'DRY RUN' if dry_run else 'COMMITTED'}) ===")
    print(f"matched: {matched}   (of which fuzzy: {fuzzy})")
    print(f"unmatched: {unmatched}")
    print(f"roots covered: {covered}")
    if review:
        report = os.path.join(HERE, f"review_source_{source_id}.tsv")
        with open(report, "w", encoding="utf-8") as fh:
            fh.write("flag\theadword\tbody_preview\n")
            for row in review:
                fh.write("\t".join(row) + "\n")
        print(f"⚠ {len(review)} items need review → {report}")
        print("  (FUZZY = matched by skeleton; UNMATCHED = filed nowhere.)")
    con.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-id", type=int, required=True)
    ap.add_argument("--input", required=True)
    ap.add_argument("--segmenter", default="generic", choices=list(SEGMENTERS))
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    ingest(a.source_id, a.input, a.segmenter, a.dry_run)
