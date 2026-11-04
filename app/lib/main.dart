import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/pin_lock.dart';
import 'data/sync_service.dart';
import 'data/vault.dart';
import 'data/vault_cipher.dart';
import 'router.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadPin();
  // Needed because Add opens PDFs directly, without a pdfrx viewer widget.
  pdfrxFlutterInitialize();
  runApp(const DocuveilApp());
  unawaited(_openVault());
}

/// Read the PIN record before the router decides where to start.
Future<void> _loadPin() async {
  try {
    await PinLock.load(SecurePinStore());
    SyncService.instance = SyncService(store: SecurePinStore());
    await SyncService.instance.load();
  } catch (e) {
    debugPrint('Secure storage not available: $e');
  }
}

/// Attach the on-device SQLite vault. The app already runs on the demo papers,
/// so a failure here is logged instead of blocking start-up.
Future<void> _openVault() async {
  if (kIsWeb) return;
  try {
    final desktop = const {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
    if (desktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    final store = await SqliteVaultStore.open(
      SqliteVaultStore.pathIn(dir.path),
      cipher: await VaultCipher.loadOrCreate(SecurePinStore()),
    );
    await Vault.attach(store);
  } catch (e) {
    debugPrint('Vault database not available: $e');
  }
}

class DocuveilApp extends StatelessWidget {
  const DocuveilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppState.textScale,
      builder: (context, scale, _) {
        return MaterialApp.router(
          title: 'Docuveil',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: appRouter,
          builder: (context, child) {
            // Honour the person's own text size on top of the system setting.
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  media.textScaler.scale(1) * scale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
