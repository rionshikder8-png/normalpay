import 'dart:async';

import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'state/nav_state.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/transaction_detail.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ApsReaderApp());
}

/// App root: owns the single [AppState], exposes it through [AppScope] and
/// routes notification taps to the transaction detail screen.
class ApsReaderApp extends StatefulWidget {
  const ApsReaderApp({super.key});

  @override
  State<ApsReaderApp> createState() => _ApsReaderAppState();
}

class _ApsReaderAppState extends State<ApsReaderApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppState _app;
  SessionState _lastSession = SessionState.loading;
  bool _handlingDeepLink = false;

  @override
  void initState() {
    super.initState();
    _app = AppState();
    _app.addListener(_onStateChanged);
    _app.pendingDeepLink.addListener(_onPendingDeepLink);
    unawaited(_app.init());
  }

  @override
  void dispose() {
    _app.removeListener(_onStateChanged);
    _app.pendingDeepLink.removeListener(_onPendingDeepLink);
    _app.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final session = _app.session;
    if (session != _lastSession) {
      final wasIn = _lastSession == SessionState.loggedIn;
      _lastSession = session;
      if (wasIn && session != SessionState.loggedIn) {
        // Signed out (or revoked + disconnected): drop any pushed detail route.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigatorKey.currentState?.popUntil((r) => r.isFirst);
        });
      }
    }
    if (session == SessionState.loggedIn && _app.pendingDeepLink.value != null) {
      _scheduleDeepLink();
    }
  }

  void _onPendingDeepLink() {
    if (_app.session == SessionState.loggedIn) _scheduleDeepLink();
  }

  /// Defers handling to after the current frame so navigation never happens
  /// while the tree is building.
  void _scheduleDeepLink() {
    if (_handlingDeepLink || _app.pendingDeepLink.value == null) return;
    _handlingDeepLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlingDeepLink = false;
      if (mounted) _handleDeepLink();
    });
  }

  void _handleDeepLink() {
    final payload = _app.pendingDeepLink.value;
    if (payload == null) return;
    // Always consume the payload, even when it cannot be resolved.
    _app.pendingDeepLink.value = null;

    final notifId = payload['id']?.toString();
    if (notifId != null && notifId.isNotEmpty) _app.markRead(notifId);

    if (!mounted || _app.session != SessionState.loggedIn) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final rawId = payload['tx'] ?? payload['trx_id'];
    final tx = _app.findTx(rawId?.toString());
    if (tx != null) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => TransactionDetailScreen(tx: tx)),
      );
    } else {
      // Nothing to open locally: land the user on the transaction list.
      shellTab.value = transactionsTab;
    }
  }

  Widget _home() => switch (_app.session) {
        SessionState.loading => const SplashScreen(),
        SessionState.loggedOut => const LoginScreen(),
        SessionState.loggedIn => const Shell(),
      };

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _app,
      child: ListenableBuilder(
        listenable: _app,
        builder: (context, _) => MaterialApp(
          title: ApsConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: buildApsTheme(),
          navigatorKey: _navigatorKey,
          home: _home(),
        ),
      ),
    );
  }
}
