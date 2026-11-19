import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';

class RefEntry {
  final String ref;
  final DateTime at;
  final String? linkedTx;
  final bool serverConfirmed;
  const RefEntry(this.ref, this.at, {this.linkedTx, this.serverConfirmed = false});
  Map<String, dynamic> toJson() => {'ref': ref, 'at': at.toIso8601String(), 'tx': linkedTx, 'srv': serverConfirmed};
  factory RefEntry.fromJson(Map<String, dynamic> j) =>
      RefEntry(j['ref'].toString(), DateTime.parse(j['at'].toString()), linkedTx: j['tx']?.toString(), serverConfirmed: j['srv'] == true);
}

class Prefs {
  final bool push;
  final bool paymentAlerts;
  final bool verificationAlerts;
  final bool deviceAlerts;
  final bool sound;
  final bool vibration;
  final bool autoSync;
  final bool backgroundMonitoring;
  const Prefs({
    this.push = true,
    this.paymentAlerts = true,
    this.verificationAlerts = true,
    this.deviceAlerts = true,
    this.sound = true,
    this.vibration = true,
    this.autoSync = true,
    this.backgroundMonitoring = true,
  });
  Prefs copyWith({bool? push, bool? paymentAlerts, bool? verificationAlerts, bool? deviceAlerts, bool? sound, bool? vibration, bool? autoSync, bool? backgroundMonitoring}) => Prefs(
        push: push ?? this.push,
        paymentAlerts: paymentAlerts ?? this.paymentAlerts,
        verificationAlerts: verificationAlerts ?? this.verificationAlerts,
        deviceAlerts: deviceAlerts ?? this.deviceAlerts,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        autoSync: autoSync ?? this.autoSync,
        backgroundMonitoring: backgroundMonitoring ?? this.backgroundMonitoring,
      );
}

/// Non-secret app data only (settings, notification inbox cache, reference-ID history).
/// Credentials and the SMS queue live in native encrypted storage, never here.
class LocalStore {
  static const _kNotifs = 'notif_inbox_v1';
  static const _kRefs = 'ref_history_v1';
  static const _kRefSeq = 'ref_seq_v1';
  static const _kFcm = 'fcm_token_v1';
  static const _kFcmSynced = 'fcm_synced_v1';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<Prefs> loadPrefs() async {
    final p = await _p;
    return Prefs(
      push: p.getBool('p_push') ?? true,
      paymentAlerts: p.getBool('p_pay') ?? true,
      verificationAlerts: p.getBool('p_ver') ?? true,
      deviceAlerts: p.getBool('p_dev') ?? true,
      sound: p.getBool('p_snd') ?? true,
      vibration: p.getBool('p_vib') ?? true,
      autoSync: p.getBool('p_sync') ?? true,
      backgroundMonitoring: p.getBool('p_bg') ?? true,
    );
  }

  Future<void> savePrefs(Prefs v) async {
    final p = await _p;
    await p.setBool('p_push', v.push);
    await p.setBool('p_pay', v.paymentAlerts);
    await p.setBool('p_ver', v.verificationAlerts);
    await p.setBool('p_dev', v.deviceAlerts);
    await p.setBool('p_snd', v.sound);
    await p.setBool('p_vib', v.vibration);
    await p.setBool('p_sync', v.autoSync);
    await p.setBool('p_bg', v.backgroundMonitoring);
  }

  Future<List<NotifItem>> loadNotifs() async {
    final p = await _p;
    final raw = p.getString(_kNotifs);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => NotifItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifs(List<NotifItem> items) async {
    final p = await _p;
    final trimmed = items.take(200).toList();
    await p.setString(_kNotifs, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<List<RefEntry>> loadRefs() async {
    final p = await _p;
    final raw = p.getString(_kRefs);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => RefEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRefs(List<RefEntry> items) async {
    final p = await _p;
    await p.setString(_kRefs, jsonEncode(items.take(200).map((e) => e.toJson()).toList()));
  }

  /// Per-day local sequence. NOT globally unique: the backend must issue persistent IDs.
  Future<int> nextRefSeq(String day) async {
    final p = await _p;
    final stored = p.getString('${_kRefSeq}_day');
    var n = stored == day ? (p.getInt(_kRefSeq) ?? 0) : 0;
    n += 1;
    await p.setString('${_kRefSeq}_day', day);
    await p.setInt(_kRefSeq, n);
    return n;
  }

  Future<String?> fcmToken() async => (await _p).getString(_kFcm);
  Future<void> setFcmToken(String? t) async {
    final p = await _p;
    if (t == null) {
      await p.remove(_kFcm);
    } else {
      await p.setString(_kFcm, t);
    }
  }

  Future<bool> fcmSynced() async => (await _p).getBool(_kFcmSynced) ?? false;
  Future<void> setFcmSynced(bool v) async => (await _p).setBool(_kFcmSynced, v);

  Future<void> clearSessionData() async {
    final p = await _p;
    for (final k in [_kNotifs, _kFcm, _kFcmSynced]) {
      await p.remove(k);
    }
  }
}
