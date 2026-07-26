import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/responsive.dart';
import '../../shared/widgets.dart';
import '../../data/models/root.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();

  void _search([String? value]) {
    final q = (value ?? _controller.text).trim();
    if (q.isNotEmpty) context.push('/root/$q');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: AdaptiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Settings entry (top corner) ──
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  icon: Icon(Icons.tune,
                      color: dark ? KColors.dSub : KColors.sub),
                  tooltip: 'الإعدادات',
                  onPressed: () => context.push('/settings'),
                ),
              ),
              const SizedBox(height: 8),
              // ── Wordmark ──
              Center(
                child: Column(
                  children: [
                    Text('كَلِمَات',
                        style: TextStyle(
                            fontFamily: KFonts.display,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: teal)),
                    const SizedBox(height: 6),
                    Text('قاموس جذور القرآن',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.4,
                            color: dark ? KColors.dSub : KColors.sub)),
                  ],
                ),
              ),
              const SizedBox(height: 44),

              // ── Search field ──
              _SearchBar(controller: _controller, onSubmit: _search),
              const SizedBox(height: 13),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: dark ? KColors.dBrass : KColors.brass),
                    const SizedBox(width: 7),
                    Text('نبحث عن الجذر تلقائيًا',
                        style: TextStyle(
                            fontSize: 13,
                            color: dark ? KColors.dBrass : KColors.brassText)),
                  ],
                ),
              ),
              const SizedBox(height: 38),

              // ── Suggested roots ──
              const SectionHeader('جذور مقترحة'),
              const SizedBox(height: 16),
              ref.watch(suggestedRootsProvider).when(
                    loading: () => const _ChipsSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (roots) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final r in roots)
                          RootChip(r.root, onTap: () => _search(r.root)),
                      ],
                    ),
                  ),
              const SizedBox(height: 32),

              // ── Most frequent roots ──
              const SectionHeader('أكثر الجذور ورودًا'),
              const SizedBox(height: 8),
              ref.watch(topRootsProvider).when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (roots) => Column(
                      children: [for (final r in roots) _FreqRow(root: r, onTap: () => _search(r.root))],
                    ),
                  ),
              const SizedBox(height: 30),

              // ── Recent searches (local; stub) ──
              const SectionHeader('عمليات البحث الأخيرة'),
              const SizedBox(height: 8),
              _RecentRow(label: 'بحر', onTap: () => _search('بحر')),
              _RecentRow(label: 'صبر', onTap: () => _search('صبر')),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = dark ? KColors.dTeal : KColors.teal;
    return Container(
      decoration: BoxDecoration(
        color: dark ? KColors.dCard : KColors.paperCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? KColors.dCardBorder : const Color(0xFFDCD2BC),
            width: 1.5),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x0D2A251C), blurRadius: 14, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: teal),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmit,
              style: TextStyle(
                  fontSize: 18, color: dark ? KColors.dText : KColors.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: InputBorder.none,
                hintText: 'اكتب كلمة… مثل: بحر',
                hintStyle: TextStyle(
                    fontSize: 18, color: dark ? KColors.dMist : KColors.mist),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreqRow extends StatelessWidget {
  const _FreqRow({required this.root, required this.onTap});
  final Root root;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: dark ? KColors.dCardBorder : const Color(0xFFEBE3D0)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(root.root,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: dark ? KColors.dText : KColors.ink)),
            Text('${root.freq}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? KColors.dBrass : KColors.brass)),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.history,
                size: 16, color: dark ? KColors.dMist : KColors.mist),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 16, color: dark ? KColors.dBody : const Color(0xFF4A4436))),
          ],
        ),
      ),
    );
  }
}

class _ChipsSkeleton extends StatelessWidget {
  const _ChipsSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 40);
}
