#!/usr/bin/env python3
"""
stamp_db.py — write a content fingerprint for the shipped database.

The app decides whether to replace its installed copy of kalimat.db by
comparing this stamp, not by trusting a hand-maintained version integer.
That integer has already failed twice: ship new content, forget to bump it,
and every existing install silently keeps the old database — the app looks
broken while the data on disk is perfectly correct.

Run this after ANY tool mutates assets/db/kalimat.db (build_quran_db.py,
ingest_lexicon.py, ingest_furuq.py, fill_maqayis.py, generate_simple.py).
CI re-runs it and fails if the committed stamp is stale, so a forgotten
stamp is caught at build time instead of on a user's phone.

Usage:
    python3 tools/stamp_db.py            # write the stamp
    python3 tools/stamp_db.py --check    # verify it matches (CI)
"""
import argparse
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "..", "assets", "db", "kalimat.db")
STAMP = DB + ".stamp"


def fingerprint() -> str:
    h = hashlib.sha256()
    with open(DB, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(check: bool):
    if not os.path.exists(DB):
        sys.exit(f"{DB} not found")
    current = fingerprint()

    if check:
        if not os.path.exists(STAMP):
            sys.exit("stamp missing — run: python3 tools/stamp_db.py")
        stored = open(STAMP, encoding="utf-8").read().strip()
        if stored != current:
            sys.exit(
                "stamp is STALE — assets/db/kalimat.db changed but the stamp "
                "was not regenerated.\n"
                "Existing installs would keep their old database.\n"
                "Fix: python3 tools/stamp_db.py && git add assets/db/kalimat.db.stamp")
        print(f"✓ stamp matches ({current[:16]}…)")
        return

    with open(STAMP, "w", encoding="utf-8") as fh:
        fh.write(current + "\n")
    print(f"✓ wrote {os.path.relpath(STAMP)}  ({current[:16]}…)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="fail if the stamp does not match the database")
    main(ap.parse_args().check)
