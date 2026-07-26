#!/usr/bin/env python3
"""
generate_simple.py — write الشرح المبسّط for each root from its OWN sources.

This is the one place in the pipeline where text is model-written rather than
quoted, so the design keeps it bounded:

  * GROUNDED — the prompt carries that root's stored مقاييس اللغة and مفردات
    الراغب text and instructs the model to summarize only what is there. It is
    a reading aid for sources already in the database, not new scholarship.
  * LABELLED — every generated row sets roots.simple_generated = 1, and the app
    renders those under «شرح تحريري» with a footer naming the sources. A reader
    can always tell editorial prose from classical text.
  * SKIPPED, NOT INVENTED — a root with no source text is left empty. The model
    is told to return the single token NO_BASIS when the sources don't support a
    summary, and that row is skipped.
  * NEVER OVERWRITES — hand-written entries (simple_generated = 0) are left
    alone; there is deliberately no --force.

Nothing here runs at app runtime: the output ships inside kalimat.db.

Usage:
    export ANTHROPIC_API_KEY=...
    python3 tools/generate_simple.py --limit 20 --dry-run   # inspect prompts
    python3 tools/generate_simple.py --limit 20             # generate 20
    python3 tools/generate_simple.py                        # all remaining
"""
import argparse
import os
import sqlite3
import sys
import time

MODEL = "claude-opus-5"
HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "..", "assets", "db", "kalimat.db")

NO_BASIS = "NO_BASIS"

SYSTEM = """\
أنت محرّر معجمي عربي. مهمتك صياغة «شرح مبسّط» لجذر قرآني، معتمدًا \
حصريًا على النصوص المعجمية الكلاسيكية المرفقة.

القواعد:
١. لا تضف معنى ولا اشتقاقًا ولا شاهدًا لا يرد في النصوص المرفقة.
٢. لا تفسّر آية ولا تستنبط حكمًا فقهيًا ولا عقديًا. اقتصر على دلالة اللفظ في اللغة.
٣. اكتب فقرة واحدة من ٢٥ إلى ٥٠ كلمة، بعربية فصيحة معاصرة واضحة لغير المتخصص.
٤. ابدأ بالمعنى المحوري ثم اذكر أبرز تفرّعاته كما وردت في النصوص.
٥. لا تذكر أسماء المؤلفين ولا عبارات مثل «تقول المصادر»؛ اكتب الشرح مباشرة.
٦. إن كانت النصوص المرفقة غير كافية لشرح موثوق، فأجب بكلمة واحدة فقط: NO_BASIS

أخرج نصّ الشرح وحده، بلا مقدمات ولا عناوين ولا علامات اقتباس."""


def build_prompt(root: str, entries: list[tuple[str, str]]) -> str:
    blocks = "\n\n".join(
        f"— {source} —\n{body[:2500]}" for source, body in entries)
    return (f"الجذر: {root}\n\nالنصوص المعجمية:\n\n{blocks}\n\n"
            "اكتب الشرح المبسّط لهذا الجذر وفق القواعد.")


def fetch_targets(con, limit):
    """Roots that have source text but no explanation yet, most frequent first."""
    rows = con.execute("""
        SELECT r.root_id, r.root, r.freq
        FROM roots r
        WHERE (r.simple IS NULL OR r.simple = '')
          AND EXISTS (SELECT 1 FROM lexicon_entries l WHERE l.root_id = r.root_id)
        ORDER BY r.freq DESC
    """).fetchall()
    return rows[:limit] if limit else rows


def sources_for(con, root_id):
    return con.execute(
        "SELECT source, body FROM lexicon_entries WHERE root_id = ?"
        " ORDER BY ordinal", (root_id,)).fetchall()


def main(limit, dry_run, sleep):
    con = sqlite3.connect(DB)
    targets = fetch_targets(con, limit)
    print(f"roots needing an explanation: {len(targets)}")
    if not targets:
        return

    if dry_run:
        rid, root, freq = targets[0]
        print(f"\n=== sample prompt ({root}, {freq} occurrences) ===\n")
        print(SYSTEM)
        print("\n--- user ---\n")
        print(build_prompt(root, sources_for(con, rid))[:1800])
        print(f"\n... would generate {len(targets)} explanations with {MODEL}")
        return

    try:
        import anthropic
    except ImportError:
        sys.exit("pip install anthropic")
    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("set ANTHROPIC_API_KEY")

    client = anthropic.Anthropic()
    written = skipped = failed = 0

    for i, (rid, root, freq) in enumerate(targets, 1):
        entries = sources_for(con, rid)
        try:
            resp = client.messages.create(
                model=MODEL,
                max_tokens=1000,
                system=SYSTEM,
                messages=[{"role": "user",
                           "content": build_prompt(root, entries)}],
            )
        except Exception as e:                      # noqa: BLE001 — log and continue
            failed += 1
            print(f"  [{i}/{len(targets)}] {root}: FAILED {type(e).__name__}: {e}")
            continue

        if resp.stop_reason == "refusal":
            skipped += 1
            print(f"  [{i}/{len(targets)}] {root}: declined by the model")
            continue

        text = "".join(b.text for b in resp.content if b.type == "text").strip()
        if not text or text.startswith(NO_BASIS):
            skipped += 1
            print(f"  [{i}/{len(targets)}] {root}: no basis in sources — left empty")
            continue

        con.execute(
            "UPDATE roots SET simple = ?, simple_generated = 1 WHERE root_id = ?",
            (text, rid))
        con.commit()                                # commit per row: resumable
        written += 1
        print(f"  [{i}/{len(targets)}] {root}: {text[:70]}…")
        if sleep:
            time.sleep(sleep)

    print(f"\nwritten: {written}   skipped: {skipped}   failed: {failed}")
    print("All rows are marked simple_generated = 1 and render as «شرح تحريري».")
    con.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None,
                    help="only the N most frequent roots still missing one")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the prompt and the target count; call nothing")
    ap.add_argument("--sleep", type=float, default=0.0,
                    help="seconds between requests")
    a = ap.parse_args()
    main(a.limit, a.dry_run, a.sleep)
