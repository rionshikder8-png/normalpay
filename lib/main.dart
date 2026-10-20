import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NormalPayReaderApp());

const _channel = MethodChannel('com.normalpay.smsreader/device');
const _blue = Color(0xFF365FE8);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);

class NormalPayReaderApp extends StatelessWidget {
  const NormalPayReaderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Normal Pay SMS Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F8FC),
          colorScheme: ColorScheme.fromSeed(
              seedColor: _blue, brightness: Brightness.light),
          fontFamily: 'Roboto',
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
        home: const ReaderHome(),
      );
}

class ReaderHome extends StatefulWidget {
  const ReaderHome({super.key});
  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> {
  final _url = TextEditingController(text: 'https://abctour.live');
  final _code = TextEditingController();
  
  bool _busy = false;
  bool _english = true;
  bool _paired = false;
  bool _permission = false;
  int _deviceId = 0;
  int _pending = 0;
  String _status = 'Not connected';
  String _message = 'Connect this phone to a device created in your Normal Pay dashboard.';
  String _server = 'https://abctour.live';

  // SMS Reader ভেরিয়েবল
  final _smsQuery = SmsQuery();
  Timer? _smsTimer;
  String _lastSmsId = "";

  String t(String en, String bn) => _english ? en : bn;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _startSmsListener();
  }

  @override
  void dispose() {
    _smsTimer?.cancel();
    _url.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final c = await _channel.invokeMapMethod<String, dynamic>('loadConfig');
      if (c != null && (c['deviceId'] as int? ?? 0) > 0) {
        setState(() {
          _paired = true;
          _deviceId = c['deviceId'] as int;
          _server = c['baseUrl'] as String? ?? 'https://abctour.live';
          _url.text = _server;
          _status = 'Paired';
          _message = 'Device credentials are stored securely on this phone.';
        });
        await _refreshPending();
        await _checkPermission();
      }
    } catch (_) {}
  }

  Future<void> _checkPermission() async {
    final s = await Permission.sms.status;
    if (mounted) setState(() => _permission = s.isGranted);
  }

  // SMS রিসিভ এবং সার্ভারে পাঠানোর ফাংশন
  Future<void> _startSmsListener() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return;

    _smsTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_paired) return;

      try {
        final messages = await _smsQuery.querySms(kinds: [SmsQueryKind.inbox], count: 1);
        if (messages.isNotEmpty) {
          final latestMsg = messages.first;
          final msgId = latestMsg.id.toString();
          
          if (msgId != _lastSmsId) {
            _lastSmsId = msgId;
            final body = latestMsg.body ?? "";
            final sender = latestMsg.address ?? "";

            // চেক করা এটা bKash না Nagad
            var provider = "";
            if (body.contains("TrxID") || body.toLowerCase().contains("bkash")) provider = "bkash";
            if (body.contains("TxnID") || body.toLowerCase().contains("nagad")) provider = "nagad";

            if (provider.isNotEmpty && (body.contains("received") || body.contains("Amount"))) {
              await _sendToServer(provider, body);
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _sendToServer(String provider, String smsBody) async {
    try {
      final response = await http.post(
        Uri.parse('https://abctour.live/api/sms-webhook.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'provider': provider,
          'sms_body': smsBody,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          if (mounted) {
            setState(() {
              _message = 'অটোমেটিক ভেরিফাই হয়েছে: TrxID ${data['transaction'] ?? ''}';
            });
          }
        }
      }
    } catch (_) {}
  }

  String _normalBaseUrl(String raw) {
    final u = Uri.parse(raw.trim());
    if (u.scheme != 'https' || u.host.isEmpty || u.userInfo.isNotEmpty || u.hasQuery || u.hasFragment) {
      throw const FormatException('Enter a valid HTTPS site URL, for example https://abctour.live');
    }
    return '${u.scheme}://${u.authority}';
  }

  Future<void> _pair() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final base = _normalBaseUrl(_url.text);
      final code = _code.text.trim().toUpperCase();
      if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
        throw const FormatException('Enter the 8-character code shown in Dashboard → SMS Reader.');
      }
      final uid = 'android-${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      final response = await http.post(
        Uri.parse('$base/api/device-register.php'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'pair_code': code,
          'device_uid': uid,
          'device_model': 'Android phone',
          'app_version': '1.0.0',
        }),
      ).timeout(const Duration(seconds: 20));
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300 || data['ok'] != true) {
        throw Exception(_apiError(data['error']?.toString() ?? 'pair_failed'));
      }
      
      await _channel.invokeMethod('saveConfig', {
        'baseUrl': base,
        'deviceId': data['device_id'],
        'deviceSecret': data['device_secret'],
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('deviceId', data['device_id']);

      setState(() {
        _paired = true;
        _deviceId = data['device_id'] as int;
        _server = base;
        _url.text = base;
        _code.clear();
        _status = 'Paired';
        _message = 'Device paired. Now allow SMS permission to read new payment notifications.';
      });
      await _requestPermission();
      await _ping();
    } catch (e) {
      setState(() {
        _status = 'Needs attention';
        _message = _cleanError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _apiError(String e) => switch (e) {
        'invalid_or_expired_code' => 'Pairing code is invalid or expired. Generate a fresh code in your dashboard.',
        'merchant_inactive' => 'This merchant account is not active.',
        'rate_limited' => 'Too many attempts. Wait a little and try again.',
        'subscription_required' => 'Your merchant plan does not currently allow SMS Reader sync.',
        _ => 'Server rejected the request ($e). Check the site URL and try again.',
      };

  String _cleanError(Object e) => e is FormatException ? e.message : e.toString().replaceFirst('Exception: ', '');

  Future<void> _requestPermission() async {
    final s = await Permission.sms.request();
    if (!mounted) return;
    setState(() {
      _permission = s.isGranted;
      _message = s.isGranted
          ? 'SMS permission granted. Only new payment-like SMS from supported wallets will be queued.'
          : 'SMS permission was not granted. The reader cannot detect incoming SMS until permission is allowed in Android Settings.';
    });
    if (s.isGranted) await _refreshPending();
  }

  String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  String _sign(String secret, String method, String path, int ts, String nonce, String body) {
    final payload = '${method.toUpperCase()}\n$path\n$ts\n$nonce\n${_sha256(body)}';
    return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).toString();
  }

  String _nonce() => List<int>.generate(24, (_) => Random.secure().nextInt(256)).map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  Future<Map<String, dynamic>> _signedRequest(String path, {String method = 'POST', String body = ''}) async {
    final c = await _channel.invokeMapMethod<String, dynamic>('loadConfig');
    if (c == null) throw Exception('Device is not paired.');
    final id = c['deviceId'] as int;
    final secret = c['deviceSecret'] as String;
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final nonce = _nonce();
    final sig = _sign(secret, method, path, ts, nonce, body);
    final request = http.Request(method, Uri.parse('${c['baseUrl']}$path'));
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': '$id',
      'X-Timestamp': '$ts',
      'X-Nonce': nonce,
      'X-Signature': sig,
    });
    request.body = body;
    final client = http.Client();
    try {
      final streamed = await client.send(request).timeout(const Duration(seconds: 25));
      final textBody = await streamed.stream.bytesToString();
      Map<String, dynamic> json;
      try {
        json = jsonDecode(textBody) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Server returned an unexpected response (HTTP ${streamed.statusCode}).');
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300 || json['ok'] != true) {
        throw Exception(_apiError(json['error']?.toString() ?? 'http_${streamed.statusCode}'));
      }
      return json;
    } finally {
      client.close();
    }
  }

  Future<void> _ping() async {
    if (!_paired) return;
    setState(() => _busy = true);
    try {
      final data = await _signedRequest('/api/device-ping.php');
      setState(() {
        _status = 'Connected';
        _message = 'Connected securely to ${data['label'] ?? 'Normal Pay'} (device #${data['device_id']}).';
      });
    } catch (e) {
      setState(() {
        _status = 'Offline / Error';
        _message = _cleanError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (!_paired || _busy) return;
    setState(() {
      _busy = true;
      _message = 'Checking the connection and syncing queued notifications…';
    });
    try {
      await _channel.invokeMethod('syncNow');
      await _ping();
      await _refreshPending();
      if (mounted) {
        setState(() {
          _message = 'Sync requested. The Android background worker will upload queued payment notifications when the network is available.';
        });
      }
    } catch (e) {
      setState(() => _message = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPending() async {
    try {
      final n = await _channel.invokeMethod<int>('pendingCount') ?? 0;
      if (mounted) setState(() => _pending = n);
    } catch (_) {}
  }

  Future<void> _disconnect() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Disconnect this device?', 'ডিভাইস বিচ্ছিন্ন করবেন?')),
        content: Text(t('This clears credentials from this phone. Also revoke the device in the Normal Pay dashboard to disable it on the server.', 'এতে ফোনের credentials মুছে যাবে। সার্ভারেও বন্ধ করতে Normal Pay Dashboard থেকে device revoke করুন।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel', 'বাতিল'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Disconnect', 'বিচ্ছিন্ন করুন'))),
        ],
      ),
    );
    if (yes != true) return;
    await _channel.invokeMethod('clearConfig');
    if (mounted) {
      setState(() {
        _paired = false;
        _deviceId = 0;
        _pending = 0;
        _status = 'Not connected';
        _message = 'Credentials removed from this phone. Revoke the device in your dashboard as well.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final good = _status == 'Connected';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Normal Pay', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('SMS Reader', style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _english = !_english),
            child: Text(_english ? 'বাংলা' : 'English', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            // -------- HERO CARD --------
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF345FE8), Color(0xFF5146D9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _blue.withOpacity(.18), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 18),
                  Text(t('Private payment notification sync', 'নিরাপদ পেমেন্ট নোটিফিকেশন সিঙ্ক'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text(t('Connect an authorized merchant device to your Normal Pay account.', 'অনুমোদিত merchant ফোনটি Normal Pay account-এর সঙ্গে যুক্ত করুন।'), style: TextStyle(color: Colors.white.withOpacity(.86), height: 1.45)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(good ? Icons.check_circle : Icons.circle, color: good ? const Color(0xFF9BF2C5) : Colors.white70, size: 13),
                      const SizedBox(width: 7),
                      Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_paired) Text('Device #$_deviceId', style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // -------- CONNECT CARD --------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.link_rounded, title: t('Connect to Normal Pay', 'Normal Pay-এর সঙ্গে যুক্ত করুন')),
                  const SizedBox(height: 7),
                  Text(t('First create a device in Dashboard → SMS Reader. Use the one-time code shown there.', 'প্রথমে Dashboard → SMS Reader থেকে device তৈরি করুন। সেখানে দেখানো একবার ব্যবহারযোগ্য code দিন।'), style: const TextStyle(color: _muted, height: 1.45, fontSize: 13)),
                  const SizedBox(height: 17),
                  Text(t('Main website URL', 'মূল ওয়েবসাইট URL'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _url,
                    enabled: !_paired && !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.language_rounded), hintText: 'https://abctour.live'),
                  ),
                  const SizedBox(height: 14),
                  Text(t('One-time pairing code', 'একবার ব্যবহারযোগ্য pairing code'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _code,
                    enabled: !_paired && !_busy,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    autocorrect: false,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.key_rounded), hintText: 'ABCD2345', counterText: ''),
                    style: const TextStyle(fontSize: 19, letterSpacing: 3, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 15),
                  if (!_paired)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _pair,
                        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.phonelink_lock_rounded),
                        label: Text(t('Pair device securely', 'নিরাপদে ডিভাইস যুক্ত করুন')),
                        style: FilledButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _ping, icon: const Icon(Icons.wifi_tethering_rounded), label: Text(t('Test connection', 'সংযোগ পরীক্ষা')))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton.icon(onPressed: _busy ? null : _syncNow, icon: const Icon(Icons.sync_rounded), label: Text(t('Sync now', 'এখন সিঙ্ক')))),
                      ],
                    ),
                  if (_paired)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _disconnect,
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          label: Text(t('Disconnect this phone', 'এই ফোন বিচ্ছিন্ন করুন'), style: const TextStyle(color: Color(0xFFB42318))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------- PERMISSION CARD --------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.security_rounded, title: t('Reader permissions', 'রিডার অনুমতি')),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.sms_outlined,
                    t('Incoming SMS permission', 'ইনকামিং SMS অনুমতি'),
                    _permission ? t('Allowed', 'অনুমোদিত') : t('Not allowed', 'অনুমতি দেওয়া হয়নি'),
                    _permission ? const Color(0xFF027A48) : const Color(0xFFB54708),
                  ),
                  const SizedBox(height: 12),
                  if (!_permission)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(t('Allow SMS permission', 'SMS অনুমতি দিন')),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(t('The app does not scan your existing inbox. It only handles new incoming SMS that look like supported wallet payment notifications, excludes common OTP/PIN messages, and uploads only parsed payment-like messages.', 'অ্যাপটি পুরোনো inbox স্ক্যান করে না। নতুন incoming SMS-এর মধ্যে supported wallet payment notification-এর মতো বার্তা বেছে নেয়, সাধারণ OTP/PIN বার্তা বাদ দেয় এবং কেবল payment-এর মতো বার্তাই আপলোড করে।'), style: const TextStyle(color: _muted, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------- SYNC CARD --------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.cloud_sync_rounded, title: t('Sync overview', 'সিঙ্কের অবস্থা')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _metric(t('Queued locally', 'কিউতে আছে'), '$_pending', Icons.pending_actions_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _metric(t('Supported wallets', 'সমর্থিত ওয়ালেট'), '4', Icons.account_balance_wallet_rounded)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(13)),
                    child: Text(_message, style: const TextStyle(color: _muted, fontSize: 13, height: 1.45)),
                  ),
                  const SizedBox(height: 10),
                  const Text('bKash  •  Nagad  •  Upay  •  Rocket', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text('Normal Pay • Private merchant build • v1.0.0', style: TextStyle(color: Color(0xFF98A2B3), fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFECEFF4)),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 18, offset: Offset(0, 5))],
        ),
        child: child,
      );

  Widget _metric(String title, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _blue, size: 20),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 23)),
            Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String title, String value, Color color) => Row(
        children: [
          Icon(icon, color: _blue, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 13))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: _blue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15))),
        ],
      );
}
