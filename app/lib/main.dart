import 'package:flutter/material.dart';

import 'router.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const DocuveilApp());
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
