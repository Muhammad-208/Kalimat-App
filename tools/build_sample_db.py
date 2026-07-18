#!/usr/bin/env python3
"""
build_sample_db.py — generate a small SEED kalimat.db so the Flutter app runs
immediately, before your real pipeline data is wired in.

It writes ../assets/db/kalimat.db using assets/db/schema.sql, seeded with the
exact sample content shown in the design (بحر, يمّ, the furuq pair, etc).

Replace this with export_app_db.py once your real Quran + furuq DBs are ready.

Usage:
    python3 tools/build_sample_db.py
"""
import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "..", "assets", "db", "schema.sql")
OUT = os.path.join(HERE, "..", "assets", "db", "kalimat.db")


def main() -> None:
    if os.path.exists(OUT):
        os.remove(OUT)
    con = sqlite3.connect(OUT)
    with open(SCHEMA, encoding="utf-8") as fh:
        con.executescript(fh.read())
    cur = con.cursor()

    cur.execute("INSERT INTO meta VALUES ('db_version','1'),('built_by','sample')")

    # ── surahs (subset used by the seed verses) ──
    surahs = [(2, "البقرة"), (5, "المائدة"), (7, "الأعراف"),
              (16, "النحل"), (30, "الروم")]
    cur.executemany("INSERT INTO surahs VALUES (?,?)", surahs)

    # ── roots ──
    roots = [
        # (id, root, spaced, freq, simple, maqayis, semitic, semitic_note)
        (1, "بحر", "ب ح ر", 42,
         "«البحر» هي الكلمة العامة للبحر في القرآن، وتأتي غالبًا مقابلة للبَرّ.",
         "الاتساع والانبساط؛ ومنه «بَحَرْتُ الشيء» أي وسّعته.",
         None, "cf. Proto-Semitic *b-ḥ-r (?)"),
        (2, "يمم", "ي م م", 8,
         "«اليمّ» يرد في القرآن محصورًا في سياق قصّة موسى.",
         "الماء الكثير / البحر في سياقٍ خاصّ.",
         "יָם (العبرية)", "cf. Hebrew yām"),
        (3, "علم", "ع ل م", 854, None, "إدراك الشيء على ما هو عليه.", None, None),
        (4, "رحم", "ر ح م", 339, None, "الرقّة والعطف والرأفة.", None, None),
        (5, "صبر", "ص ب ر", 103, None, "الحبس والمنع.", None, None),
        (6, "نور", "ن و ر", 194, None, "الضياء وما يقابل الظلمة.", None, None),
        (7, "حكم", "ح ك م", 210, None, "المنع؛ ومنه الحكمة لأنها تمنع من الجهل.", None, None),
        (8, "قول", "ق و ل", 1722, None, "اللفظ الدالّ على المعنى.", None, None),
        (9, "كون", "ك و ن", 1358, None, "الوجود والحدوث.", None, None),
        (10, "ربب", "ر ب ب", 980, None, "التربية والإصلاح والسياسة.", None, None),
    ]
    cur.executemany(
        "INSERT INTO roots(root_id,root,root_spaced,freq,simple,maqayis,semitic,semitic_note)"
        " VALUES (?,?,?,?,?,?,?,?)", roots)

    # ── sources catalog (attribution + license per work) ──
    sources = [
        (1, "مقاييس اللغة", "ابن فارس", "395هـ", "dictionary", None, "public-domain"),
        (2, "الراغب الأصفهاني", "الراغب الأصفهاني", "502هـ", "quran_lexicon", None, "public-domain"),
        (3, "لسان العرب", "ابن منظور", "711هـ", "dictionary", None, "public-domain"),
        (4, "الصحاح", "الجوهري", "393هـ", "dictionary", None, "public-domain"),
        (5, "العين", "الخليل بن أحمد", "170هـ", "dictionary", None, "public-domain"),
        (6, "تاج العروس", "الزبيدي", "1205هـ", "dictionary", None, "public-domain"),
        (7, "الفروق اللغوية", "أبو هلال العسكري", "395هـ", "furuq", "الشاملة #1736", "public-domain"),
        (8, "غريب القرآن", "السجستاني", "330هـ", "quran_lexicon", None, "public-domain"),
    ]
    cur.executemany(
        "INSERT INTO sources(source_id,name,author,death_year,category,edition,license)"
        " VALUES (?,?,?,?,?,?,?)", sources)

    # ── lexicon entries for بحر — several sources to show it is جامع ──
    lex = [
        (1, "الراغب الأصفهاني", "quran_lexicon", 0,
         "أصلُ البَحْر: كلُّ مكانٍ واسعٍ جامعٍ للماءِ الكثير، ثم غلب على الماءِ المِلْح."),
        (1, "لسان العرب", "dictionary", 1,
         "البَحْرُ: الماءُ الكثيرُ المِلْحُ خِلافُ البَرّ، سُمِّي بذلك لعُمقِه واتّساعِه،"
         " والجمعُ أبْحُرٌ وبِحارٌ."),
        (1, "العين", "dictionary", 2,
         "البَحْر: سُمّي بحرًا لاستبحارِه، وهو انبساطُه وسَعَتُه."),
        (1, "الصحاح", "dictionary", 3,
         "البَحْر خِلافُ البَرّ، وتَبَحَّر الرجلُ في العلم: اتّسع فيه."),
    ]
    cur.executemany(
        "INSERT INTO lexicon_entries(root_id,source,category,ordinal,body)"
        " VALUES (?,?,?,?,?)", lex)

    # ── words / occurrences for بحر (2 sample verses shown in design) ──
    words = [
        (1, "وَالْبَحْرِ", 30, 41, "ظَهَرَ الْفَسَادُ فِي الْبَرِّ وَالْبَحْرِ"),
        (1, "الْبَحْرَ", 16, 14,
         "وَهُوَ الَّذِي سَخَّرَ الْبَحْرَ لِتَأْكُلُوا مِنْهُ لَحْمًا طَرِيًّا"),
        (1, "الْبَحْرَ", 2, 50, None),
        (1, "الْبَحْرِ", 5, 96, None),
        (1, "الْبَحْرَ", 7, 138, None),
    ]
    cur.executemany(
        "INSERT INTO words(root_id,surface,surah,ayah,verse_text) VALUES (?,?,?,?,?)", words)

    # ── furuq: بحر × يمّ (verified = 1 → visible) ──
    cur.execute(
        "INSERT INTO furuq(root_a,root_b,maqayis_a,maqayis_b,quran_a,quran_b,"
        "count_a,count_b,semitic_a,semitic_b,difference,source,verified) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,1)",
        ("بحر", "يمم",
         "الاتساع والانبساط", "البحر في سياقٍ خاصّ",
         "لفظ عامّ مقابلٌ للبَرّ", "محصور في قصّة موسى",
         42, 8,
         None, "יָם (yām)",
         "«البحر» هو اللفظ العامّ الشائع. أمّا «اليمّ» فيرد في القرآن محصورًا في "
         "سياق قصّة موسى، ويوافق العبرية יָם. (مسألة الأصل محلّ نظرٍ بين اللغويين.)",
         "الراغب الأصفهاني + جيفري"))

    # unverified example (بحر not affected; a pending pair stays hidden)
    cur.execute(
        "INSERT INTO furuq(root_a,root_b,difference,source,verified) VALUES (?,?,?,?,0)",
        ("علم", "معرفة", "إدخال يدوي — بانتظار المراجعة", "إدخال يدوي"))

    con.commit()
    con.close()
    size = os.path.getsize(OUT)
    print(f"✓ wrote {OUT}  ({size:,} bytes)")


if __name__ == "__main__":
    main()
