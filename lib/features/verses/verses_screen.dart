import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';
import '../../data/models/word.dart';

class VersesScreen extends ConsumerWidget {
  const VersesScreen({super.key, required this.rootId});
  final int rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final async = ref.watch(verseListProvider(rootId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_right, color: teal),
          onPressed: () => context.pop(),
        ),
        title: async.maybeWhen(
          data: (d) => d == null
              ? const Text('الشواهد')
              : Column(
                  children: [
                    Text('الشواهد القرآنية · ${d.root.root}',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: teal)),
                    Text('${d.total} موضعًا في ${d.surahCount} سورة',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: dark ? KColors.dMist : KColors.mist)),
                  ],
                ),
          orElse: () => const Text('الشواهد'),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
          data: (d) {
            if (d == null || d.groups.isEmpty) {
              return Center(
                child: Text('لا توجد مواضع',
                    style: TextStyle(color: dark ? KColors.dSub : KColors.sub)),
              );
            }
            return AdaptiveContent(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                itemCount: d.groups.length,
                itemBuilder: (_, i) => _SurahBlock(group: d.groups[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _countLabel(int n) {
  if (n == 1) return 'موضع واحد';
  if (n == 2) return 'موضعان';
  if (n <= 10) return '$n مواضع';
  return '$n موضعًا';
}

class _SurahBlock extends StatelessWidget {
  const _SurahBlock({required this.group});
  final SurahGroup group;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // surah header pill
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: dark ? KColors.dCard : const Color(0xFFEFE7D6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group.surahName,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dark ? KColors.dTeal : KColors.teal)),
              Text(_countLabel(group.items.length),
                  style: TextStyle(
                      fontSize: 12, color: dark ? KColors.dSub : KColors.sub)),
            ],
          ),
        ),
        for (final w in group.items) _VerseRow(occ: w),
      ],
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({required this.occ});
  final WordOccurrence occ;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: dark ? KColors.dCardBorder : const Color(0xFFEBE3D0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(occ.surface,
              style: TextStyle(
                  fontFamily: KFonts.quran,
                  fontSize: 22,
                  color: dark ? KColors.dText : KColors.ink)),
          Text('${occ.ayah}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark ? KColors.dBrass : KColors.brass)),
        ],
      ),
    );
  }
}
