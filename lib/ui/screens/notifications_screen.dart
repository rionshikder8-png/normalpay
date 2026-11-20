import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/nav_state.dart';
import '../widgets/common.dart';
import 'transaction_detail.dart';

/// Notification inbox: live payment alerts, verification results and device
/// events, newest first and grouped by day.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _typeIcon(NotifType t) => switch (t) {
        NotifType.paymentReceived => Icons.payments_rounded,
        NotifType.paymentVerified => Icons.verified_rounded,
        NotifType.unmatched => Icons.help_outline_rounded,
        NotifType.duplicate => Icons.copy_all_rounded,
        NotifType.readerDisconnected => Icons.phonelink_erase_rounded,
        NotifType.readerReconnected => Icons.phonelink_ring_rounded,
        NotifType.serverLost => Icons.cloud_off_rounded,
        NotifType.serverRestored => Icons.cloud_done_rounded,
        NotifType.other => Icons.notifications_none_rounded,
      };

  Color _typeColor(NotifType t) => switch (t) {
        NotifType.paymentReceived || NotifType.paymentVerified => ApsColors.success,
        NotifType.unmatched || NotifType.duplicate => ApsColors.warn,
        NotifType.serverLost || NotifType.readerDisconnected => ApsColors.danger,
        _ => ApsColors.primary,
      };

  Future<void> _confirmClear(BuildContext context, AppState appState) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notification history?'),
        content: const Text(
          'This removes all alerts stored on this phone. New alerts will still arrive. '
          'Nothing on the APS server is deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear', style: TextStyle(color: ApsColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) appState.clearNotifications();
  }

  void _open(BuildContext context, AppState appState, NotifItem n) {
    appState.markRead(n.id);
    final tx = appState.findTx(n.txRef ?? n.trxId);
    if (tx != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TransactionDetailScreen(tx: tx)),
      );
    } else {
      shellTab.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final unread = appState.unreadCount;
            final items = List<NotifItem>.from(appState.notifications)
              ..sort((a, b) => b.at.compareTo(a.at));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      const Text('Notifications', style: ApsText.title),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ApsColors.infoBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ApsColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (unread > 0)
                        TextButton(
                          onPressed: appState.markAllRead,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: ApsColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert_rounded, size: 20, color: ApsColors.muted),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'clear') _confirmClear(context, appState);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'clear',
                            child: Text('Clear history'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (!appState.notifPermission && appState.prefs.push) ...[
                        ApsCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: ApsColors.warnBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notifications_off_rounded, size: 18, color: ApsColors.warn),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Notifications are blocked', style: ApsText.bodyBold),
                                    SizedBox(height: 2),
                                    Text(
                                      'Android is not showing APS alerts. Allow notifications to receive live payment alerts.',
                                      style: ApsText.caption,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  await appState.push.requestPermission();
                                  await appState.refreshPermissions();
                                },
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: ApsColors.warn,
                                ),
                                child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (appState.fcmServerState == ApiState.notAvailable) ...[
                        ApsCard(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: ApsColors.muted),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Push delivery needs the APS server FCM update. Local alerts still work while the app can sync.',
                                  style: ApsText.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (items.isEmpty)
                        const EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications yet',
                          message: 'Live payment alerts will appear here.',
                        )
                      else
                        ..._grouped(context, appState, items),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, AppState appState, List<NotifItem> items) {
    final groups = <String, List<NotifItem>>{};
    for (final n in items) {
      groups.putIfAbsent(dayGroup(n.at), () => <NotifItem>[]).add(n);
    }
    final out = <Widget>[];
    groups.forEach((label, rows) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Text(
            label,
            style: ApsText.bodyBold.copyWith(
              fontSize: 12.5,
              color: const Color(0xFF1F3A5F),
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
      out.add(
        ApsCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _NotifTile(
                  item: rows[i],
                  typeIcon: _typeIcon(rows[i].type),
                  typeColor: _typeColor(rows[i].type),
                  onTap: () => _open(context, appState, rows[i]),
                ),
              ],
            ],
          ),
        ),
      );
    });
    return out;
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.item,
    required this.typeIcon,
    required this.typeColor,
    required this.onTap,
  });

  final NotifItem item;
  final IconData typeIcon;
  final Color typeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.gateway != null)
              GatewayLogo(item.gateway, size: 38)
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, size: 19, color: typeColor),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6, top: 1),
                          decoration: const BoxDecoration(color: ApsColors.primary, shape: BoxShape.circle),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: unread
                              ? ApsText.bodyBold.copyWith(fontSize: 13.5)
                              : ApsText.body.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ApsText.caption,
                    ),
                  ],
                  if (item.amount != null || item.trxId != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        if (item.amount != null)
                          Text(
                            taka(item.amount!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ApsColors.success,
                            ),
                          ),
                        if (item.trxId != null)
                          Text(
                            'TrxID ${item.trxId}',
                            style: ApsText.caption,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(shortTime(item.at), style: ApsText.caption),
          ],
        ),
      ),
    );
  }
}
