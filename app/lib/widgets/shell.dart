import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'layout.dart';
import 'seal_ring.dart';

/// Wraps every signed-in screen. Wide windows get the side bar, phones get the
/// bottom bar (only on the five main screens). Same words in both.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabRoots = {'/', '/papers', '/alerts', '/audit'};

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(
          children: [
            _SideNav(location: location),
            const VerticalDivider(width: 1, color: AppColors.line),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: child,
      bottomNavigationBar: _tabRoots.contains(location)
          ? _BottomNav(location: location)
          : null,
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.location});
  final String location;

  bool _on(String route) =>
      route == '/' ? location == '/' : location.startsWith(route);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Row(
              children: [
                const SealRing(size: 38, baseColor: AppColors.brand),
                const SizedBox(width: 10),
                Text(
                  'Docuveil',
                  style: AppText.t0.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SideLink(
            label: 'Home',
            icon: Icons.home_outlined,
            route: '/',
            on: _on('/'),
          ),
          _SideLink(
            label: 'My papers',
            icon: Icons.description_outlined,
            route: '/papers',
            on: _on('/papers'),
          ),
          _SideLink(
            label: 'Alerts',
            icon: Icons.notifications_none_rounded,
            route: '/alerts',
            on: _on('/alerts'),
            badge: 1,
          ),
          _SideLink(
            label: 'Check before applying',
            icon: Icons.verified_user_outlined,
            route: '/audit',
            on: _on('/audit'),
          ),
          _SideLink(
            label: 'Where my papers are',
            icon: Icons.folder_outlined,
            route: '/locations',
            on: _on('/locations'),
          ),
          _SideLink(
            label: 'Devices and sync',
            icon: Icons.devices_rounded,
            route: '/devices',
            on: _on('/devices'),
          ),
          _SideLink(
            label: 'Settings',
            icon: Icons.tune_rounded,
            route: '/settings',
            on: _on('/settings'),
          ),
          const Spacer(),
          const Divider(color: AppColors.line),
          const _TextSizePicker(),
        ],
      ),
    );
  }
}

class _SideLink extends StatelessWidget {
  const _SideLink({
    required this.label,
    required this.icon,
    required this.route,
    required this.on,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool on;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.brand : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: on ? AppColors.brandTint : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go(route),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.t3.copyWith(color: color),
                    ),
                  ),
                  if (badge != null) _Badge(badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: AppColors.bad,
      borderRadius: BorderRadius.circular(11),
    ),
    alignment: Alignment.center,
    child: Text(
      '$count',
      style: AppText.smallBold.copyWith(color: Colors.white, fontSize: 13),
    ),
  );
}

/// Three-step text size control (A A A). Lives in the side bar and in Settings.
class _TextSizePicker extends StatelessWidget {
  const _TextSizePicker();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Text size',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextSizeChoice(),
      ],
    ),
  );
}

class TextSizeChoice extends StatelessWidget {
  const TextSizeChoice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppState.textScale,
      builder: (context, value, _) {
        Widget item(String tip, double scale, double fontSize) {
          final on = (value - scale).abs() < 0.01;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                selected: on,
                label: 'Text size $tip',
                child: Material(
                  color: on ? AppColors.brandTint : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: on ? AppColors.brand : AppColors.line,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () => AppState.textScale.value = scale,
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          'A',
                          textScaler: TextScaler.noScaling,
                          style: AppText.bodyBold.copyWith(
                            fontSize: fontSize,
                            color: on ? AppColors.brand : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            item('small', AppState.small, 15),
            item('normal', AppState.normal, 20),
            item('large', AppState.large, 26),
          ],
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, IconData icon, String route, {int? badge}) {
      final on = route == '/' ? location == '/' : location.startsWith(route);
      final color = on ? AppColors.brand : AppColors.ink2;
      return Expanded(
        child: InkWell(
          onTap: () => context.go(route),
          child: SizedBox(
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      textScaler: const TextScaler.linear(1),
                      style: AppText.smallBold.copyWith(
                        color: color,
                        fontSize: 14,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(top: 2, right: 16, child: _Badge(badge)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.card,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                item('Home', Icons.home_outlined, '/'),
                item('Papers', Icons.description_outlined, '/papers'),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Add a paper',
                    child: InkWell(
                      onTap: () => context.go('/add'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.card,
                                  width: 5,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                item(
                  'Alerts',
                  Icons.notifications_none_rounded,
                  '/alerts',
                  badge: 1,
                ),
                item('Check', Icons.verified_user_outlined, '/audit'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
