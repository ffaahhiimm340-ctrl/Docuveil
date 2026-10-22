import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// One breakpoint: 900px and wider gets the desktop layout (side bar, two columns).
class Breakpoints {
  Breakpoints._();
  static const double wide = 900;
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

/// Standard page: top bar with back button and title, scrolling body,
/// and an optional pinned bottom area for the main action.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.back = true,
    this.backTo,
    this.bottom,
    this.trailing,
    this.maxWidth = 640,
    this.bigTitle = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool back;

  /// Where the back button goes when there is nothing to pop.
  final String? backTo;
  final List<Widget>? bottom;
  final Widget? trailing;
  final double maxWidth;

  /// Use the larger greeting-style title.
  final bool bigTitle;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final pad = wide ? 44.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth + pad * 2),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(pad, wide ? 28 : 12, pad, 16),
                    children: [
                      _Header(
                        title: title,
                        subtitle: subtitle,
                        back: back,
                        backTo: backTo,
                        trailing: trailing,
                        big: bigTitle,
                        wide: wide,
                      ),
                      const SizedBox(height: 14),
                      ..._spaced(children),
                    ],
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Container(
                color: AppColors.bg,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth + pad * 2),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _spaced(bottom!, gap: 8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> items, {double gap = 12}) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(items[i]);
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.back,
    required this.backTo,
    required this.trailing,
    required this.big,
    required this.wide,
  });

  final String title;
  final String? subtitle;
  final bool back;
  final String? backTo;
  final Widget? trailing;
  final bool big;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final titleStyle = big
        ? (wide ? AppText.t0Wide : AppText.t0)
        : (wide ? AppText.t0 : AppText.t1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (back) ...[
          Semantics(
            button: true,
            label: 'Back',
            child: Material(
              color: AppColors.card,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(backTo ?? '/'),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              if (subtitle != null) Text(subtitle!, style: AppText.sub),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Two columns on wide screens, a single stacked column on phones.
class TwoCol extends StatelessWidget {
  const TwoCol({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 360,
    this.gap = 24,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    Widget col(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: PageScaffold._spaced(items, gap: 14),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: PageScaffold._spaced([...main, ...side], gap: 14),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(main)),
        SizedBox(width: gap),
        SizedBox(width: sideWidth, child: col(side)),
      ],
    );
  }
}
