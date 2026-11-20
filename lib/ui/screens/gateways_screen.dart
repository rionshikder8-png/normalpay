import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'gateway_detail.dart';

/// Gateways: one compact card per SMS gateway showing reader link state,
/// configuration state, parser readiness, last SMS and (when the server provides
/// them) totals. Monitoring can be toggled per gateway.
class GatewaysScreen extends StatelessWidget {
  const GatewaysScreen({super.key});

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text('Gateways', style: ApsText.title),
              const SizedBox(height: 2),
              const Text('SMS-based payment detection', style: ApsText.caption),
              const SizedBox(height: 14),
              for (final id in GatewayId.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GatewayCard(
                    id: id,
                    appState: appState,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({required this.id, required this.appState});

  final GatewayId id;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final stats = appState.gateways[id] ?? GatewayStats(id: id);
    final configured = appState.session == SessionState.loggedIn;
    final enabled = appState.gatewayEnabled[id] ?? stats.monitoringEnabled;
    final amount = stats.totalAmount;
    final lastSms = stats.lastSmsAt;

    return ApsCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GatewayDetailScreen(id)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GatewayLogo(id),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  id.label,
                  style: ApsText.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusPill.link(appState.linkFor(id)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: ApsColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          _Row(
            label: 'Configuration Status',
            child: _ValueText(configured ? 'Configured' : 'Not Configured'),
          ),
          const Divider(height: 1),
          _Row(
            label: 'SMS Parser',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill('Ready', fg: ApsColors.success, bg: ApsColors.successBg),
                SizedBox(height: 3),
                Text(
                  'Conservative incoming-payment parser',
                  textAlign: TextAlign.end,
                  style: ApsText.caption,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _Row(
            label: 'Last Received SMS',
            child: _ValueText(lastSms == null ? 'None yet' : relative(lastSms)),
          ),
          const Divider(height: 1),
          _Row(
            label: 'Total Transactions',
            child: _ValueText(stats.totalTransactions?.toString() ?? '—'),
          ),
          const Divider(height: 1),
          _Row(
            label: 'Total Received Amount',
            child: _ValueText(amount == null ? '—' : taka(amount)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Expanded(child: Text('Enable monitoring', style: ApsText.body)),
                Switch(
                  value: enabled,
                  onChanged: (v) => appState.setGatewayEnabled(id, v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: ApsText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Flexible(flex: 5, child: Align(alignment: Alignment.centerRight, child: child)),
        ],
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.end,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ApsColors.ink),
    );
  }
}
