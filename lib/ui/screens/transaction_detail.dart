import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Read-only detail view for one locally known transaction.
///
/// Only fields that actually carry data are rendered — no placeholders or
/// invented values.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.tx});

  final TxItem tx;

  @override
  Widget build(BuildContext context) {
    final providerTrxId = _clean(tx.providerTrxId);
    final apsReference = _clean(tx.apsReference);
    final senderNumber = _clean(tx.senderNumber);
    final matchInfo = _clean(tx.matchInfo);

    return Scaffold(
      backgroundColor: ApsColors.bg,
      appBar: AppBar(title: const Text('Transaction Details')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: ApsColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ApsColors.border),
                ),
                child: Column(
                  children: [
                    GatewayLogo(tx.gateway, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      taka(tx.amount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ApsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx.gateway?.label ?? 'Payment',
                      style: ApsText.label,
                    ),
                    const SizedBox(height: 10),
                    StatusPill.tx(tx.status),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: ApsColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ApsColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    if (tx.gateway != null)
                      _row('Gateway', tx.gateway!.label),
                    _row('Amount', taka(tx.amount)),
                    if (senderNumber != null)
                      _row('Sender Number', senderNumber),
                    if (providerTrxId != null)
                      _copyRow(context, 'Provider Transaction ID', providerTrxId),
                    if (apsReference != null)
                      _copyRow(context, 'APS Reference ID', apsReference),
                    if (tx.smsReceivedAt != null)
                      _row('SMS Received', dateTime(tx.smsReceivedAt!)),
                    if (tx.verifiedAt != null)
                      _row('Backend Verification', dateTime(tx.verifiedAt!)),
                    if (matchInfo != null) _row('Match info', matchInfo),
                  ],
                ),
              ),
              if (providerTrxId != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => copyToClipboard(
                    context,
                    providerTrxId,
                    label: 'Transaction ID copied',
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Transaction ID'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: ApsText.label),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: ApsText.bodyBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: ApsText.label),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: ApsText.bodyBold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => copyToClipboard(context, value),
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: ApsColors.primary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }
}
