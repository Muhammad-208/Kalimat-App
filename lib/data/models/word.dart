/// A single Quranic occurrence (surface form) of a root.
class WordOccurrence {
  final String surface; // الْبَحْرَ
  final int surah;
  final int ayah;
  final String? verseText; // optional full ayah

  const WordOccurrence({
    required this.surface,
    required this.surah,
    required this.ayah,
    this.verseText,
  });

  factory WordOccurrence.fromMap(Map<String, Object?> m) => WordOccurrence(
        surface: m['surface'] as String,
        surah: m['surah'] as int,
        ayah: m['ayah'] as int,
        verseText: m['verse_text'] as String?,
      );
}

/// Occurrences grouped by surah for the "all locations" screen.
class SurahGroup {
  final String surahName; // البقرة
  final List<WordOccurrence> items;
  const SurahGroup({required this.surahName, required this.items});
}
