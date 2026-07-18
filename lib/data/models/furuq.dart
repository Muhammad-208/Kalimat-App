/// A semantic-differentiation pair (بحر × يمّ). Only surfaced when verified == 1.
class Furuq {
  final String rootA;
  final String rootB;
  final String? maqayisA, maqayisB;
  final String? quranA, quranB;
  final int? countA, countB;
  final String? semiticA, semiticB;
  final String difference; // الفرق
  final String? source;
  final bool verified;

  const Furuq({
    required this.rootA,
    required this.rootB,
    required this.difference,
    this.maqayisA,
    this.maqayisB,
    this.quranA,
    this.quranB,
    this.countA,
    this.countB,
    this.semiticA,
    this.semiticB,
    this.source,
    this.verified = false,
  });

  factory Furuq.fromMap(Map<String, Object?> m) => Furuq(
        rootA: m['root_a'] as String,
        rootB: m['root_b'] as String,
        maqayisA: m['maqayis_a'] as String?,
        maqayisB: m['maqayis_b'] as String?,
        quranA: m['quran_a'] as String?,
        quranB: m['quran_b'] as String?,
        countA: m['count_a'] as int?,
        countB: m['count_b'] as int?,
        semiticA: m['semitic_a'] as String?,
        semiticB: m['semitic_b'] as String?,
        difference: m['difference'] as String,
        source: m['source'] as String?,
        verified: ((m['verified'] as int?) ?? 0) == 1,
      );
}
