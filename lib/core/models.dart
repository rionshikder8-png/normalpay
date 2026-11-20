enum GatewayId { bkash, nagad, rocket, upay }

/// Gateways the Reader actually monitors. Owner decision: only official bKash and Nagad SMS are read.
/// Rocket and Upay stay in the enum only so server data for them still parses; add them here to enable.
const List<GatewayId> supportedGateways = [GatewayId.bkash, GatewayId.nagad];

extension GatewayIdX on GatewayId {
  String get key => name;
  String get label => switch (this) {
        GatewayId.bkash => 'bKash',
        GatewayId.nagad => 'Nagad',
        GatewayId.rocket => 'Rocket',
        GatewayId.upay => 'Upay',
      };
  static GatewayId? parse(String? v) {
    final s = (v ?? '').toLowerCase();
    for (final g in GatewayId.values) {
      if (g.key == s) return g;
    }
    return null;
  }
}

/// SMS reader / monitoring state for one gateway. Derived from real local data
/// (last SMS seen/queued/uploaded) and, when available, server stats.
enum GatewayLink { connected, disconnected, notConfigured }

class GatewayStats {
  final GatewayId id;
  final bool monitoringEnabled;
  final int? totalTransactions; // null = unknown (server stats unavailable)
  final double? totalAmount;
  final DateTime? lastTransactionAt;
  final DateTime? lastSmsAt;
  final bool smsDetectionActive;
  const GatewayStats({
    required this.id,
    this.monitoringEnabled = true,
    this.totalTransactions,
    this.totalAmount,
    this.lastTransactionAt,
    this.lastSmsAt,
    this.smsDetectionActive = false,
  });
}

enum TxStatus { verified, pending, unmatched, duplicate, unknown }

TxStatus parseTxStatus(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'verified':
    case 'matched':
    case 'paid':
    case 'completed':
      return TxStatus.verified;
    case 'pending':
    case 'review':
      return TxStatus.pending;
    case 'unmatched':
      return TxStatus.unmatched;
    case 'duplicate':
      return TxStatus.duplicate;
    default:
      return TxStatus.unknown;
  }
}

class TxItem {
  final String id;
  final GatewayId? gateway;
  final double amount;
  final String? providerTrxId;
  final String? senderNumber;
  final String? apsReference;
  final DateTime? smsReceivedAt;
  final DateTime? verifiedAt;
  final TxStatus status;
  final String? matchInfo;
  const TxItem({
    required this.id,
    this.gateway,
    required this.amount,
    this.providerTrxId,
    this.senderNumber,
    this.apsReference,
    this.smsReceivedAt,
    this.verifiedAt,
    this.status = TxStatus.unknown,
    this.matchInfo,
  });

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory TxItem.fromJson(Map<String, dynamic> j) => TxItem(
        id: (j['id'] ?? j['provider_trx_id'] ?? j['trx_id'] ?? '').toString(),
        gateway: GatewayIdX.parse(j['provider']?.toString() ?? j['gateway']?.toString()),
        amount: double.tryParse((j['amount'] ?? 0).toString()) ?? 0,
        providerTrxId: (j['provider_trx_id'] ?? j['trx_id'])?.toString(),
        senderNumber: (j['sender'] ?? j['sender_number'])?.toString(),
        apsReference: (j['aps_reference'] ?? j['reference'])?.toString(),
        smsReceivedAt: _dt(j['sms_received_at'] ?? j['received_at']),
        verifiedAt: _dt(j['verified_at']),
        status: parseTxStatus(j['status']?.toString()),
        matchInfo: j['match_info']?.toString(),
      );
}

enum NotifType {
  paymentReceived,
  paymentVerified,
  unmatched,
  duplicate,
  readerDisconnected,
  readerReconnected,
  serverLost,
  serverRestored,
  other,
}

NotifType parseNotifType(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'payment_received':
    case 'new_payment':
      return NotifType.paymentReceived;
    case 'payment_verified':
      return NotifType.paymentVerified;
    case 'unmatched_transaction':
    case 'unmatched':
      return NotifType.unmatched;
    case 'duplicate_sms':
    case 'duplicate':
      return NotifType.duplicate;
    case 'reader_disconnected':
      return NotifType.readerDisconnected;
    case 'reader_reconnected':
      return NotifType.readerReconnected;
    case 'server_connection_lost':
      return NotifType.serverLost;
    case 'server_connection_restored':
      return NotifType.serverRestored;
    default:
      return NotifType.other;
  }
}

class NotifItem {
  final String id; // stable id used for de-duplication
  final NotifType type;
  final String title;
  final String body;
  final GatewayId? gateway;
  final double? amount;
  final String? trxId;
  final String? txRef;
  final DateTime at;
  final bool read;
  const NotifItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.gateway,
    this.amount,
    this.trxId,
    this.txRef,
    required this.at,
    this.read = false,
  });

  NotifItem copyWith({bool? read}) => NotifItem(
        id: id,
        type: type,
        title: title,
        body: body,
        gateway: gateway,
        amount: amount,
        trxId: trxId,
        txRef: txRef,
        at: at,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'gateway': gateway?.key,
        'amount': amount,
        'trxId': trxId,
        'txRef': txRef,
        'at': at.toIso8601String(),
        'read': read,
      };

  factory NotifItem.fromJson(Map<String, dynamic> j) => NotifItem(
        id: j['id'].toString(),
        type: NotifType.values.firstWhere((t) => t.name == j['type'], orElse: () => NotifType.other),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        gateway: GatewayIdX.parse(j['gateway']?.toString()),
        amount: j['amount'] == null ? null : double.tryParse(j['amount'].toString()),
        trxId: j['trxId']?.toString(),
        txRef: j['txRef']?.toString(),
        at: DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.now(),
        read: j['read'] == true,
      );
}

/// Result of a backend call that may hit an endpoint that does not exist yet.
enum ApiState { ok, notAvailable, unauthorized, offline, error }

class ApiResult<T> {
  final ApiState state;
  final T? data;
  final String? message;
  const ApiResult(this.state, {this.data, this.message});
  bool get ok => state == ApiState.ok;
}
