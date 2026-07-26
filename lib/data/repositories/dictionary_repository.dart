import 'package:sqflite/sqflite.dart';
import '../arabic.dart';
import '../db/database.dart';
import '../models/root.dart';
import '../models/word.dart';
import '../models/furuq.dart';
import '../models/source_info.dart';

/// All reads go through here. The app is read-only over the bundled DB.
///
/// IMPORTANT (religious-content safety): `furuq` rows are ONLY returned when
/// `verified = 1`. Unverified/pending scholarly comparisons never reach users.
class DictionaryRepository {
  DictionaryRepository(this._db);
  final KalimatDb _db;

  Future<Database> get _d => _db.database;

  // ── Home screen ────────────────────────────────────────
  Future<List<Root>> suggestedRoots() async {
    // Curated shortlist; swap for a `featured` flag if you add one.
    const seeds = ['بحر', 'علم', 'رحمة', 'صبر', 'نور', 'حكم'];
    final db = await _d;
    final rows = await db.query(
      'roots',
      where: 'root IN (${List.filled(seeds.length, '?').join(',')})',
      whereArgs: seeds,
    );
    final byRoot = {for (final r in rows) r['root'] as String: Root.fromMap(r)};
    return [for (final s in seeds) if (byRoot[s] != null) byRoot[s]!];
  }

  Future<List<Root>> mostFrequentRoots({int limit = 3}) async {
    final db = await _d;
    final rows =
        await db.query('roots', orderBy: 'freq DESC', limit: limit);
    return rows.map(Root.fromMap).toList();
  }

  // ── Search ─────────────────────────────────────────────
  /// Resolves a typed word to its root.
  ///
  /// Users type undiacritized, often with the ال article and inflected
  /// ("البحر", "يعلمون"), while the corpus stores fully vocalized forms
  /// ("ٱلْبَحْرَ"). Everything is therefore compared on the normalized columns
  /// the build pipeline precomputes — never on the raw text.
  Future<Root?> resolveRoot(String query) async {
    final n = normalizeArabic(query);
    if (n.isEmpty) return null;
    final db = await _d;
    final bare = stripArticle(n);

    // 1) the root itself, with or without the article ("بحر", "البحر")
    var rows = await db.query('roots',
        where: 'root_norm IN (?,?)', whereArgs: [n, bare], limit: 1);
    if (rows.isNotEmpty) return Root.fromMap(rows.first);

    // 2) a precomputed spelling variant of a real Quranic word
    //    ("يعلمون" -> علم, "الكتاب" -> كتب, "بحار" -> بحر)
    var hit = await db.rawQuery(
      'SELECT r.* FROM word_keys k JOIN roots r ON r.root_id = k.root_id '
      'WHERE k.kind = 0 AND k.key IN (?,?) ORDER BY r.freq DESC LIMIT 1',
      [n, bare],
    );
    if (hit.isNotEmpty) return Root.fromMap(hit.first);

    // 3) geminate/weak fallback: الرب -> ربب, اليم -> يمم
    final fuzzy = collapseDoubles(bare);
    rows = await db.query('roots',
        where: 'root_fuzzy = ?',
        whereArgs: [fuzzy],
        orderBy: 'freq DESC',
        limit: 1);
    if (rows.isNotEmpty) return Root.fromMap(rows.first);

    // 4) consonantal skeleton — catches Quranic spellings that drop or move a
    //    long vowel ("الصلاة" vs the corpus's ٱلصَّلَوٰة). Lossy, so it runs last.
    hit = await db.rawQuery(
      'SELECT r.* FROM word_keys k JOIN roots r ON r.root_id = k.root_id '
      'WHERE k.kind = 1 AND k.key IN (?,?) ORDER BY r.freq DESC LIMIT 1',
      [skeletonArabic(n), skeletonArabic(bare)],
    );
    if (hit.isNotEmpty) return Root.fromMap(hit.first);

    // 4) last resort: prefix match on the normalized root
    rows = await db.query('roots',
        where: 'root_norm LIKE ?',
        whereArgs: ['$bare%'],
        orderBy: 'freq DESC',
        limit: 1);
    return rows.isEmpty ? null : Root.fromMap(rows.first);
  }

  // ── Word-result screen ─────────────────────────────────
  Future<List<LexiconEntry>> lexiconFor(int rootId) async {
    final db = await _d;
    final rows = await db.query('lexicon_entries',
        where: 'root_id = ?', whereArgs: [rootId], orderBy: 'ordinal');
    return rows.map(LexiconEntry.fromMap).toList();
  }

  Future<List<WordOccurrence>> occurrences(int rootId, {int? limit}) async {
    final db = await _d;
    // Ayah text lives in `ayahs` (stored once per verse), not on each word row.
    final rows = await db.rawQuery(
      'SELECT w.surface, w.surah, w.ayah, a.text AS verse_text '
      'FROM words w LEFT JOIN ayahs a '
      '  ON a.surah = w.surah AND a.ayah = w.ayah '
      'WHERE w.root_id = ? ORDER BY w.surah, w.ayah'
      '${limit != null ? ' LIMIT $limit' : ''}',
      [rootId],
    );
    return rows.map(WordOccurrence.fromMap).toList();
  }

  Future<Root?> rootById(int id) async {
    final db = await _d;
    final rows =
        await db.query('roots', where: 'root_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Root.fromMap(rows.first);
  }

  /// Occurrences grouped by surah name for the "all locations" screen.
  Future<List<SurahGroup>> occurrencesBySurah(int rootId) async {
    final db = await _d;
    final rows = await db.rawQuery(
      'SELECT w.surface, w.surah, w.ayah, a.text AS verse_text, '
      '       s.name AS surah_name '
      'FROM words w JOIN surahs s ON s.surah = w.surah '
      'LEFT JOIN ayahs a ON a.surah = w.surah AND a.ayah = w.ayah '
      'WHERE w.root_id = ? ORDER BY w.surah, w.ayah',
      [rootId],
    );
    final groups = <String, List<WordOccurrence>>{};
    final order = <String>[];
    for (final r in rows) {
      final name = r['surah_name'] as String;
      if (!order.contains(name)) order.add(name);
      (groups[name] ??= []).add(WordOccurrence.fromMap(r));
    }
    return [for (final n in order) SurahGroup(surahName: n, items: groups[n]!)];
  }

  // ── Settings: which sources exist ──────────────────────
  /// Sources that actually have lexicon entries, grouped-friendly for settings.
  Future<List<SourceInfo>> availableSources() async {
    final db = await _d;
    final rows = await db.rawQuery('''
      SELECT le.source AS name,
             COALESCE(le.category, s.category) AS category,
             s.author AS author,
             COUNT(*) AS cnt
      FROM lexicon_entries le
      LEFT JOIN sources s ON s.name = le.source
      GROUP BY le.source
      ORDER BY category, cnt DESC
    ''');
    return rows.map(SourceInfo.fromMap).toList();
  }

  // ── Furuq (verified only) ──────────────────────────────
  Future<Furuq?> verifiedFuruqFor(String root) async {
    final db = await _d;
    final rows = await db.query(
      'furuq',
      where: '(root_a = ? OR root_b = ?) AND verified = 1',
      whereArgs: [root, root],
      limit: 1,
    );
    return rows.isEmpty ? null : Furuq.fromMap(rows.first);
  }

  /// A specific verified pair, matched in either order (بحر×يمّ == يمّ×بحر).
  Future<Furuq?> verifiedFuruqPair(String a, String b) async {
    final db = await _d;
    final rows = await db.query(
      'furuq',
      where: '((root_a = ? AND root_b = ?) OR (root_a = ? AND root_b = ?))'
          ' AND verified = 1',
      whereArgs: [a, b, b, a],
      limit: 1,
    );
    return rows.isEmpty ? null : Furuq.fromMap(rows.first);
  }
}
