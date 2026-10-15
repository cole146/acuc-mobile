import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String kBase = String.fromEnvironment('ACUC_BASE', defaultValue: 'https://acuc.jobs');
const bool kRestQueryStyle = bool.fromEnvironment('ACUC_REST_QUERY', defaultValue: false);
const String kAppVersion = '2.0.0';
const String kUserAgent = 'ACUCApp/$kAppVersion (Flutter; native)';

class ApiError implements Exception {
  final String message;
  final int status;
  final String code;
  ApiError(this.message, {this.status = 0, this.code = ''});
  @override
  String toString() => message;
}

/// Signed-in state + every call to acuc.jobs (the same acuc/v1 API the website uses).
class Session extends ChangeNotifier {
  Session._();
  static final Session I = Session._();

  final _store = const FlutterSecureStorage();
  final _client = http.Client();

  String? _token;
  Map<String, dynamic>? user;
  bool ready = false;

  bool get signedIn => _token != null;
  String get name => (user?['name'] ?? '').toString();
  String get firstName => name.split(' ').first;
  bool get isEmployer => user?['is_employer'] == true;

  Future<void> load() async {
    try {
      _token = await _store.read(key: 'token');
    } catch (_) {
      _token = null;
    }
    if (_token != null) {
      try {
        final me = await get('/me');
        if (me is Map<String, dynamic> && me['logged_in'] != false) {
          user = me;
        } else {
          await _forget();
        }
      } on ApiError catch (e) {
        if (e.status == 401) await _forget();
      } catch (_) {/* offline: keep the token, try again later */}
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(String login, String password) async {
    final r = await post('/app/token', {'login': login.trim(), 'password': password, 'device': _deviceName()}, auth: false);
    await useToken((r['token'] ?? '').toString(), user: r['user'] as Map<String, dynamic>?);
  }

  Future<void> useToken(String token, {Map<String, dynamic>? user}) async {
    if (!token.startsWith('acuc_')) throw ApiError('Sign-in did not finish. Please try again.');
    _token = token;
    await _store.write(key: 'token', value: token);
    this.user = user ?? (await get('/me')) as Map<String, dynamic>?;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (!signedIn) return;
    try {
      user = (await get('/me')) as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      await delete('/app/token');
    } catch (_) {}
    await _forget();
  }

  Future<void> _forget() async {
    _token = null;
    user = null;
    try {
      await _store.delete(key: 'token');
    } catch (_) {}
    notifyListeners();
  }

  String _deviceName() {
    try {
      final s = '${Platform.isAndroid ? 'Android' : Platform.operatingSystem} phone';
      return s.length > 40 ? s.substring(0, 40) : s;
    } catch (_) {
      return 'Phone';
    }
  }

  Uri uri(String path, [Map<String, dynamic>? q]) {
    final query = <String, String>{};
    q?.forEach((k, v) {
      if (v != null && '$v' != '') query[k] = '$v';
    });
    // Signed-in answers are personal: a unique address keeps any page cache from mixing them up.
    if (_token != null) query['_'] = DateTime.now().millisecondsSinceEpoch.toString();
    if (kRestQueryStyle) {
      // Sites without pretty REST URLs (and local tests): /?rest_route=/acuc/v1/…
      return Uri.parse('$kBase/').replace(queryParameters: {'rest_route': '/acuc/v1$path', ...query});
    }
    return Uri.parse('$kBase/wp-json/acuc/v1$path').replace(queryParameters: query.isEmpty ? null : query);
  }

  Map<String, String> _headers({bool json = false, bool auth = true}) => {
        'Accept': 'application/json',
        'User-Agent': kUserAgent,
        if (json) 'Content-Type': 'application/json',
        if (auth && _token != null) 'X-ACUC-Token': _token!,
      };

  Future<dynamic> get(String path, [Map<String, dynamic>? q]) => _send(() => _client.get(uri(path, q), headers: _headers()));

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) =>
      _send(() => _client.post(uri(path), headers: _headers(json: true, auth: auth), body: jsonEncode(body)));

  Future<dynamic> delete(String path) => _send(() => _client.delete(uri(path), headers: _headers()));

  Future<dynamic> upload(String path, String field, String filePath, {String? filename}) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', uri(path))..headers.addAll(_headers());
      req.files.add(await http.MultipartFile.fromPath(field, filePath, filename: filename));
      return http.Response.fromStream(await _client.send(req));
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiError('ACUC is taking too long to answer. Check your connection and try again.');
    } on SocketException {
      throw ApiError('No internet connection. Check your connection and try again.');
    } on http.ClientException {
      throw ApiError('No internet connection. Check your connection and try again.');
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final msg = (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty)
        ? data['message'] as String
        : 'Something went wrong (${res.statusCode}). Please try again.';
    final code = data is Map ? (data['code'] ?? '').toString() : '';
    if (res.statusCode == 401 && _token != null && code == 'acuc_app_token') {
      await _forget();
    }
    throw ApiError(_plain(msg), status: res.statusCode, code: code);
  }

  String _plain(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&#8217;', '’').replaceAll('&amp;', '&').trim();
}
