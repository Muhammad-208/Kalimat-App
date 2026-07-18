import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Small caps-style section label with a trailing hairline (used everywhere).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? KColors.dTeal : KColors.teal;
    final line = dark ? KColors.dCardBorder : KColors.paperLine;
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: accent)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: line)),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// A rounded "pill" root chip (بحر).
class RootChip extends StatelessWidget {
  const RootChip(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? KColors.dExplainBg : KColors.tealTintBg,
      shape: StadiumBorder(
          side: BorderSide(
              color: dark ? KColors.dExplainBorder : KColors.tealTintBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(label,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: dark ? KColors.dTeal : KColors.teal)),
        ),
      ),
    );
  }
}

/// A generic titled card (used for الشرح المبسّط / المعنى المحوري).
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.tinted = false,
  });
  final String title;
  final String body;
  final bool tinted; // teal-tinted "simplified explanation" style

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg, border;
    if (tinted) {
      bg = dark ? KColors.dExplainBg : KColors.explainBg;
      border = dark ? KColors.dExplainBorder : KColors.explainBorder;
    } else {
      bg = dark ? KColors.dCard : KColors.paperCard;
      border = dark ? KColors.dCardBorder : KColors.paperLine;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(
                  fontSize: tinted ? 18 : 17,
                  height: 1.9,
                  color: dark ? KColors.dText : KColors.ink)),
        ],
      ),
    );
  }
}

/// A Quranic verse card (Amiri Quran, warm parchment background).
class VerseCard extends StatelessWidget {
  const VerseCard({super.key, required this.verse, required this.reference});
  final String verse; // ظَهَرَ الْفَسَادُ...
  final String reference; // الروم: 41

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: dark ? KColors.dVerseBg : KColors.verseBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? KColors.dVerseBorder : KColors.verseBorder),
      ),
      child: Column(
        children: [
          Text(verse,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: KFonts.quran,
                  fontSize: 25,
                  height: 2.15,
                  color: dark ? KColors.dVerseText : KColors.ink)),
          const SizedBox(height: 12),
          Text(reference,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? KColors.dBrass : KColors.brassText)),
        ],
      ),
    );
  }
}

/// The amber "scholarly dispute" pill (◈ محل خلاف علمي).
class DisputePill extends StatelessWidget {
  const DisputePill({super.key, this.text = 'محل خلاف علمي'});
  final String text;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2210) : KColors.verseBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? KColors.dVerseBorder : KColors.verseBorder),
      ),
      child: Text('◈ $text',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dark ? KColors.dBrass : KColors.brassText)),
    );
  }
}
