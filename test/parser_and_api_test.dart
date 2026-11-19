import 'package:aps_reader/core/models.dart';
import 'package:aps_reader/data/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('request signing', () {
    test('sha256Hex matches known vector', () {
      expect(ApsApi.sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('signature is deterministic and canonical-string based', () {
      final a = ApsApi.sign('secret', 'post', '/api/x', 1000, 'nonce', '{}');
      final b = ApsApi.sign('secret', 'POST', '/api/x', 1000, 'nonce', '{}');
      expect(a, b);
      expect(a.length, 64);
      expect(ApsApi.sign('secret', 'POST', '/api/x', 1001, 'nonce', '{}'), isNot(a));
      expect(ApsApi.sign('secret', 'POST', '/api/x', 1000, 'nonce', '{"a":1}'), isNot(a));
    });

    test('nonce is 48 hex chars and unique', () {
      final n1 = ApsApi.nonce();
      final n2 = ApsApi.nonce();
      expect(n1.length, 48);
      expect(RegExp(r'^[0-9a-f]{48}$').hasMatch(n1), isTrue);
      expect(n1, isNot(n2));
    });
  });

  group('base url', () {
    test('accepts https origin', () {
      expect(ApsApi.normalizeBaseUrl('https://aps.adverune.store/'), 'https://aps.adverune.store');
    });
    test('rejects http, query and credentials', () {
      expect(() => ApsApi.normalizeBaseUrl('http://aps.adverune.store'), throwsFormatException);
      expect(() => ApsApi.normalizeBaseUrl('https://aps.adverune.store/?a=1'), throwsFormatException);
      expect(() => ApsApi.normalizeBaseUrl('https://user:pw@aps.adverune.store'), throwsFormatException);
    });
  });

  group('models', () {
    test('TxItem parses backend json and hides missing fields', () {
      final t = TxItem.fromJson({'id': '7', 'provider': 'bkash', 'amount': '2500.50', 'provider_trx_id': 'AB12CD34', 'status': 'verified'});
      expect(t.gateway, GatewayId.bkash);
      expect(t.amount, 2500.5);
      expect(t.status, TxStatus.verified);
      expect(t.senderNumber, isNull);
      expect(t.apsReference, isNull);
    });
    test('status parsing', () {
      expect(parseTxStatus('matched'), TxStatus.verified);
      expect(parseTxStatus('review'), TxStatus.pending);
      expect(parseTxStatus('weird'), TxStatus.unknown);
    });
    test('notification type parsing', () {
      expect(parseNotifType('payment_received'), NotifType.paymentReceived);
      expect(parseNotifType('server_connection_restored'), NotifType.serverRestored);
      expect(parseNotifType(null), NotifType.other);
    });
    test('NotifItem json round trip', () {
      final n = NotifItem(id: 'e1', type: NotifType.paymentReceived, title: 'New Payment Received', body: 'b', gateway: GatewayId.nagad, amount: 100, trxId: 'T1', at: DateTime(2026, 11, 19, 10));
      final r = NotifItem.fromJson(n.toJson());
      expect(r.id, 'e1');
      expect(r.gateway, GatewayId.nagad);
      expect(r.read, isFalse);
      expect(r.copyWith(read: true).read, isTrue);
    });
  });

  test('friendly errors', () {
    expect(friendlyApiError('invalid_or_expired_code'), contains('invalid or expired'));
    expect(friendlyApiError('zzz'), contains('zzz'));
  });
}
