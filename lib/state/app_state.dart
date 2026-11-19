import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../data/api.dart';
import '../data/local_store.dart';
import '../data/native_bridge.dart';
import '../data/push_service.dart';

enum SessionState { loading, loggedOut, loggedIn }

class DeviceInfoView {
  final String name;
  final String androidVersion;
  final String appVersion;
  const DeviceInfoView(this.name, this.androidVersion, this.appVersion);
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({NativeBridge? bridge, LocalStore? store, PushService? push, ApsApi? api})
      : bridge = bridge ?? NativeBridge(),
        store = store ?? LocalStore(),
        push = push ?? PushService() {
    this.api = api ?? ApsApi(this.bridge);
  }

  final NativeBridge bridge;
  final LocalStore store;
  final PushService push;
  late final ApsApi api;

  SessionState session = SessionState.loading;
  DeviceConfig? config;
  Prefs prefs = const Prefs();
  DeviceInfoView deviceInfo = const DeviceInfoView('Android device', '', ApsConfig.appVersionFallback);

  // health
  NativeHealth health = const NativeHealth();
  bool online = true;
  bool serverReachable = false;
  bool smsPermission = false;
  bool notifPermission = false;
  bool batteryUnrestricted = false;
  bool? revoked;
  String? serverLabel;
  DateTime? lastPingOk;

  // data
  Map<GatewayId, bool> gatewayEnabled = {for (final g in GatewayId.values) g: true};
  Map<GatewayId, GatewayStats> gateways = {};
  ApiState statsState = ApiState.notAvailable;
  Map<String, dynamic>? overview; // total_payments, today_payments, total_amount, pending
  List<TxItem> transactions = [];
  ApiState txState = ApiState.notAvailable;
  bool txLoading = false;
  bool txHasMore = false;
  int _txPage = 1;
  List<NotifItem> notifications = [];
  List<RefEntry> references = [];
  String? lastError;
  bool refreshing = false;

  /// Set by a notification tap; the shell listens and opens the transaction.
  final ValueNotifier<Map<String, dynamic>?> pendingDeepLink = ValueNotifier(null);

  StreamSubscription? _conn, _tap, _inc, _tok;
  Timer? _tick;
  bool _disposed = false;

  int get unreadCount => notifications.where((n) => !n.read).length;

  // ---------------------------------------------------------------- lifecycle
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    prefs = await store.loadPrefs();
    notifications = await store.loadNotifs();
    references = await store.loadRefs();
    await _loadDeviceInfo();
    await push.init();
    _tap = push.taps.listen((d) => pendingDeepLink.value = d);
    _inc = push.incoming.listen(_onIncoming);
    _tok = push.tokenChanges.listen((t) => _syncToken(t));
    config = await bridge.loadConfig();
    session = config == null ? SessionState.loggedOut : SessionState.loggedIn;
    notifyListeners();
    _conn = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    final c = await Connectivity().checkConnectivity();
    online = !c.contains(ConnectivityResult.none);
    if (session == SessionState.loggedIn) await onSignedIn(initial: true);
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      final pkg = await PackageInfo.fromPlatform();
      deviceInfo = DeviceInfoView('${a.manufacturer} ${a.model}'.trim(), 'Android ${a.version.release} (SDK ${a.version.sdkInt})', pkg.version);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && session == SessionState.loggedIn) {
      refreshAll(silent: true);
    }
  }

  Future<void> onSignedIn({bool initial = false}) async {
    config = await bridge.loadConfig();
    gatewayEnabled = {for (final e in (await bridge.gatewayEnabled()).entries) if (GatewayIdX.parse(e.key) != null) GatewayIdX.parse(e.key)!: e.value};
    for (final g in GatewayId.values) {
      gatewayEnabled.putIfAbsent(g, () => true);
    }
    await refreshAll(silent: initial);
    if (prefs.push) {
      notifPermission = await push.requestPermission();
      final t = await push.token();
      if (t != null) await _syncToken(t);
    }
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(minutes: 2), (_) {
      if (session == SessionState.loggedIn) _refreshHealthOnly();
    });
  }

  // ---------------------------------------------------------------- pairing
  Future<String?> pair({required String baseUrl, required String code}) async {
    try {
      final info = deviceInfo;
      await api.pair(baseUrl: baseUrl, code: code, model: info.name, version: info.appVersion);
      session = SessionState.loggedIn;
      await requestSmsPermission();
      notifyListeners();
      await onSignedIn();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } on ApiException catch (e) {
      return e.message;
    } on TimeoutException {
      return 'The server did not respond in time. Check your connection and try again.';
    } catch (_) {
      return 'Could not reach the server. Check your connection and the server URL.';
    }
  }

  Future<void> logout() async {
    final token = await store.fcmToken();
    if (token != null) {
      // Best effort: tell the server to stop sending to this phone, then drop the local token.
      await api.registerFcmToken(token, remove: true);
    }
    await push.deleteToken();
    await bridge.clearConfig();
    await store.clearSessionData();
    _tick?.cancel();
    config = null;
    session = SessionState.loggedOut;
    transactions = [];
    notifications = [];
    overview = null;
    gateways = {};
    health = const NativeHealth();
    serverReachable = false;
    lastPingOk = null;
    revoked = null;
    notifyListeners();
  }

  /// Called when the server reports 401/403: the device was revoked or credentials are invalid.
  Future<void> _handleRevoked() async {
    revoked = true;
    serverReachable = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- permissions
  Future<void> refreshPermissions() async {
    smsPermission = (await Permission.sms.status).isGranted;
    notifPermission = (await Permission.notification.status).isGranted;
    batteryUnrestricted = await bridge.isIgnoringBatteryOptimizations();
  }

  Future<void> requestSmsPermission() async {
    final s = await Permission.sms.request();
    smsPermission = s.isGranted;
    notifyListeners();
  }

  // ---------------------------------------------------------------- refresh
  Future<void> refreshAll({bool silent = false}) async {
    if (session != SessionState.loggedIn || refreshing) return;
    refreshing = true;
    if (!silent) notifyListeners();
    try {
      await refreshPermissions();
      await _refreshHealthOnly(notify: false);
      await Future.wait([_loadStats(), loadTransactions(reset: true), _loadServerNotifications()]);
      _buildGateways();
    } finally {
      refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshHealthOnly({bool notify = true}) async {
    health = await bridge.health();
    final wasUp = serverReachable;
    final r = await api.ping();
    if (r.ok) {
      serverReachable = true;
      lastPingOk = DateTime.now();
      serverLabel = r.data?['label']?.toString();
      revoked = false;
      if (!wasUp && lastPingOk != null && _everLost) {
        _everLost = false;
        _localAlert(NotifType.serverRestored, 'Server Connection Restored', 'APS Reader is connected to the server again.');
      }
    } else if (r.state == ApiState.unauthorized) {
      await _handleRevoked();
    } else {
      serverReachable = false;
      if (wasUp && online) {
        _everLost = true;
        _localAlert(NotifType.serverLost, 'Server Connection Lost', 'APS Reader cannot reach the server. Payments will queue and sync automatically.');
      }
    }
    if (notify && !_disposed) notifyListeners();
  }

  bool _everLost = false;

  Future<void> _loadStats() async {
    final r = await api.stats();
    statsState = r.state;
    if (r.ok) {
      overview = r.data;
    }
  }

  void _buildGateways() {
    final srv = <String, dynamic>{};
    final list = overview?['gateways'];
    if (list is List) {
      for (final e in list) {
        if (e is Map && e['provider'] != null) srv[e['provider'].toString()] = e;
      }
    }
    final next = <GatewayId, GatewayStats>{};
    for (final g in GatewayId.values) {
      final s = srv[g.key] as Map?;
      final lastSmsMs = health.lastSmsByProvider[g.key] ?? 0;
      next[g] = GatewayStats(
        id: g,
        monitoringEnabled: gatewayEnabled[g] ?? true,
        totalTransactions: s == null ? null : int.tryParse('${s['total_transactions'] ?? s['count'] ?? ''}'),
        totalAmount: s == null ? null : double.tryParse('${s['total_amount'] ?? ''}'),
        lastTransactionAt: s == null ? null : DateTime.tryParse('${s['last_transaction_at'] ?? ''}')?.toLocal(),
        lastSmsAt: lastSmsMs > 0 ? DateTime.fromMillisecondsSinceEpoch(lastSmsMs) : null,
        smsDetectionActive: (gatewayEnabled[g] ?? true) && smsPermission,
      );
    }
    gateways = next;
  }

  /// Link state is about SMS reader connectivity, not gateway availability.
  GatewayLink linkFor(GatewayId g) {
    if (session != SessionState.loggedIn) return GatewayLink.notConfigured;
    if (!(gatewayEnabled[g] ?? true)) return GatewayLink.disconnected;
    if (!smsPermission) return GatewayLink.disconnected;
    return serverReachable ? GatewayLink.connected : GatewayLink.disconnected;
  }

  // ---------------------------------------------------------------- transactions
  Future<void> loadTransactions({bool reset = false, Map<String, String>? filters}) async {
    if (txLoading) return;
    txLoading = true;
    if (reset) _txPage = 1;
    notifyListeners();
    final r = await api.transactions(page: _txPage, filters: filters);
    txState = r.state;
    if (r.ok) {
      final rows = (r.data?['items'] ?? r.data?['transactions'] ?? []) as List;
      final parsed = rows.whereType<Map>().map((e) => TxItem.fromJson(Map<String, dynamic>.from(e))).toList();
      if (reset) transactions = [];
      final seen = transactions.map((t) => t.id).toSet();
      transactions = [...transactions, ...parsed.where((t) => seen.add(t.id))];
      txHasMore = r.data?['has_more'] == true;
      _txPage += 1;
    }
    txLoading = false;
    if (!_disposed) notifyListeners();
  }

  TxItem? findTx(String? idOrTrx) {
    if (idOrTrx == null || idOrTrx.isEmpty) return null;
    for (final t in transactions) {
      if (t.id == idOrTrx || t.providerTrxId == idOrTrx) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------- notifications
  Future<void> _loadServerNotifications() async {
    final r = await api.notifications();
    if (!r.ok) return;
    final rows = (r.data?['items'] ?? r.data?['notifications'] ?? []) as List;
    var changed = false;
    final have = notifications.map((n) => n.id).toSet();
    for (final e in rows.whereType<Map>()) {
      final m = Map<String, dynamic>.from(e);
      final item = PushService.itemFromMessage(m, m['id']?.toString(), title: m['title']?.toString(), body: m['body']?.toString());
      if (item != null && have.add(item.id)) {
        notifications.add(m['read'] == true ? item.copyWith(read: true) : item);
        changed = true;
      }
    }
    if (changed) _sortAndSaveNotifs();
  }

  void _sortAndSaveNotifs() {
    notifications.sort((a, b) => b.at.compareTo(a.at));
    store.saveNotifs(notifications);
  }

  void _onIncoming(NotifItem item) {
    if (notifications.any((n) => n.id == item.id)) return; // de-dup
    if (!_allowed(item.type)) return;
    notifications.insert(0, item);
    _sortAndSaveNotifs();
    notifyListeners();
    if (item.type == NotifType.paymentReceived || item.type == NotifType.paymentVerified) {
      refreshAll(silent: true);
    }
  }

  bool _allowed(NotifType t) {
    if (!prefs.push) return false;
    return switch (t) {
      NotifType.paymentReceived => prefs.paymentAlerts,
      NotifType.paymentVerified || NotifType.unmatched || NotifType.duplicate => prefs.verificationAlerts,
      _ => prefs.deviceAlerts,
    };
  }

  Future<void> _localAlert(NotifType type, String title, String body) async {
    if (!_allowed(type)) return;
    final item = NotifItem(id: '${type.name}-${DateTime.now().millisecondsSinceEpoch ~/ 60000}', type: type, title: title, body: body, at: DateTime.now());
    if (notifications.any((n) => n.id == item.id)) return;
    notifications.insert(0, item);
    _sortAndSaveNotifs();
    await push.showLocalAlert(item);
  }

  void markRead(String id) {
    final i = notifications.indexWhere((n) => n.id == id);
    if (i < 0 || notifications[i].read) return;
    notifications[i] = notifications[i].copyWith(read: true);
    store.saveNotifs(notifications);
    notifyListeners();
  }

  void markAllRead() {
    notifications = notifications.map((n) => n.copyWith(read: true)).toList();
    store.saveNotifs(notifications);
    notifyListeners();
  }

  void clearNotifications() {
    notifications = [];
    store.saveNotifs(notifications);
    notifyListeners();
  }

  // ---------------------------------------------------------------- FCM token
  Future<void> _syncToken(String token) async {
    final prev = await store.fcmToken();
    await store.setFcmToken(token);
    if (session != SessionState.loggedIn) return;
    if (prev == token && await store.fcmSynced()) return;
    final r = await api.registerFcmToken(token);
    final ok = r.ok;
    await store.setFcmSynced(ok);
    fcmServerState = r.state;
    if (!_disposed) notifyListeners();
  }

  ApiState fcmServerState = ApiState.notAvailable;

  Future<void> retryTokenSync() async {
    final t = await push.token();
    if (t != null) {
      await store.setFcmSynced(false);
      await _syncToken(t);
    }
  }

  // ---------------------------------------------------------------- settings
  Future<void> updatePrefs(Prefs p) async {
    final pushTurnedOn = !prefs.push && p.push;
    prefs = p;
    await store.savePrefs(p);
    notifyListeners();
    if (pushTurnedOn) {
      notifPermission = await push.requestPermission();
      await retryTokenSync();
      notifyListeners();
    }
    if (!p.autoSync) {
      // Auto sync off: stop periodic uploads; queued items remain safe until manual sync.
    }
  }

  Future<void> setGatewayEnabled(GatewayId g, bool v) async {
    gatewayEnabled[g] = v;
    await bridge.setGatewayEnabled(g.key, v);
    _buildGateways();
    notifyListeners();
  }

  Future<void> syncNow() async {
    await bridge.syncNow();
    await Future.delayed(const Duration(seconds: 3));
    await _refreshHealthOnly();
    await refreshAll(silent: true);
  }

  // ---------------------------------------------------------------- reference IDs
  /// Returns a new reference. If the backend endpoint exists it is persisted and globally unique;
  /// otherwise a clearly-labelled LOCAL reference is produced (never a provider transaction ID).
  Future<RefEntry> generateReference({String? linkTx}) async {
    final r = await api.createReference(linkTx: linkTx);
    final now = DateTime.now();
    RefEntry entry;
    final serverRef = r.ok ? (r.data?['reference'] ?? r.data?['aps_reference'])?.toString() : null;
    if (serverRef != null && serverRef.isNotEmpty) {
      entry = RefEntry(serverRef, now, linkedTx: linkTx, serverConfirmed: true);
    } else {
      final day = DateFormat('yyyyMMdd').format(now);
      String ref;
      do {
        final seq = await store.nextRefSeq(day);
        ref = 'APS-$day-${seq.toString().padLeft(6, '0')}';
      } while (references.any((e) => e.ref == ref));
      entry = RefEntry(ref, now, linkedTx: linkTx);
    }
    references.insert(0, entry);
    await store.saveRefs(references);
    notifyListeners();
    return entry;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _conn?.cancel();
    _tap?.cancel();
    _inc?.cancel();
    _tok?.cancel();
    _tick?.cancel();
    push.dispose();
    super.dispose();
  }

  void _onConnectivity(List<ConnectivityResult> r) {
    final nowOnline = !r.contains(ConnectivityResult.none);
    final was = online;
    online = nowOnline;
    if (!was && nowOnline && session == SessionState.loggedIn) {
      // Back online: flush the offline queue and re-check the server.
      bridge.syncNow();
      _refreshHealthOnly();
    }
    notifyListeners();
  }
}
