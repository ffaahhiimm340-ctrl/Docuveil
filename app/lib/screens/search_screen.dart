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

/// 18 Search: find text inside papers, on every device, and see where each match lives.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController(text: 'cgpa');
  PlaceKind? _place;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Every field whose label or value contains the query.
  List<(Paper, PaperField, PaperCopy)> get _hits {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <(Paper, PaperField, PaperCopy)>[];
    for (final p in SampleData.papers) {
      for (final f in p.fields) {
        final text = '${f.label} ${f.value} ${f.was ?? ''}'.toLowerCase();
        if (!text.contains(q) && !p.title.toLowerCase().contains(q)) continue;
        for (final c in p.copies) {
          if (_place != null && c.kind != _place) continue;
          out.add((p, f, c));
        }
        break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hits = _hits;
    return PageScaffold(
      title: 'Search your papers',
      backTo: '/papers',
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          style: AppText.t3.copyWith(fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(_controller.clear),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OptionPill(
              'Everywhere',
              selected: _place == null,
              onTap: () => setState(() => _place = null),
            ),
            OptionPill(
              'Phone',
              selected: _place == PlaceKind.phone,
              onTap: () => setState(() => _place = PlaceKind.phone),
            ),
            OptionPill(
              'Laptop',
              selected: _place == PlaceKind.laptop,
              onTap: () => setState(() => _place = PlaceKind.laptop),
            ),
            OptionPill(
              'Drive',
              selected: _place == PlaceKind.cloud,
              onTap: () => setState(() => _place = PlaceKind.cloud),
            ),
          ],
        ),
        Text(
          '${hits.length} result${hits.length == 1 ? '' : 's'}',
          style: AppText.smallBold,
        ),
        for (final h in hits)
          AppCard(
            borderColor: h.$3.state == CopyState.changed ? AppColors.bad : null,
            onTap: () => context.go('/papers/${h.$1.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(h.$1.title, style: AppText.t3),
                    if (h.$3.state == CopyState.changed)
                      const StatusChip(
                        'Changed copy',
                        tone: Tone.bad,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: AppText.sub,
                    children: [
                      const TextSpan(text: '…'),
                      TextSpan(
                        text: h.$2.label,
                        style: AppText.bodyBold.copyWith(
                          backgroundColor: AppColors.warnTint,
                        ),
                      ),
                      TextSpan(
                        text:
                            ': ${h.$3.state == CopyState.changed ? h.$2.value : (h.$2.was ?? h.$2.value)}…',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                LocChip.forCopy(h.$3),
                const SizedBox(height: 4),
                PathText(h.$3.path),
              ],
            ),
          ),
        if (hits.isEmpty)
          Text('Nothing found. Try another word.', style: AppText.sub),
        Text('Recent searches', style: AppText.smallBold),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in const ['roll number', 'insurance', 'date of birth'])
              OptionPill(r, onTap: () => setState(() => _controller.text = r)),
          ],
        ),
      ],
    );
  }
}
