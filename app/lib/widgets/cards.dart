import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'chips.dart';
import 'seal_ring.dart';

/// White rounded surface. Pass [onTap] to make it a button.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.card,
    this.borderColor,
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!, width: 2),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A tinted message box with an icon, used for verdicts and tips.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.tone,
    required this.child,
    this.icon,
    this.radius = 20,
  });

  final Tone tone;
  final Widget child;
  final IconData? icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? tone.icon, color: tone.fg, size: 26),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A file path in a monospace face.
class PathText extends StatelessWidget {
  const PathText(this.path, {super.key});
  final String path;

  @override
  Widget build(BuildContext context) => Text(path, style: AppText.path);
}

/// The core "where is my file?" line: place icon, place name, state, exact path.
class CopyLine extends StatelessWidget {
  const CopyLine(this.copy, {super.key, this.compact = false});

  final PaperCopy copy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            copy.kind.icon,
            tone: copy.state.tone,
            size: compact ? 40 : 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      copy.placeName,
                      style: AppText.t3.copyWith(fontSize: compact ? 17 : 18),
                    ),
                    StatusChip(
                      copy.state.label,
                      tone: copy.state.tone,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                PathText(copy.path),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of copies separated by hairlines.
class CopyLines extends StatelessWidget {
  const CopyLines(this.copies, {super.key, this.compact = false});

  final List<PaperCopy> copies;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < copies.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.line),
          CopyLine(copies[i], compact: compact),
        ],
      ],
    );
  }
}

/// Card for one paper: seal, title, status, and every place it lives.
class PaperCard extends StatelessWidget {
  const PaperCard(this.paper, {super.key, this.onTap});

  final Paper paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = paper.status.tone;
    return AppCard(
      borderColor: paper.hasChange ? AppColors.bad : null,
      onTap: onTap ?? () => context.go('/papers/${paper.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SealRing.forPaper(paper, size: 44, mark: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.shortTitle, style: AppText.t3),
                    Text(
                      paper.statusText,
                      style: AppText.smallBold.copyWith(color: tone.fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final c in paper.copies) LocChip.forCopy(c)],
          ),
        ],
      ),
    );
  }
}

/// Plain row with seal, used on Home for short lists.
class PaperRow extends StatelessWidget {
  const PaperRow(this.paper, {super.key, this.subtitle});

  final Paper paper;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => context.go('/papers/${paper.id}'),
      child: Row(
        children: [
          SealRing.forPaper(paper, size: 44, mark: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paper.title, style: AppText.t3),
                Text(
                  subtitle ?? paper.statusText,
                  style: AppText.smallBold.copyWith(
                    color: paper.status.tone.fg,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink2),
        ],
      ),
    );
  }
}

/// Group of rows inside one white card with hairlines between them.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row inside a [ListGroup]: optional leading tile, title, subtitle, trailing.
class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.path,
  });

  final String title;
  final String? subtitle;
  final String? path;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.t3),
                    if (subtitle != null) Text(subtitle!, style: AppText.small),
                    if (path != null) PathText(path!),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppText.t2)),
        if (action != null)
          TextButton(
            onPressed: onAction ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              action!,
              style: AppText.bodyBold.copyWith(color: AppColors.brand),
            ),
          ),
      ],
    );
  }
}
