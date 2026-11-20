import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/nav_state.dart';
import 'dashboard_screen.dart';
import 'gateways_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

/// Logged-in container: 5 screens in an [IndexedStack] plus a custom bottom bar
/// (active tab = rounded pill with icon + label, inactive = icon only).
class Shell extends StatelessWidget {
  const Shell({super.key});

  static const List<_TabSpec> _tabs = [
    _TabSpec('Dashboard', Icons.dashboard_rounded),
    _TabSpec('Transactions', Icons.receipt_long_rounded),
    _TabSpec('Notifications', Icons.notifications_rounded),
    _TabSpec('Gateways', Icons.account_balance_wallet_rounded),
    _TabSpec('Settings', Icons.settings_rounded),
  ];

  static const int _notificationsIndex = 2;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final banner = _banners(app);

    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: Column(
        children: [
          if (banner != null) SafeArea(bottom: false, child: banner),
          Expanded(
            // The banner already consumed the top inset, so screens must not add it again.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: banner != null,
              child: ValueListenableBuilder<int>(
                valueListenable: shellTab,
                builder: (context, index, _) => IndexedStack(
                  index: _safeIndex(index),
                  children: const [
                    DashboardScreen(),
                    TransactionsScreen(),
                    NotificationsScreen(),
                    GatewaysScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(app),
    );
  }

  static int _safeIndex(int raw) {
    if (raw < 0) return 0;
    if (raw >= _tabs.length) return _tabs.length - 1;
    return raw;
  }

  Widget? _banners(AppState app) {
    final revoked = app.revoked == true;
    final offline = !app.online;
    if (!revoked && !offline) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (revoked)
          _Banner(
            background: ApsColors.dangerBg,
            foreground: ApsColors.danger,
            icon: Icons.gpp_bad_rounded,
            message: 'This device was revoked or its credentials are invalid. Reconnect it from Settings.',
            actionLabel: 'Disconnect',
            onAction: () => app.logout(),
          ),
        if (offline)
          _Banner(
            background: ApsColors.warnBg,
            foreground: ApsColors.warn,
            icon: Icons.wifi_off_rounded,
            message: 'No internet. Payments are queued safely and will sync automatically.',
          ),
      ],
    );
  }

  Widget _bottomBar(AppState app) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ApsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: ValueListenableBuilder<int>(
            valueListenable: shellTab,
            builder: (context, index, _) {
              final active = _safeIndex(index);
              return Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    if (i == active)
                      Expanded(
                        child: _ActiveTab(
                          spec: _tabs[i],
                          badge: i == _notificationsIndex ? app.unreadCount : 0,
                        ),
                      )
                    else
                      _InactiveTab(
                        spec: _tabs[i],
                        badge: i == _notificationsIndex ? app.unreadCount : 0,
                        onTap: () => shellTab.value = i,
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({required this.spec, required this.badge});
  final _TabSpec spec;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ApsColors.infoBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconWithBadge(
              icon: spec.icon,
              color: ApsColors.primary,
              badge: badge,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ApsColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveTab extends StatelessWidget {
  const _InactiveTab({required this.spec, required this.badge, required this.onTap});
  final _TabSpec spec;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          child: Center(
            child: _IconWithBadge(
              icon: spec.icon,
              color: ApsColors.muted,
              badge: badge,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab icon with an optional unread-count badge (red, "9+" when above 9).
class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({required this.icon, required this.color, required this.badge});
  final IconData icon;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: color);
    if (badge <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          top: -7,
          right: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ApsColors.danger,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slim full-width notice used for revoked credentials and offline state.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: foreground),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
