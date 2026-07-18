/// A Quranic root with its pre-generated, human-reviewed content.
class Root {
  final int id;
  final String root; // بحر
  final String rootSpaced; // ب ح ر
  final int freq; // 42
  final String? simple; // الشرح المبسّط
  final String? maqayis; // المعنى المحوري — ابن فارس
  final String? semitic; // المقابل السامي (disputed, nullable)
  final String? semiticNote; // cf. Proto-Semitic *b-ḥ-r (?)

  const Root({
    required this.id,
    required this.root,
    required this.rootSpaced,
    required this.freq,
    this.simple,
    this.maqayis,
    this.semitic,
    this.semiticNote,
  });

  factory Root.fromMap(Map<String, Object?> m) => Root(
        id: m['root_id'] as int,
        root: m['root'] as String,
        rootSpaced: m['root_spaced'] as String,
        freq: (m['freq'] as int?) ?? 0,
        simple: m['simple'] as String?,
        maqayis: m['maqayis'] as String?,
        semitic: m['semitic'] as String?,
        semiticNote: m['semitic_note'] as String?,
      );
}

class LexiconEntry {
  final String source; // الراغب الأصفهاني
  final String body;
  const LexiconEntry({required this.source, required this.body});

  factory LexiconEntry.fromMap(Map<String, Object?> m) => LexiconEntry(
        source: m['source'] as String,
        body: m['body'] as String,
      );
}
