import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/layout.dart';

enum _Filter { all, attention, expiring }

/// 05 My papers: every paper with every place a copy lives.
class PapersScreen extends StatefulWidget {
  const PapersScreen({super.key});

  @override
  State<PapersScreen> createState() => _PapersScreenState();
}

class _PapersScreenState extends State<PapersScreen> {
  _Filter _filter = _Filter.all;

  List<Paper> get _shown {
    final all = SampleData.papers;
    return switch (_filter) {
      _Filter.all => all,
      _Filter.attention =>
        all.where((p) => p.status != PaperStatus.safe).toList(),
      _Filter.expiring =>
        all
            .where((p) => p.statusText.toLowerCase().contains('renews'))
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final all = SampleData.papers;
    final attention = all.where((p) => p.status != PaperStatus.safe).length;
    final expiring = all
        .where((p) => p.statusText.toLowerCase().contains('renews'))
        .length;

    return PageScaffold(
      title: 'My papers',
      subtitle: wide
          ? '${all.length} papers. Each row shows every place a copy lives.'
          : null,
      back: false,
      bigTitle: true,
      maxWidth: wide ? 1180 : 640,
      trailing: wide
          ? SizedBox(
              width: 200,
              child: AppButton.primary(
                'Add a paper',
                icon: Icons.add_rounded,
                onPressed: () => context.go('/add'),
              ),
            )
          : OptionPill(
              'By place',
              icon: Icons.folder_outlined,
              onTap: () => context.go('/locations'),
            ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: wide ? 420 : double.infinity,
              child: _SearchBox(onTap: () => context.go('/search')),
            ),
            OptionPill(
              'All ${all.length}',
              selected: _filter == _Filter.all,
              onTap: () => setState(() => _filter = _Filter.all),
            ),
            OptionPill(
              'Needs attention $attention',
              selected: _filter == _Filter.attention,
              onTap: () => setState(() => _filter = _Filter.attention),
            ),
            OptionPill(
              'Expiring $expiring',
              selected: _filter == _Filter.expiring,
              onTap: () => setState(() => _filter = _Filter.expiring),
            ),
          ],
        ),
        if (wide)
          _PapersTable(papers: _shown)
        else
          Column(
            children: [
              for (final p in _shown) ...[
                PaperCard(p),
                const SizedBox(height: 8),
              ],
              if (_shown.isEmpty)
                Text('Nothing here. All good.', style: AppText.sub),
            ],
          ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: AppColors.ink2),
              const SizedBox(width: 10),
              Text(
                'Search inside your papers',
                style: AppText.body.copyWith(color: AppColors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PapersTable extends StatelessWidget {
  const _PapersTable({required this.papers});
  final List<Paper> papers;

  Widget _cell(Paper p, PlaceKind kind) {
    final copy = p.copies.where((c) => c.kind == kind).toList();
    if (copy.isEmpty) return Text('Not here', style: AppText.small);
    final c = copy.first;
    return Align(
      alignment: Alignment.centerLeft,
      child: LocChip(c.state.label, tone: c.state.tone),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget head(String t, {int flex = 2}) => Expanded(
      flex: flex,
      child: Text(t, style: AppText.smallBold),
    );
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                head('Paper', flex: 3),
                head('Status', flex: 3),
                head('Phone'),
                head('Laptop'),
                head('Google Drive'),
                head('Last checked', flex: 3),
              ],
            ),
          ),
          for (final p in papers) ...[
            const Divider(height: 1, color: AppColors.line),
            InkWell(
              onTap: () => context.go('/papers/${p.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(p.title, style: AppText.t3)),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(p.statusText, tone: p.status.tone),
                      ),
                    ),
                    Expanded(flex: 2, child: _cell(p, PlaceKind.phone)),
                    Expanded(flex: 2, child: _cell(p, PlaceKind.laptop)),
                    Expanded(flex: 2, child: _cell(p, PlaceKind.cloud)),
                    Expanded(
                      flex: 3,
                      child: Text('Today, 9:13 am', style: AppText.small),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
