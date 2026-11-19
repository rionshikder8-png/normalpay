import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/nav_state.dart';
import '../widgets/common.dart';
import 'gateway_detail.dart';
import 'transaction_detail.dart';

/// Dashboard: compact overview of payments, per-gateway SMS statistics, the most
/// recent payments and the real device/reader health from the native layer.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Scaffold(
        backgroundColor: ApsColors.bg,
        body: RefreshIndicator(
          color: ApsColors.primary,
          onRefresh: () => appState.refreshAll(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Header(reachable: appState.serverReachable),
              const SectionHeader('Payment Overview'),
              _OverviewGrid(overview: appState.overview),
              if (appState.statsState == ApiState.notAvailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 2, right: 2),
                  child: Text(
                    'Live totals need the APS server stats endpoint. Not available yet.',
                    style: ApsText.caption,
                  ),
                ),
              const SectionHeader('Gateway Statistics'),
              _GatewayStatsCard(appState: appState),
              SectionHeader(
                'Recent Payments',
                action: 'See all',
                onAction: () {
                  shellTab.value = 1;
                },
              ),
              _RecentPayments(appState: appState),
              const SectionHeader('Device Health'),
              _DeviceHealth(appState: appState),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.reachable});

  final bool reachable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Image.asset('assets/images/aps_mark_transparent.png', height: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('APS Reader', style: ApsText.title),
                SizedBox(height: 1),
                Text('Powered by Adverune', style: ApsText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: reachable ? 'Server connected' : 'Server unreachable',
            child: _Dot(reachable ? ApsColors.success : ApsColors.danger, size: 10),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ payment overview

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.overview});

  final Map<String, dynamic>? overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Payments',
                  value: _countValue(overview, 'total_payments'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: "Today's Payments",
                  value: _countValue(overview, 'today_payments'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Received Amount',
                  value: _moneyValue(overview, 'total_amount'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Pending Transactions',
                  value: _countValue(overview, 'pending'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ApsCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: ApsText.caption, maxLines: 2),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ApsColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _countValue(Map<String, dynamic>? overview, String key) {
  final raw = overview?[key];
  if (raw == null) return '—';
  final n = raw is num ? raw : num.tryParse(raw.toString());
  if (n == null) return '—';
  return n.toInt().toString();
}

String _moneyValue(Map<String, dynamic>? overview, String key) {
  final raw = overview?[key];
  if (raw == null) return '—';
  final n = raw is num ? raw : num.tryParse(raw.toString());
  if (n == null) return '—';
  return taka(n);
}

// ----------------------------------------------------------- gateway statistics

class _GatewayStatsCard extends StatelessWidget {
  const _GatewayStatsCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final ids = GatewayId.values;
    return ApsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < ids.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _GatewayBlock(
              stats: appState.gateways[ids[i]] ?? GatewayStats(id: ids[i]),
              link: appState.linkFor(ids[i]),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GatewayDetailScreen(ids[i]),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GatewayBlock extends StatelessWidget {
  const _GatewayBlock({required this.stats, required this.link, required this.onTap});

  final GatewayStats stats;
  final GatewayLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = stats.totalAmount;
    final lastTx = stats.lastTransactionAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                GatewayLogo(stats.id),
                const SizedBox(width: 10),
                Expanded(child: Text(stats.id.label, style: ApsText.bodyBold)),
                const SizedBox(width: 8),
                StatusPill.link(link),
                const Icon(Icons.chevron_right_rounded, size: 18, color: ApsColors.muted),
              ],
            ),
          ),
        ),
        _kvRow('Transactions', stats.totalTransactions?.toString() ?? '—'),
        _kvRow('Total Amount', amount == null ? '—' : taka(amount)),
        _kvRow('Last Transaction', lastTx == null ? 'None yet' : relative(lastTx)),
        _kvRowWidget('SMS Detection', _smsDetectionPill(stats)),
        const SizedBox(height: 6),
      ],
    );
  }
}

StatusPill _smsDetectionPill(GatewayStats stats) {
  if (!stats.monitoringEnabled) {
    return const StatusPill('Off', fg: ApsColors.muted, bg: Color(0xFFF2F4F7));
  }
  if (stats.smsDetectionActive) {
    return const StatusPill('Active', fg: ApsColors.success, bg: ApsColors.successBg);
  }
  return const StatusPill('Inactive', fg: ApsColors.warn, bg: ApsColors.warnBg);
}

// ------------------------------------------------------------ recent payments

class _RecentPayments extends StatelessWidget {
  const _RecentPayments({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    if (appState.txState == ApiState.notAvailable) {
      return const ApsCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Transactions are not available yet',
          message:
              'The APS server has no transaction feed for the Reader yet. SMS payments are still detected and uploaded.',
        ),
      );
    }
    if (appState.txState != ApiState.ok) {
      return const ApsCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load payments',
          message:
              'Pull down to refresh. Payments detected from SMS stay queued safely on this phone.',
        ),
      );
    }
    final items = appState.transactions.take(8).toList();
    if (items.isEmpty) {
      return const ApsCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No payments yet',
          message: 'Payments detected from SMS will appear here.',
        ),
      );
    }
    return ApsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RecentTile(tx: items[i]),
          ],
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.tx});

  final TxItem tx;

  @override
  Widget build(BuildContext context) {
    final trxId = tx.providerTrxId;
    return Row(
      children: [
        Expanded(
          child: TxTile(
            tx,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TransactionDetailScreen(tx),
                ),
              );
            },
          ),
        ),
        if (trxId != null)
          IconButton(
            onPressed: () => copyToClipboard(context, trxId, label: 'Transaction ID copied'),
            icon: const Icon(Icons.copy_rounded),
            iconSize: 16,
            color: ApsColors.muted,
            tooltip: 'Copy transaction ID',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- device health

class _DeviceHealth extends StatelessWidget {
  const _DeviceHealth({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final health = appState.health;
    final lastSync = health.lastSyncOkAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(health.lastSyncOkAtMs)
        : null;
    final lastSms = health.lastSmsAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(health.lastSmsAtMs)
        : null;
    final running = appState.smsPermission && appState.prefs.backgroundMonitoring;
    final serverLabel = appState.serverLabel;
    final serverText = appState.serverReachable
        ? (serverLabel == null || serverLabel.isEmpty ? 'Connected' : 'Connected · $serverLabel')
        : 'Unreachable';
    final readerText = running ? 'Running' : (appState.smsPermission ? 'Paused' : 'Needs permission');

    final rows = <Widget>[
      _InfoRow(
        label: 'Reader Status',
        value: readerText,
        color: running ? ApsColors.success : ApsColors.warn,
      ),
      _InfoRow(
        label: 'Internet',
        value: appState.online ? 'Online' : 'Offline',
        color: appState.online ? ApsColors.success : ApsColors.danger,
      ),
      _InfoRow(
        label: 'Server Connection',
        value: serverText,
        color: appState.serverReachable ? ApsColors.success : ApsColors.danger,
      ),
      _InfoRow(label: 'Last Successful Sync', value: relative(lastSync)),
      _InfoRow(label: 'Last SMS Received', value: relative(lastSms)),
      _InfoRow(
        label: 'Pending Uploads',
        value: health.pending == 0 ? 'All uploaded' : '${health.pending} queued',
        color: health.pending == 0 ? ApsColors.success : ApsColors.warn,
        trailing: health.pending == 0
            ? null
            : const StatusPill('Queued', fg: ApsColors.warn, bg: ApsColors.warnBg),
      ),
      _InfoRow(
        label: 'Background Monitoring',
        value: appState.batteryUnrestricted ? 'Unrestricted' : 'Battery optimized (may delay)',
        color: appState.batteryUnrestricted ? ApsColors.success : ApsColors.warn,
      ),
      _InfoRow(
        label: 'SMS Permission',
        value: appState.smsPermission ? 'Granted' : 'Missing',
        color: appState.smsPermission ? ApsColors.success : ApsColors.danger,
        trailing: appState.smsPermission ? null : _AllowButton(onPressed: appState.requestSmsPermission),
      ),
    ];

    return ApsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.color, this.trailing});

  final String label;
  final String value;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _Dot(color ?? ApsColors.muted),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(label, style: ApsText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ApsColors.ink,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AllowButton extends StatelessWidget {
  const _AllowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ApsColors.primary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: const Text('Allow'),
    );
  }
}

// ------------------------------------------------------------------- primitives

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Widget _kvRow(String label, String value) => _kvRowWidget(
      label,
      Text(
        value,
        textAlign: TextAlign.end,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ApsColors.ink),
      ),
    );

Widget _kvRowWidget(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: ApsText.label)),
          const SizedBox(width: 10),
          value,
        ],
      ),
    );
