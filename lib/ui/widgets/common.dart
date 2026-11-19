import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/format.dart';

class ApsCard extends StatelessWidget {
  const ApsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(color: ApsColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: ApsColors.border)),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.fg, required this.bg});
  final String text;
  final Color fg;
  final Color bg;
  factory StatusPill.link(GatewayLink l) => switch (l) {
        GatewayLink.connected => const StatusPill('Connected', fg: ApsColors.success, bg: ApsColors.successBg),
        GatewayLink.disconnected => const StatusPill('Disconnected', fg: ApsColors.danger, bg: ApsColors.dangerBg),
        GatewayLink.notConfigured => const StatusPill('Not Configured', fg: ApsColors.notConnected, bg: ApsColors.notConnectedBg),
      };
  factory StatusPill.tx(TxStatus s) => switch (s) {
        TxStatus.verified => const StatusPill('Verified', fg: ApsColors.success, bg: ApsColors.successBg),
        TxStatus.pending => const StatusPill('Pending', fg: ApsColors.warn, bg: ApsColors.warnBg),
        TxStatus.unmatched => const StatusPill('Unmatched', fg: ApsColors.danger, bg: ApsColors.dangerBg),
        TxStatus.duplicate => const StatusPill('Duplicate', fg: ApsColors.primary, bg: ApsColors.infoBg),
        TxStatus.unknown => const StatusPill('Unknown', fg: ApsColors.muted, bg: Color(0xFFF2F4F7)),
      };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Brand logo for a gateway inside a white circle, using the supplied official logo assets.
class GatewayLogo extends StatelessWidget {
  const GatewayLogo(this.id, {super.key, this.size = 40});
  final GatewayId? id;
  final double size;
  @override
  Widget build(BuildContext context) {
    Widget inner;
    switch (id) {
      case GatewayId.bkash:
        inner = Image.asset('assets/images/bkash.png', fit: BoxFit.contain);
      case GatewayId.nagad:
        inner = Image.asset('assets/images/nagad.png', fit: BoxFit.contain);
      case GatewayId.rocket:
        inner = Image.asset('assets/images/rocket_full.png', fit: BoxFit.contain);
      case GatewayId.upay:
        inner = Image.asset('assets/images/upay.png', fit: BoxFit.contain);
      case null:
        inner = const Icon(Icons.payments_rounded, color: ApsColors.muted, size: 20);
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: ApsColors.border)),
      child: ClipOval(child: inner),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: ApsText.section)),
          if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: const TextStyle(color: ApsColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56, decoration: const BoxDecoration(color: ApsColors.infoBg, shape: BoxShape.circle), child: Icon(icon, color: ApsColors.primary)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: ApsText.bodyBold),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: ApsText.label)],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

void copyToClipboard(BuildContext context, String text, {String label = 'Copied'}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(label), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

class AmountText extends StatelessWidget {
  const AmountText(this.value, {super.key, this.style});
  final num value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text('+${taka(value)}', style: style ?? ApsText.amount);
}

class TxTile extends StatelessWidget {
  const TxTile(this.tx, {super.key, required this.onTap});
  final TxItem tx;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final trx = tx.providerTrxId ?? tx.id;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          GatewayLogo(tx.gateway),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.gateway?.label ?? 'Payment', style: ApsText.bodyBold),
              const SizedBox(height: 2),
              Text('TrxID $trx', maxLines: 1, overflow: TextOverflow.ellipsis, style: ApsText.caption),
              if (tx.senderNumber != null && tx.senderNumber!.isNotEmpty) Text(tx.senderNumber!, style: ApsText.caption),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AmountText(tx.amount),
            const SizedBox(height: 2),
            Text(tx.smsReceivedAt == null ? '' : shortTime(tx.smsReceivedAt!), style: ApsText.caption),
            const SizedBox(height: 4),
            StatusPill.tx(tx.status),
          ]),
        ]),
      ),
    );
  }
}
