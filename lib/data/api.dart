import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/models.dart';
import 'native_bridge.dart';

class PairResult {
  final int deviceId;
  final String secret;
  const PairResult(this.deviceId, this.secret);
}

class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);
  @override
  String toString() => message;
}

String friendlyApiError(String code) => switch (code) {
      'invalid_or_expired_code' => 'Pairing code is invalid or expired. Generate a new one in your dashboard.',
      'merchant_inactive' => 'This merchant account is not active.',
      'rate_limited' => 'Too many attempts. Please wait a moment and try again.',
      'subscription_required' => 'Your plan does not currently allow SMS Reader sync.',
      'device_revoked' || 'revoked' => 'This device was revoked. Pair it again with a new code.',
      _ => 'Server rejected the request ($code).',
    };

class ApsApi {
  ApsApi(this._bridge, {http.Client? client}) : _client = client ?? http.Client();
  final NativeBridge _bridge;
  final http.Client _client;

  static String normalizeBaseUrl(String raw) {
    final u = Uri.parse(raw.trim());
    if (u.scheme != 'https' || u.host.isEmpty || u.userInfo.isNotEmpty || u.hasQuery || u.hasFragment) {
      throw const FormatException('Enter a valid HTTPS server URL, e.g. https://aps.adverune.store');
    }
    return '${u.scheme}://${u.authority}';
  }

  static String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

  static String sign(String secret, String method, String path, int ts, String nonce, String body) {
    final payload = '${method.toUpperCase()}\n$path\n$ts\n$nonce\n${sha256Hex(body)}';
    return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload)).toString();
  }

  static String nonce([Random? r]) {
    final rnd = r ?? Random.secure();
    return List<int>.generate(24, (_) => rnd.nextInt(256)).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<PairResult> pair({required String baseUrl, required String code, required String model, required String version}) async {
    final base = normalizeBaseUrl(baseUrl);
    final c = code.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(c)) {
      throw const ApiException('bad_code', 'Enter the 8-character pairing code from your dashboard.');
    }
    final uid = 'android-${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';
    final res = await _client
        .post(Uri.parse('$base${ApsConfig.registerPath}'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'pair_code': c, 'device_uid': uid, 'device_model': model, 'app_version': version}))
        .timeout(const Duration(seconds: 20));
    final data = _decode(res.body, res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      final code = data['error']?.toString() ?? 'pair_failed';
      throw ApiException(code, friendlyApiError(code));
    }
    final id = (data['device_id'] as num).toInt();
    final secret = data['device_secret'] as String;
    await _bridge.saveConfig(base, id, secret);
    return PairResult(id, secret);
  }

  Map<String, dynamic> _decode(String body, int status) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    throw ApiException('bad_response', 'Server returned an unexpected response (HTTP $status).');
  }

  /// Signed request using the stored device credentials.
  Future<ApiResult<Map<String, dynamic>>> signed(String path,
      {String method = 'POST', Map<String, dynamic>? json, Map<String, String>? query}) async {
    final cfg = await _bridge.loadConfig();
    if (cfg == null) return const ApiResult(ApiState.unauthorized, message: 'Device is not paired.');
    final body = method == 'GET' ? '' : jsonEncode(json ?? const {});
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final n = nonce();
    final sig = sign(cfg.deviceSecret, method, path, ts, n, body);
    var uri = Uri.parse('${cfg.baseUrl}$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Device-Id': '${cfg.deviceId}',
        'X-Timestamp': '$ts',
        'X-Nonce': n,
        'X-Signature': sig,
      })
      ..body = body;
    try {
      final streamed = await _client.send(req).timeout(const Duration(seconds: 25));
      final text = await streamed.stream.bytesToString();
      final code = streamed.statusCode;
      if (code == 404 || code == 405) return const ApiResult(ApiState.notAvailable, message: 'Not available on server yet.');
      Map<String, dynamic> j;
      try {
        j = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        return ApiResult(ApiState.error, message: 'Unexpected server response (HTTP $code).');
      }
      if (code == 401 || code == 403) {
        return ApiResult(ApiState.unauthorized, message: friendlyApiError(j['error']?.toString() ?? 'revoked'));
      }
      if (code < 200 || code >= 300 || j['ok'] != true) {
        return ApiResult(ApiState.error, message: friendlyApiError(j['error']?.toString() ?? 'http_$code'));
      }
      return ApiResult(ApiState.ok, data: j);
    } on TimeoutException {
      return const ApiResult(ApiState.offline, message: 'Server timed out.');
    } catch (_) {
      return const ApiResult(ApiState.offline, message: 'Could not reach the server.');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> ping() => signed(ApsConfig.pingPath);

  Future<ApiResult<Map<String, dynamic>>> registerFcmToken(String token, {bool remove = false}) =>
      signed(ApsConfig.fcmTokenPath, json: {'token': token, 'platform': 'android', 'action': remove ? 'remove' : 'register'});

  Future<ApiResult<Map<String, dynamic>>> stats() => signed(ApsConfig.statsPath, method: 'GET');

  Future<ApiResult<Map<String, dynamic>>> transactions({int page = 1, int perPage = 30, Map<String, String>? filters}) =>
      signed(ApsConfig.transactionsPath, method: 'GET', query: {'page': '$page', 'per_page': '$perPage', ...?filters});

  Future<ApiResult<Map<String, dynamic>>> notifications({int page = 1}) =>
      signed(ApsConfig.notificationsPath, method: 'GET', query: {'page': '$page'});

  Future<ApiResult<Map<String, dynamic>>> createReference({String? linkTx}) =>
      signed(ApsConfig.referencePath, json: {if (linkTx != null) 'transaction_id': linkTx});
}
