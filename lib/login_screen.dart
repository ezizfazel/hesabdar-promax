import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'colors.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtl = TextEditingController(text: 'admin1');
  final passCtl = TextEditingController(text: '123456');
  bool loading = false;
  bool canCheckBiometrics = false;
  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometricSupport();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUser = await storage.read(key: 'promax_user');
    final savedPass = await storage.read(key: 'promax_pass');
    if (savedUser != null && savedPass != null) {
      setState(() {
        userCtl.text = savedUser;
        passCtl.text = savedPass;
      });
      _tryAutoBiometricLogin();
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final bool supported = await auth.isDeviceSupported();
      final bool canCheck = await auth.canCheckBiometrics;
      setState(() => canCheckBiometrics = supported && canCheck);
    } catch (_) {}
  }

  Future<void> _tryAutoBiometricLogin() async {
    final savedUser = await storage.read(key: 'promax_user');
    final savedPass = await storage.read(key: 'promax_pass');
    if (savedUser != null && savedPass != null && canCheckBiometrics) {
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: 'ورود سریع به حسابدار پرومکس',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (authenticated) {
          login();
        }
      } catch (_) {}
    }
  }

  Future<void> login() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse("$serverUrl?action=login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": userCtl.text.trim(),
          "password": passCtl.text.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      setState(() => loading = false);
      if (data['status'] == 'success') {
        await storage.write(key: 'promax_user', value: userCtl.text.trim());
        await storage.write(key: 'promax_pass', value: passCtl.text.trim());
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationScreen(adminData: data['admin']),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'لطفاً اثر انگشت خود را تایید کنید',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated) {
        login();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطا در بیومتریک: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PromaxColors.blueAction.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    size: 54,
                    color: PromaxColors.blueAction,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "PROMAX MOBILE",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  "توسعه‌دهنده: $developerName | نسخه $appVersion",
                  style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: userCtl,
                  decoration: InputDecoration(
                    labelText: "نام کاربری",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "رمز عبور",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : login,
                  style: FilledButton.styleFrom(
                    backgroundColor: PromaxColors.blueAction,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ورود به سامانه", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (canCheckBiometrics) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _authenticateBiometric,
                    icon: const Icon(Icons.fingerprint, color: PromaxColors.blueAction, size: 26),
                    label: const Text(
                      "ورود با اثر انگشت / Face ID",
                      style: TextStyle(color: PromaxColors.blueAction, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: PromaxColors.blueAction),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
