#!/usr/bin/env python3
"""
store.py — data layer for the Kalimat editor (runs on YOUR machine only).

The editor works on a MASTER database (full schema, includes unverified furuq).
Reviewers edit pairs and flip `verified`. Export then produces the public
assets/db/kalimat.db with all unverified furuq stripped out — so nothing pending
can ever reach the shipped app, on top of the app's own verified-only queries.

No web framework needed here; app.py is a thin Flask wrapper over these funcs,
which is why they're unit-testable on their own.
"""
import os
import shutil
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
MASTER = os.path.join(HERE, "master.db")
APP_DB = os.path.join(HERE, "..", "..", "assets", "db", "kalimat.db")


def _con(path=MASTER):
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    return con


def stats(path=MASTER):
    with _con(path) as con:
        v = con.execute("SELECT COUNT(*) FROM furuq WHERE verified=1").fetchone()[0]
        u = con.execute("SELECT COUNT(*) FROM furuq WHERE verified=0").fetchone()[0]
    return {"verified": v, "unverified": u, "total": v + u}


def list_furuq(status="all", q="", path=MASTER):
    """status: 'all' | 'verified' | 'unverified'."""
    where, args = [], []
    if status == "verified":
        where.append("verified=1")
    elif status == "unverified":
        where.append("verified=0")
    if q:
        where.append("(root_a LIKE ? OR root_b LIKE ? OR difference LIKE ?)")
        args += [f"%{q}%", f"%{q}%", f"%{q}%"]
    sql = "SELECT * FROM furuq"
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY verified ASC, furuq_id ASC"
    with _con(path) as con:
        return [dict(r) for r in con.execute(sql, args).fetchall()]


def get_furuq(fid, path=MASTER):
    with _con(path) as con:
        r = con.execute("SELECT * FROM furuq WHERE furuq_id=?", (fid,)).fetchone()
    return dict(r) if r else None


_EDITABLE = ("root_a", "root_b", "maqayis_a", "maqayis_b", "quran_a", "quran_b",
             "count_a", "count_b", "semitic_a", "semitic_b", "difference", "source")


def update_furuq(fid, fields: dict, path=MASTER):
    sets, args = [], []
    for k in _EDITABLE:
        if k in fields:
            sets.append(f"{k}=?")
            args.append(fields[k] or None)
    if not sets:
        return
    args.append(fid)
    with _con(path) as con:
        con.execute(f"UPDATE furuq SET {', '.join(sets)} WHERE furuq_id=?", args)
        con.commit()


def set_verified(fid, value: bool, path=MASTER):
    with _con(path) as con:
        con.execute("UPDATE furuq SET verified=? WHERE furuq_id=?",
                    (1 if value else 0, fid))
        con.commit()


def export_app_db(master=MASTER, out=APP_DB, version: int | None = None):
    """Copy master → public app DB, stripping every unverified furuq row."""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.copyfile(master, out)
    with _con(out) as con:
        removed = con.execute("SELECT COUNT(*) FROM furuq WHERE verified=0").fetchone()[0]
        con.execute("DELETE FROM furuq WHERE verified=0")
        if version is not None:
            con.execute("INSERT INTO meta(key,value) VALUES('db_version',?) "
                        "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                        (str(version),))
        con.commit()
        con.execute("VACUUM")
    kept = stats(out)["verified"]
    return {"out": out, "verified_kept": kept, "unverified_stripped": removed}


if __name__ == "__main__":
    print("stats:", stats())
