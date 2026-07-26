/// Arabic normalization for search.
///
/// Must stay in lockstep with `tools/normalize.py` — the shipped DB stores
/// `roots.root_norm`, `roots.root_fuzzy` and `words.surface_norm` computed with
/// the Python version, so any divergence here silently breaks lookups.
library;

// Harakat, tanwin, shadda, sukun, dagger-alef.
final _tashkeel = RegExp('[ً-ٰٟ]');
final _tatweel = RegExp('ـ');
final _nonArabic = RegExp('[^ء-ي\\s]');
final _spaces = RegExp(r'\s+');

const _subs = <String, String>{
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ؤ': 'و', 'ئ': 'ي', 'ء': '', 'ى': 'ي', 'ة': 'ه',
};

/// Strips diacritics and unifies hamza/alef/yaa/taa. Letters only.
String normalizeArabic(String text) {
  var t = text.replaceAll(_tashkeel, '').replaceAll(_tatweel, '');
  _subs.forEach((from, to) => t = t.replaceAll(from, to));
  return t.replaceAll(_nonArabic, '').replaceAll(_spaces, ' ').trim();
}

/// Drops a leading ال, but never below 3 letters (so روم/ارض stay intact).
String stripArticle(String n) =>
    n.startsWith('ال') && n.length >= 4 ? n.substring(2) : n;

/// Closed-class function words (حروف المعاني والضمائر), in normalized form.
///
/// These carry no root, but undiacritized they collide with real ones: ماء
/// normalizes to ما (the hamza is dropped), so كما/بما land on موه, and the
/// skeleton tier pulls ولما onto يوم. A dictionary of Quranic roots must
/// decline rather than guess — a wrong root is worse than no answer.
///
/// Words that genuinely do have roots are deliberately absent: كان → كون,
/// كلما → كلل, ليس → ليس all remain searchable.
const _functionWords = <String>{
  'ما', 'من', 'عن', 'في', 'الي', 'علي', 'مع', 'لدي', 'عند',
  'لم', 'لن', 'لا', 'ان', 'اذا', 'اذ', 'قد', 'ثم', 'بل', 'او', 'ام',
  'هل', 'لو', 'لولا', 'حتي', 'كي', 'لكن', 'بلي', 'نعم',
  'لما', 'كما', 'بما', 'فما', 'فلما', 'ولما', 'وما', 'لمن', 'ممن', 'عما',
  'هذا', 'هذه', 'ذلك', 'تلك', 'هولاء', 'كذلك', 'الذي', 'التي', 'الذين',
  'هو', 'هي', 'هم', 'هن', 'نحن', 'انا', 'انت', 'انتم', 'اياك',
};

/// Whether [normalized] is a function word that should never resolve to a root.
bool isFunctionWord(String normalized) => _functionWords.contains(normalized);

/// Consonantal skeleton: drops long vowels so الصلاة reaches the corpus's
/// ٱلصَّلَوٰة, and كتاب reaches كتب. Lossy — only used as the last search tier.
String skeletonArabic(String n) {
  final s = n.replaceAll(RegExp('[اوي]'), '');
  return s.length >= 2 ? s : n;
}

/// Merges adjacent identical letters so ربب matches رب, يمم matches يم.
String collapseDoubles(String n) {
  final buf = StringBuffer();
  String? prev;
  for (final ch in n.replaceAll(' ', '').split('')) {
    if (ch != prev) buf.write(ch);
    prev = ch;
  }
  return buf.toString();
}
