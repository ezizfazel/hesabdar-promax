import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// لایه‌ی مرکزی ارتباط با سرور.
///
/// همه‌ی درخواست‌ها باید از این کلاس عبور کنند تا:
///  - توکن نشست (Bearer) به‌صورت خودکار به هدر اضافه شود؛
///  - همه‌ی درخواست‌ها timeout داشته باشند؛
///  - اگر سرور 401 برگرداند (توکن نامعتبر یا منقضی)، کاربر به صفحه‌ی ورود برگردد.
class Api {
  Api._();

  static const Duration timeout = Duration(seconds: 15);
  static const _storage = FlutterSecureStorage();

  static const _kToken = 'promax_token';
  static const _kAdmin = 'promax_admin';
  static const _kUser = 'promax_user';
  // کلید قدیمی: نسخه‌های قبلی رمز عبور را روی گوشی ذخیره می‌کردند.
  static const _kLegacyPass = 'promax_pass';

  /// کلید ناوبری سراسری برای برگرداندن کاربر به صفحه‌ی ورود هنگام انقضای نشست.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// سازنده‌ی صفحه‌ی ورود؛ در main.dart مقداردهی می‌شود تا وابستگی حلقوی ایجاد نشود.
  static Widget Function()? loginScreenBuilder;

  static String? _token;
  static bool _redirecting = false;

  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static Map<String, String> _headers([Map<String, String>? extra]) {
    return {
      'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_token',
      // برخی هاست‌های اشتراکی هدر Authorization را به PHP نمی‌رسانند؛ سرور این را هم می‌پذیرد.
      if (hasToken) 'X-Auth-Token': _token!,
      ...?extra,
    };
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final res = await http.get(url, headers: _headers(headers)).timeout(timeout);
    _checkUnauthorized(res);
    return res;
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final res = await http.post(url, headers: _headers(headers), body: body).timeout(timeout);
    _checkUnauthorized(res);
    return res;
  }

  static void _checkUnauthorized(http.Response res) {
    if (res.statusCode != 401 || _redirecting) return;
    _redirecting = true;
    clearSession().whenComplete(() {
      _redirecting = false;
      final nav = navigatorKey.currentState;
      final builder = loginScreenBuilder;
      if (nav == null || builder == null) return;
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => builder()), (_) => false);
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          const SnackBar(content: Text('نشست شما منقضی شده است. لطفاً دوباره وارد شوید.')),
        );
      }
    });
  }

  // ------------------- مدیریت نشست -------------------

  /// پس از ورود موفق صدا زده می‌شود. فقط توکن و اطلاعات نمایشی ادمین ذخیره می‌شود،
  /// نه رمز عبور.
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> admin,
    required String username,
  }) async {
    _token = token;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kAdmin, value: jsonEncode(admin));
    await _storage.write(key: _kUser, value: username);
    await _storage.delete(key: _kLegacyPass);
  }

  /// نشست ذخیره‌شده (برای ورود با اثر انگشت). اگر وجود نداشته باشد null برمی‌گرداند.
  static Future<Map<String, dynamic>?> loadSavedAdmin() async {
    final token = await _storage.read(key: _kToken);
    final admin = await _storage.read(key: _kAdmin);
    if (token == null || token.isEmpty || admin == null) return null;
    try {
      final decoded = jsonDecode(admin);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// فعال‌سازی توکن ذخیره‌شده، فقط پس از تأیید بیومتریک.
  static Future<bool> restoreToken() async {
    final token = await _storage.read(key: _kToken);
    if (token == null || token.isEmpty) return false;
    _token = token;
    return true;
  }

  static Future<String?> savedUsername() => _storage.read(key: _kUser);

  /// پاک کردن رمز عبوری که نسخه‌های قدیمی اپ ذخیره کرده بودند.
  static Future<void> purgeLegacyPassword() => _storage.delete(key: _kLegacyPass);

  /// پاک کردن نشست محلی (توکن و اطلاعات ادمین). نام کاربری برای راحتی نگه داشته می‌شود.
  static Future<void> clearSession() async {
    _token = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kAdmin);
    await _storage.delete(key: _kLegacyPass);
  }

  /// خروج: ابطال توکن روی سرور (در صورت امکان) و پاک کردن نشست محلی.
  static Future<void> logout(String serverUrl) async {
    if (hasToken) {
      try {
        await http
            .post(Uri.parse('$serverUrl?action=logout'), headers: _headers())
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await clearSession();
  }
}
