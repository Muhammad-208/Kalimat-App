import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';
import '../../shared/widgets.dart';
import '../../data/models/furuq.dart';

class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key, required this.rootA, required this.rootB});
  final String rootA, rootB;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final async = ref.watch(comparisonProvider('$rootA|$rootB'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('مقارنة'),
        leading: IconButton(
          icon: Icon(Icons.chevron_right, color: teal),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (f) => f == null
              ? Center(
                  child: Text('لا توجد مقارنة محقّقة لهذا الزوج',
                      style: TextStyle(color: dark ? KColors.dSub : KColors.sub)),
                )
              : _Body(f: f),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.f});
  final Furuq f;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      child: AdaptiveContent(
        maxWidth: 820,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderPair(a: f.rootA, b: f.rootB),
          const SizedBox(height: 18),
          _Row(label: 'المعنى المحوري', a: f.maqayisA, b: f.maqayisB),
          _Row(label: 'الدلالة القرآنية', a: f.quranA, b: f.quranB),
          _Row(
            label: 'عدد المواضع',
            a: f.countA?.toString(),
            b: f.countB?.toString(),
            big: true,
          ),
          _Row(
            label: 'المقابل السامي',
            a: f.semiticA,
            b: f.semiticB,
            dispute: true,
          ),
          const SizedBox(height: 6),
          _DifferenceCard(text: f.difference),
          if (f.source != null) ...[
            const SizedBox(height: 14),
            _SourceNote(source: f.source!),
          ],
        ],
      ),
      ),
    );
  }
}

class _HeaderPair extends StatelessWidget {
  const _HeaderPair({required this.a, required this.b});
  final String a, b;

  Widget _card(BuildContext c, String word) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0C3B35) : KColors.teal,
        borderRadius: BorderRadius.circular(16),
        border: dark ? Border.all(color: const Color(0xFF17493F)) : null,
      ),
      child: Column(
        children: [
          Text(word,
              style: const TextStyle(
                  fontFamily: KFonts.root,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4EEE1))),
          const SizedBox(height: 6),
          Text(word.split('').join(' '),
              style: const TextStyle(
                  fontSize: 13, letterSpacing: 6, color: Color(0xCCF4EEE1))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _card(context, a)),
            const SizedBox(width: 14),
            Expanded(child: _card(context, b)),
          ],
        ),
        // gold × badge overlapping the gap
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KColors.dBrass,
            shape: BoxShape.circle,
            border: Border.all(color: dark ? KColors.dBg : KColors.paper, width: 3),
          ),
          child: const Text('×',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: KColors.ink)),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.a,
    required this.b,
    this.big = false,
    this.dispute = false,
  });
  final String label;
  final String? a, b;
  final bool big, dispute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // centered brass label (+ dispute pill)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: KColors.brass)),
              if (dispute) ...[
                const SizedBox(width: 8),
                const DisputePill(text: 'محل خلاف'),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Cell(text: a, big: big, dispute: dispute)),
              const SizedBox(width: 12),
              Expanded(child: _Cell(text: b, big: big, dispute: dispute)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.text, this.big = false, this.dispute = false});
  final String? text;
  final bool big, dispute;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final content = (text == null || text!.isEmpty) ? '—' : text!;
    final Color bg, border;
    if (dispute) {
      bg = dark ? KColors.dDisputeBg : KColors.disputeBg;
      border = dark ? KColors.dDisputeBorder : KColors.disputeBorder;
    } else {
      bg = dark ? KColors.dCard : KColors.paperCard;
      border = dark ? KColors.dCardBorder : KColors.paperLine;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      alignment: big ? Alignment.center : AlignmentDirectional.centerStart,
      child: Text(
        content,
        textAlign: big ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: big ? 22 : 15,
          height: big ? 1.2 : 1.85,
          fontWeight: big ? FontWeight.w700 : FontWeight.w400,
          color: big
              ? teal
              : (dark ? KColors.dBody : KColors.ink),
        ),
      ),
    );
  }
}

class _DifferenceCard extends StatelessWidget {
  const _DifferenceCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: dark ? KColors.dVerseBg : KColors.verseBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? KColors.dVerseBorder : KColors.verseBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفرق',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: dark ? KColors.dBrass : KColors.brassText)),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  fontSize: 17,
                  height: 2,
                  color: dark ? KColors.dVerseText : const Color(0xFF3A2E18))),
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source});
  final String source;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? KColors.dCard : KColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? KColors.dCardBorder : KColors.paperLine),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 18, color: dark ? KColors.dMist : KColors.mist),
          const SizedBox(width: 10),
          Expanded(
            child: Text('المصدر: $source — ليس في العسكري.',
                style: TextStyle(
                    fontSize: 13, height: 1.7, color: dark ? KColors.dSub : KColors.sub)),
          ),
        ],
      ),
    );
  }
}
