import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/data/arabic.dart';

/// These must mirror `tools/normalize.py` / `tools/build_quran_db.py`, because
/// the shipped DB's search keys are precomputed with the Python versions. If
/// these expectations change, the DB has to be rebuilt or lookups break.
void main() {
  group('normalizeArabic', () {
    test('strips tashkeel from a vocalized Quranic form', () {
      expect(normalizeArabic('ٱلْبَحْرَ'), 'البحر');
      expect(normalizeArabic('يَعْلَمُونَ'), 'يعلمون');
    });

    test('unifies hamza seats, alef maqsura and ta marbuta', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إيمان'), 'ايمان');
      expect(normalizeArabic('رحمة'), 'رحمه');
      expect(normalizeArabic('موسى'), 'موسي');
    });

    test('drops non-Arabic characters and collapses whitespace', () {
      expect(normalizeArabic('  بحر123  '), 'بحر');
      expect(normalizeArabic('abc'), '');
    });
  });

  group('stripArticle', () {
    test('removes the definite article', () {
      expect(stripArticle('البحر'), 'بحر');
    });

    test('never strips below three letters', () {
      expect(stripArticle('الم'), 'الم');
    });
  });

  group('collapseDoubles', () {
    test('merges adjacent identical letters for geminate roots', () {
      expect(collapseDoubles('ربب'), 'رب');
      expect(collapseDoubles('يمم'), 'يم');
      expect(collapseDoubles('بحر'), 'بحر');
    });
  });

  group('isFunctionWord', () {
    // Regression: search for لما once answered كلل, because كُلَّمَا was being
    // mis-split as ك + لما. Particles must decline rather than guess — in a
    // dictionary of Quranic roots a wrong root is worse than no answer.
    test('particles and pronouns are rejected', () {
      for (final w in ['لما', 'كما', 'بما', 'ولما', 'لمن', 'ما', 'من', 'ذلك']) {
        expect(isFunctionWord(normalizeArabic(w)), isTrue, reason: w);
      }
    });

    test('words that genuinely have roots are NOT rejected', () {
      // كلما is a real word (root كلل); الماء is موه. Over-blocking these
      // would silently delete valid lookups.
      for (final w in ['كلما', 'كل', 'كان', 'الماء', 'بحر', 'الصلاة']) {
        expect(isFunctionWord(normalizeArabic(w)), isFalse, reason: w);
      }
    });
  });

  group('skeletonArabic', () {
    test('drops long vowels so orthographic variants converge', () {
      // The corpus writes ٱلصَّلَوٰة; users type الصلاة. Both must collapse alike.
      expect(skeletonArabic('الصلوه'), skeletonArabic('الصلاه'));
      expect(skeletonArabic('كتاب'), 'كتب');
    });

    test('keeps the input when stripping would leave almost nothing', () {
      expect(skeletonArabic('اوي'), 'اوي');
    });
  });
}
