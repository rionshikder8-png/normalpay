import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Exposes the single [AppState] instance to the widget tree.
///
/// It is an [InheritedNotifier], so every widget that reads it through
/// [AppScope.of] rebuilds automatically when the state changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required super.child})
      : super(notifier: notifier);

  /// Reads the state and registers a dependency: the caller rebuilds on change.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() called with a context that has no AppScope above it.');
    return scope!.notifier!;
  }

  /// Reads the state without registering a dependency (for callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.read() called with a context that has no AppScope above it.');
    return scope!.notifier!;
  }
}
