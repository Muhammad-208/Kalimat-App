/// A source that has entries in the DB, shown in the settings toggle list.
class SourceInfo {
  final String name; // لسان العرب
  final String? category; // dictionary | quran_lexicon | furuq | semitic
  final String? author; // ابن منظور
  final int count; // how many entries it contributes

  const SourceInfo({
    required this.name,
    required this.count,
    this.category,
    this.author,
  });

  factory SourceInfo.fromMap(Map<String, Object?> m) => SourceInfo(
        name: m['name'] as String,
        category: m['category'] as String?,
        author: m['author'] as String?,
        count: (m['cnt'] as int?) ?? 0,
      );
}
