import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/models.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

const _channelPayments = AndroidNotificationChannel(
  'aps_payments',
  'Payment alerts',
  description: 'New payments detected by APS Reader',
  importance: Importance.high,
);
const _channelVerify = AndroidNotificationChannel(
  'aps_verification',
  'Verification alerts',
  description: 'Payment verification, unmatched and duplicate events',
  importance: Importance.high,
);
const _channelDevice = AndroidNotificationChannel(
  'aps_device',
  'Device alerts',
  description: 'Reader and server connection status',
  importance: Importance.defaultImportance,
);

String channelFor(NotifType t) => switch (t) {
      NotifType.paymentReceived => _channelPayments.id,
      NotifType.paymentVerified || NotifType.unmatched || NotifType.duplicate => _channelVerify.id,
      _ => _channelDevice.id,
    };

/// Background isolate entry point. Data-only messages are turned into a local notification here;
/// messages that carry a `notification` block are already shown by the Android system tray.
@pragma('vm:entry-point')
Future<void> apsFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (message.notification != null) return; // system tray displays it
  await PushService.showLocalFromData(message.data, message.messageId);
}

class PushService {
  PushService();
  final _taps = StreamController<Map<String, dynamic>>.broadcast();
  final _incoming = StreamController<NotifItem>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  bool _ready = false;
  bool get ready => _ready;

  /// Notification tapped (foreground, background or cold start). Payload: {type, tx, trx_id}.
  Stream<Map<String, dynamic>> get taps => _taps.stream;
  Stream<NotifItem> get incoming => _incoming.stream;
  Stream<String> get tokenChanges => _tokens.stream;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(apsFirebaseBackgroundHandler);

    const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p == null || p.isEmpty) return;
        try {
          _taps.add(jsonDecode(p) as Map<String, dynamic>);
        } catch (_) {}
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channelPayments);
    await android?.createNotificationChannel(_channelVerify);
    await android?.createNotificationChannel(_channelDevice);

    FirebaseMessaging.onMessage.listen((m) async {
      final item = itemFromMessage(m.data, m.messageId, title: m.notification?.title, body: m.notification?.body);
      if (item != null) _incoming.add(item);
      // Foreground: FCM does not draw a tray notification, so show one locally.
      await showLocalFromData(m.data, m.messageId, title: m.notification?.title, body: m.notification?.body);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(Map<String, dynamic>.from(m.data)));
    FirebaseMessaging.instance.onTokenRefresh.listen(_tokens.add);

    final launch = await _local.getNotificationAppLaunchDetails();
    final lp = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && lp != null && lp.isNotEmpty) {
      try {
        _taps.add(jsonDecode(lp) as Map<String, dynamic>);
      } catch (_) {}
    }
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _taps.add(Map<String, dynamic>.from(initial.data));
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final s = await FirebaseMessaging.instance.requestPermission();
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> token() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteToken() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static NotifItem? itemFromMessage(Map<String, dynamic> d, String? messageId, {String? title, String? body}) {
    final type = parseNotifType(d['type']?.toString());
    final t = title ?? d['title']?.toString() ?? '';
    final b = body ?? d['body']?.toString() ?? '';
    if (t.isEmpty && b.isEmpty) return null;
    final id = (d['event_id'] ?? d['notification_id'] ?? messageId ?? '${type.name}-${d['trx_id'] ?? DateTime.now().microsecondsSinceEpoch}').toString();
    return NotifItem(
      id: id,
      type: type,
      title: t,
      body: b,
      gateway: GatewayIdX.parse(d['gateway']?.toString() ?? d['provider']?.toString()),
      amount: d['amount'] == null ? null : double.tryParse(d['amount'].toString()),
      trxId: d['trx_id']?.toString(),
      txRef: d['tx']?.toString(),
      at: DateTime.tryParse((d['at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
    );
  }

  static Future<void> showLocalFromData(Map<String, dynamic> d, String? messageId, {String? title, String? body}) async {
    final item = itemFromMessage(d, messageId, title: title, body: body);
    if (item == null) return;
    final ch = channelFor(item.type);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        ch,
        ch == _channelPayments.id ? _channelPayments.name : (ch == _channelVerify.id ? _channelVerify.name : _channelDevice.name),
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(item.body),
      ),
    );
    // Stable id => the same event can never show twice.
    await _local.show(item.id.hashCode & 0x7fffffff, item.title, item.body, details,
        payload: jsonEncode({'type': d['type'], 'tx': d['tx'], 'trx_id': d['trx_id'], 'id': item.id}));
  }

  Future<void> showLocalAlert(NotifItem item) =>
      showLocalFromData({'type': _typeKey(item.type), 'trx_id': item.trxId, 'tx': item.txRef, 'event_id': item.id}, item.id, title: item.title, body: item.body);

  static String _typeKey(NotifType t) => switch (t) {
        NotifType.paymentReceived => 'payment_received',
        NotifType.paymentVerified => 'payment_verified',
        NotifType.unmatched => 'unmatched_transaction',
        NotifType.duplicate => 'duplicate_sms',
        NotifType.readerDisconnected => 'reader_disconnected',
        NotifType.readerReconnected => 'reader_reconnected',
        NotifType.serverLost => 'server_connection_lost',
        NotifType.serverRestored => 'server_connection_restored',
        NotifType.other => 'other',
      };

  void dispose() {
    _taps.close();
    _incoming.close();
    _tokens.close();
  }
}
