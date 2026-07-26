/// A Quranic root with its pre-generated, human-reviewed content.
class Root {
  final int id;
  final String root; // بحر
  final String rootSpaced; // ب ح ر
  final int freq; // 42
  final String? simple; // الشرح المبسّط
  /// True when [simple] was written by a model from the classical sources
  /// rather than by a human. The UI must label these — see word_result_screen.
  final bool simpleGenerated;
  final String? maqayis; // المعنى المحوري — ابن فارس
  final String? semitic; // المقابل السامي (disputed, nullable)
  final String? semiticNote; // cf. Proto-Semitic *b-ḥ-r (?)

  const Root({
    required this.id,
    required this.root,
    required this.rootSpaced,
    required this.freq,
    this.simple,
    this.simpleGenerated = false,
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
        // Absent in a pre-v2 DB, so default to "human-written" rather than
        // silently labelling curated text as generated.
        simpleGenerated: (m['simple_generated'] as int?) == 1,
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
