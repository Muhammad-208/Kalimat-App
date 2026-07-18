# محرّر كلمات — Kalimat editor (local only)

A small **local** tool for reviewing furuq pairs, flipping `verified`, and
exporting the public `assets/db/kalimat.db`. It is **not** part of the shipped
app — this is the upstream review step we agreed keeps privileged edits out of
every user's APK.

## Why it's separate
Anything that can change `verified` or edit religious content must not live in
the public build. Reviewers run this on their own machine against the **master**
database; export produces the read-only artifact the app ships.

## Setup
```bash
pip install flask
cd tools/editor
python3 app.py            # → http://127.0.0.1:5000
```
Use a different master DB:
```bash
KALIMAT_MASTER=/path/to/master.db python3 app.py
```

## Workflow
1. Filter **بانتظار المراجعة** (pending) to see unverified pairs.
2. **تحرير** to edit any field (roots, maqayis, quran usage, counts, semitic, the
   difference text, source).
3. **اعتماد ✓** to mark a pair `verified` (or إلغاء التحقّق to revert).
4. **تصدير kalimat.db** (top-right) writes `../../assets/db/kalimat.db` with every
   unverified row **stripped out**, then VACUUMs. Rebuild the APK to ship it.

## Files
- `store.py` — DB layer (list / edit / verify / export). Unit-testable, no Flask.
- `app.py` — thin Flask UI over `store.py`.
- `master.db` — sample master (1 verified + 3 pending) so you can try it now.

## Notes
- Export is defence-in-depth: the app already queries `verified = 1` only, and
  export additionally removes unverified rows so they can't ship even by accident.
- For a full content pipeline, point `store.MASTER` at the DB your Python
  ingestion writes to, or merge this furuq table into that master.
