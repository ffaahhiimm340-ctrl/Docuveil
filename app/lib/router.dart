import 'package:go_router/go_router.dart';

import 'screens/add_flow.dart';
import 'screens/alerts_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/changed_screen.dart';
import 'screens/check_file_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/home_screen.dart';
import 'screens/locations_screen.dart';
import 'screens/onboarding/set_lock_screen.dart';
import 'screens/onboarding/unlock_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/paper_detail_screen.dart';
import 'screens/papers_screen.dart';
import 'screens/renewals_screen.dart';
import 'screens/safety_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/shell.dart';

/// Every page in the design maps to one route here.
final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
    // Before the vault is open: no navigation bars.
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/setup-lock', builder: (_, _) => const SetLockScreen()),
    GoRoute(path: '/unlock', builder: (_, _) => const UnlockScreen()),

    // After unlock: side bar on wide windows, bottom bar on phones.
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/papers', builder: (_, _) => const PapersScreen()),
        GoRoute(
          path: '/papers/:id',
          builder: (_, s) =>
              PaperDetailScreen(paperId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/papers/:id/changed',
          builder: (_, s) => ChangedScreen(paperId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/add', builder: (_, _) => const AddSourceScreen()),
        GoRoute(path: '/add/check', builder: (_, _) => const AddCheckScreen()),
        GoRoute(path: '/add/saved', builder: (_, _) => const AddSavedScreen()),
        GoRoute(
          path: '/check-file',
          builder: (_, _) => const CheckFileScreen(),
        ),
        GoRoute(path: '/audit', builder: (_, _) => const AuditScreen()),
        GoRoute(path: '/audit/fix', builder: (_, _) => const FixStepsScreen()),
        GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
        GoRoute(path: '/locations', builder: (_, _) => const LocationsScreen()),
        GoRoute(path: '/devices', builder: (_, _) => const DevicesScreen()),
        GoRoute(path: '/devices/pair', builder: (_, _) => const PairScreen()),
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(path: '/renewals', builder: (_, _) => const RenewalsScreen()),
        GoRoute(path: '/safety', builder: (_, _) => const SafetyScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/places',
          builder: (_, _) => const WatchedPlacesScreen(),
        ),
        GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      ],
    ),
  ],
);
