import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../state/app_scope.dart';
import '../widgets/common.dart';

/// Detail view for one SMS gateway: what the Reader detects, which sender IDs are
/// recognised, and exactly what is uploaded. Deliberately makes no claims about
/// provider APIs — the Reader only ever reads SMS.
class GatewayDetailScreen extends StatelessWidget {
  const GatewayDetailScreen(this.id, {super.key});

  final GatewayId id;

  /// Known sender short codes used to recognise payment SMS for each gateway.
  static const Map<GatewayId, String> senderIds = {
    GatewayId.bkash: '16247',
    GatewayId.nagad: '16167',
    GatewayId.upay: '16268',
    GatewayId.rocket: '16216',
  };

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final stats = appState.gateways[id] ?? GatewayStats(id: id);
        final enabled = appState.gatewayEnabled[id] ?? stats.monitoringEnabled;
        final lastSms = stats.lastSmsAt;
        final amount = stats.totalAmount;
        final senderId = senderIds[id] ?? '—';

        return Scaffold(
          backgroundColor: ApsColors.bg,
          appBar: AppBar(
            title: Text(id.label, style: ApsText.title),
            centerTitle: false,
            titleSpacing: 0,
          ),
          body: RefreshIndicator(
            color: ApsColors.primary,
            onRefresh: () => appState.refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _HeaderCard(
                  id: id,
                  link: appState.linkFor(id),
                  enabled: enabled,
                ),
                const SectionHeader('Monitoring'),
                ApsCard(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable monitoring', style: ApsText.bodyBold),
                            SizedBox(height: 2),
                            Text(
                              'When off, SMS from this gateway is ignored by the reader.',
                              style: ApsText.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: enabled,
                        onChanged: (v) {
                          appState.setGatewayEnabled(id, v);
                        },
                      ),
                    ],
                  ),
                ),
                const SectionHeader('SMS Detection'),
                ApsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Detection', style: ApsText.bodyBold)),
                          StatusPill(
                            stats.smsDetectionActive ? 'Active' : 'Inactive',
                            fg: stats.smsDetectionActive ? ApsColors.success : ApsColors.warn,
                            bg: stats.smsDetectionActive ? ApsColors.successBg : ApsColors.warnBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Known sender IDs', style: ApsText.label),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _SenderChip(senderId),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Only incoming messages from this sender that look like a payment '
                        '(an amount plus a transaction ID) are treated as payments.',
                        style: ApsText.caption,
                      ),
                    ],
                  ),
                ),
                const SectionHeader('What is uploaded'),
                const ApsCard(
                  child: Text(
                    'Only payment-like incoming SMS (amount + transaction ID) is uploaded. '
                    'OTP/PIN messages, promotional messages, failed transactions and outgoing '
                    'messages are never uploaded.',
                    style: ApsText.body,
                  ),
                ),
                const SectionHeader('Last SMS'),
                ApsCard(
                  child: _Row(
                    label: 'Last received',
                    value: lastSms == null ? 'None yet' : relative(lastSms),
                  ),
                ),
                const SectionHeader('Totals'),
                ApsCard(
                  child: Column(
                    children: [
                      _Row(
                        label: 'Total Transactions',
                        value: stats.totalTransactions?.toString() ?? '—',
                      ),
                      const Divider(height: 1),
                      _Row(
                        label: 'Total Received Amount',
                        value: amount == null ? '—' : taka(amount),
                      ),
                      if (amount == null) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Totals need the APS server stats endpoint. Not available yet.',
                            style: ApsText.caption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.id, required this.link, required this.enabled});

  final GatewayId id;
  final GatewayLink link;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ApsCard(
      child: Row(
        children: [
          GatewayLogo(id, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id.label, style: ApsText.section),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Monitoring enabled' : 'Monitoring disabled',
                  style: ApsText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill.link(link),
        ],
      ),
    );
  }
}

class _SenderChip extends StatelessWidget {
  const _SenderChip(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ApsColors.infoBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: ApsColors.primaryDark,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ApsColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
