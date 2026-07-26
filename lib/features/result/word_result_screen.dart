import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';
import '../../shared/widgets.dart';
import '../../data/models/root.dart';

class WordResultScreen extends ConsumerWidget {
  const WordResultScreen({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(rootResultProvider(query));

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (result) {
            if (result == null) {
              return Center(
                child: Text('لم يُعثر على الجذر «$query»',
                    style: TextStyle(color: dark ? KColors.dSub : KColors.sub)),
              );
            }
            return _Content(result: result);
          },
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.result});
  final RootResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final root = result.root;
    // Per-user setting: drop any source the user has hidden.
    final hidden = ref.watch(hiddenSourcesProvider);
    final visibleLexicon =
        result.lexicon.where((e) => !hidden.contains(e.source)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: AdaptiveContent(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar: back / title / dark toggle ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // In RTL the "forward chevron" points right = back.
              IconButton(
                icon: Icon(Icons.chevron_right, color: teal),
                onPressed: () => context.pop(),
              ),
              Text('الجذر',
                  style: TextStyle(
                      fontSize: 15, color: dark ? KColors.dSub : KColors.sub)),
              IconButton(
                icon: Icon(dark ? Icons.light_mode : Icons.dark_mode,
                    size: 20, color: dark ? KColors.dMist : KColors.mist),
                onPressed: () => ref.read(themeModeProvider.notifier).state =
                    dark ? ThemeMode.light : ThemeMode.dark,
              ),
            ],
          ),

          // ── Root display + frequency badge ──
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(root.rootSpaced,
                    style: TextStyle(
                        fontFamily: KFonts.root,
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 16,
                        height: 1,
                        color: teal)),
                const SizedBox(height: 22),
                _FreqBadge(freq: root.freq),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Simplified explanation ──
          // A generated summary is titled and footed differently from a
          // hand-written one: the reader must never take editorial prose for
          // classical text.
          if (root.simple != null)
            InfoCard(
              title: root.simpleGenerated ? 'شرح تحريري' : 'الشرح المبسّط',
              body: root.simpleGenerated
                  ? '${root.simple!}\n\n'
                      '— صياغة تحريرية مبنية على المصادر أدناه، '
                      'وليست نصًّا منقولًا عن مؤلف.'
                  : root.simple!,
              tinted: true,
            ),
          const SizedBox(height: 16),

          // ── Core meaning (Ibn Faris) ──
          if (root.maqayis != null)
            InfoCard(title: 'المعنى المحوري — ابن فارس', body: root.maqayis!),
          const SizedBox(height: 16),

          // ── Dictionary accordion ──
          if (visibleLexicon.isNotEmpty) _LexiconAccordion(entries: visibleLexicon),
          const SizedBox(height: 16),

          // ── Semitic cognate (dispute) ──
          _SemiticCard(root: root),
          const SizedBox(height: 16),

          // ── Quranic evidence ──
          _EvidenceSection(result: result),
          const SizedBox(height: 16),

          // ── Nearby-words / comparison CTA ──
          if (result.furuq != null) _ComparisonCta(a: result.furuq!.rootA, b: result.furuq!.rootB),
        ],
      ),
      ),
    );
  }
}

class _FreqBadge extends StatelessWidget {
  const _FreqBadge({required this.freq});
  final int freq;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2210) : KColors.verseBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? KColors.dVerseBorder : KColors.verseBorder),
      ),
      child: Text('وردت $freq مرة في القرآن',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dark ? KColors.dBrass : KColors.brassText)),
    );
  }
}

class _LexiconAccordion extends StatelessWidget {
  const _LexiconAccordion({required this.entries});
  final List<LexiconEntry> entries;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    return Container(
      decoration: BoxDecoration(
        color: dark ? KColors.dCard : KColors.paperCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? KColors.dCardBorder : KColors.paperLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
          title: Text('في المعاجم',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: teal)),
          trailing: Text(
            entries.map((e) => e.source).take(2).join(' · '),
            style: TextStyle(fontSize: 12, color: dark ? KColors.dMist : KColors.mist),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.source,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: dark ? KColors.dBrass : KColors.brass)),
                    const SizedBox(height: 8),
                    Text(e.body,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.9,
                            color: dark ? KColors.dBody : const Color(0xFF3A362C))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SemiticCard extends StatelessWidget {
  const _SemiticCard({required this.root});
  final Root root;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = root.semitic ??
        'قارن بعض الباحثين الجذر بمعناه في لغاتٍ ساميّةٍ شقيقة. '
            'المسألة محلّ نظر ولا تُعدّ قولًا مقطوعًا به.';
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: dark ? KColors.dDisputeBg : KColors.disputeBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark ? KColors.dDisputeBorder : KColors.disputeBorder,
            style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المقابل السامي',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: dark ? const Color(0xFFB9AE8C) : const Color(0xFF7A6B4A))),
              const DisputePill(),
            ],
          ),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(
                  fontSize: 16, height: 1.9, color: dark ? KColors.dBody : const Color(0xFF4A4436))),
          if (root.semiticNote != null) ...[
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(root.semiticNote!,
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: dark ? KColors.dMist : KColors.mist)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.result});
  final RootResult result;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final freq = result.root.freq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الشواهد القرآنية',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: teal)),
            Text('$freq موضعًا',
                style: TextStyle(fontSize: 12, color: dark ? KColors.dMist : KColors.mist)),
          ],
        ),
        const SizedBox(height: 14),
        for (final v in result.sampleVerses) ...[
          VerseCard(
            verse: v.verseText ?? v.surface,
            reference: 'سورة ${v.surah}: ${v.ayah}',
          ),
          const SizedBox(height: 14),
        ],
        OutlinedButton(
          onPressed: () => context.push('/verses/${result.root.id}'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(15),
            side: BorderSide(
                color: dark ? const Color(0xFF2A4A43) : KColors.tealTintBorder, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text('عرض كل المواضع ($freq)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: teal)),
        ),
      ],
    );
  }
}

class _ComparisonCta extends StatelessWidget {
  const _ComparisonCta({required this.a, required this.b});
  final String a, b;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0C3B35) : KColors.teal,
        borderRadius: BorderRadius.circular(18),
        border: dark ? Border.all(color: const Color(0xFF17493F)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كلمات قريبة',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: dark ? KColors.dTeal : const Color(0xB3F4EEE1))),
          const SizedBox(height: 10),
          Text('ما الفرق بين $a و $b؟',
              style: const TextStyle(
                  fontFamily: KFonts.root,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4EEE1))),
          const SizedBox(height: 8),
          const Text('مقارنة لغوية · أبو هلال العسكري وغيره',
              style: TextStyle(fontSize: 13, color: Color(0xCCF4EEE1))),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: () => context.push('/compare/$a/$b'),
              style: FilledButton.styleFrom(
                backgroundColor: KColors.dBrass,
                foregroundColor: KColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('افتح المقارنة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
