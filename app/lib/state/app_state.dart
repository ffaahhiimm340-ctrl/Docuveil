import 'package:flutter/foundation.dart';

/// App-wide settings that every screen reads. Kept tiny on purpose until the
/// local encrypted database exists; then these move into stored settings.
class AppState {
  AppState._();

  /// Text size multiplier: 0.9 small, 1.0 normal (default), 1.25 large.
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static const small = 0.9;
  static const normal = 1.0;
  static const large = 1.25;
}
