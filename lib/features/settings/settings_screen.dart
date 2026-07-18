import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';
import '../../shared/widgets.dart';
import '../../data/models/source_info.dart';

/// Arabic labels for the source categories.
const _categoryLabels = {
  'dictionary': 'المعاجم العامة',
  'quran_lexicon': 'المعاجم القرآنية',
  'furuq': 'الفروق اللغوية',
  'semitic': 'المقابلات السامية',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    final sourcesAsync = ref.watch(availableSourcesProvider);
    final hidden = ref.watch(hiddenSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: IconButton(
          icon: Icon(Icons.chevron_right, color: teal),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (hidden.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(hiddenSourcesProvider.notifier).showAll(),
              child: Text('إظهار الكل',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (sources) {
          if (sources.isEmpty) {
            return Center(
              child: Text('لا توجد مصادر بعد',
                  style: TextStyle(color: dark ? KColors.dSub : KColors.sub)),
            );
          }
          // group by category, preserving the repository's order
          final groups = <String, List<SourceInfo>>{};
          for (final s in sources) {
            (groups[s.category ?? 'dictionary'] ??= []).add(s);
          }

          return AdaptiveContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                _SignInCard(),
                const SizedBox(height: 16),
                _Intro(),
                const SizedBox(height: 20),
                for (final entry in groups.entries) ...[
                  SectionHeader(_categoryLabels[entry.key] ?? entry.key),
                  const SizedBox(height: 12),
                  _SourceGroup(sources: entry.value, hidden: hidden),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SignInCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0C3B35) : KColors.teal;
    final user = ref.watch(authStateProvider).valueOrNull;

    // Signed in → show account + sign out.
    if (user != null) {
      return Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFF4EEE1), size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مُسجَّل الدخول · تتم المزامنة',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF4EEE1))),
                  if (user.email != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(user.email!,
                          style: const TextStyle(fontSize: 12, color: Color(0xCCF4EEE1))),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              child: const Text('خروج',
                  style: TextStyle(color: Color(0xFFF4EEE1), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    // Signed out → prompt.
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/auth'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: Color(0xFFF4EEE1), size: 28),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تسجيل الدخول للمزامنة',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF4EEE1))),
                    SizedBox(height: 2),
                    Text('الاستخدام متاح دون حساب',
                        style: TextStyle(fontSize: 12, color: Color(0xCCF4EEE1))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Color(0x99F4EEE1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? KColors.dExplainBg : KColors.explainBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? KColors.dExplainBorder : KColors.explainBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: dark ? KColors.dTeal : KColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'اختر المصادر التي تظهر في «في المعاجم». يُطبَّق اختيارك على كل عمليات البحث،'
              ' ويُحفظ على جهازك.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: dark ? KColors.dBody : KColors.sub),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceGroup extends ConsumerWidget {
  const _SourceGroup({required this.sources, required this.hidden});
  final List<SourceInfo> sources;
  final Set<String> hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? KColors.dCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? KColors.dCardBorder : const Color(0xFFE4DAC5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < sources.length; i++) ...[
            _SourceRow(
              source: sources[i],
              visible: !hidden.contains(sources[i].name),
              onChanged: () {
                ref.read(hiddenSourcesProvider.notifier).toggle(sources[i].name);
                // if signed in, sync the change up
                final user = ref.read(authServiceProvider).currentUser;
                if (user != null) {
                  ref.read(syncServiceProvider).push(
                        uid: user.uid,
                        hiddenSources: ref.read(hiddenSourcesProvider),
                      );
                }
              },
            ),
            if (i != sources.length - 1)
              Divider(
                  height: 1,
                  color: dark ? KColors.dCardBorder : const Color(0xFFF0E9D8)),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.visible,
    required this.onChanged,
  });
  final SourceInfo source;
  final bool visible;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: dark ? KColors.dText : KColors.ink)),
                if (source.author != null || source.count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      [
                        if (source.author != null) source.author!,
                        if (source.count > 0) '${source.count} مدخلًا',
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: dark ? KColors.dMist : KColors.mist),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: visible,
            activeColor: teal,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
