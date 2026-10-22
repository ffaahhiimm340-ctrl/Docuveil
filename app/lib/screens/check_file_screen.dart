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

/// 11 Check a file: compare any copy against the saved original.
class CheckFileScreen extends StatelessWidget {
  const CheckFileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paper = SampleData.paperById('marksheet');
    final original = paper.copies.firstWhere(
      (c) => c.state == CopyState.original,
    );
    final change = paper.fields.firstWhere((f) => f.isChanged);

    return PageScaffold(
      title: 'Check a file',
      backTo: '/add',
      bottom: [
        AppButton.primary(
          'Check another file',
          onPressed: () => context.go('/add'),
        ),
        AppButton.secondary(
          'What should I do?',
          onPressed: () => context.go('/papers/${paper.id}/changed'),
        ),
      ],
      children: [
        Text(
          'Got a copy from someone or somewhere? See if it still matches your original.',
          style: AppText.sub,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File you picked', style: AppText.smallBold),
              const SizedBox(height: 6),
              Row(
                children: [
                  const IconTile(Icons.description_outlined),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _T('Marksheet_Sem2_copy.pdf'),
                        PathText('Phone / WhatsApp / Documents'),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Change',
                      style: AppText.bodyBold.copyWith(
                        color: AppColors.brand,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compared with your original', style: AppText.smallBold),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconTile(original.kind.icon, tone: Tone.ok),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paper.title, style: AppText.t3),
                        PathText('Laptop: ${original.path}'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          color: AppColors.badTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dangerous_outlined,
                    color: AppColors.bad,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Not the same as your original',
                      style: AppText.t2.copyWith(color: AppColors.bad),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(change.label, style: AppText.smallBold),
                  Text.rich(
                    TextSpan(
                      style: AppText.num(26),
                      children: [
                        TextSpan(
                          text: change.was,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.ink2,
                          ),
                        ),
                        const TextSpan(text: ' to '),
                        TextSpan(
                          text: change.value,
                          style: const TextStyle(color: AppColors.bad),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        InfoBanner(
          tone: Tone.ok,
          child: Text(
            'Ignored as harmless: new file size and a different save date. ${paper.matchingDetails} other details match.',
            style: AppText.body,
          ),
        ),
      ],
    );
  }
}

class _T extends StatelessWidget {
  const _T(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: AppText.t3);
}
