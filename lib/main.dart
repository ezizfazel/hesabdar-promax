import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'invoice.dart';

const String serverUrl = "https://promaxmobile.ir/api.php";
const String appVersion = "2.0.0";
const String developerName = "ezizfd";

const List<String> popularBrands = [
  'اپل (Apple)',
  'سامسونگ (Samsung)',
  'شیائومی (Xiaomi)',
  'پوکو (Poco)',
  'هواوی (Huawei)',
  'آنر (Honor)',
  'نوکیا (Nokia)',
  'موتورولا (Motorola)',
  'اینفینیکس (Infinix)',
  'سایر برندها',
];

const List<String> registryOptions = [
  'شرکتی با گارانتی',
  'مسافری',
  'انجام شد (سفید)',
  'در انتظار خریدار',
  'بدون ریجستر',
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PromaxApp());
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    String value = newValue.text.replaceAll(',', '');
    if (value.isEmpty) return newValue;
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String newString = value.replaceAllMapped(formatter, (Match m) => '${m[1]},');
    return newValue.copyWith(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

class NationalIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String filtered = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (filtered.length > 10) filtered = filtered.substring(0, 10);
    return TextEditingValue(text: filtered, selection: TextSelection.collapsed(offset: filtered.length));
  }
}

String formatToman(dynamic numValue) {
  if (numValue == null) return "۰";
  return numValue.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

class PromaxColors {
  static const Color headerGradientStart = Color(0xFF0F172A);
  static const Color headerGradientEnd = Color(0xFF1E3A8A);
  static const Color background = Color(0xFF0F172A);
  static const Color cardBackground = Colors.white;
  static const Color fieldBorder = Color(0xFFCBD5E1);
  static const Color blueAction = Color(0xFF2563EB);
  static const Color greenAction = Color(0xFF16A34A);
  static const Color alertBg = Color(0xFFFEE2E2);
  static const Color alertText = Color(0xFFDC2626);
  static const Color textMuted = Color(0xFF64748B);
}

class PromaxApp extends StatelessWidget {
  const PromaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابدار پرومکس',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: PromaxColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: PromaxColors.blueAction),
      ),
      home: const LoginScreen(),
    );
  }
}

// لودینگ پیشرفته با درصد انیمیشنی زنده
class PromaxProgressLoading extends StatefulWidget {
  final String message;
  const PromaxProgressLoading({super.key, this.message = "در حال بارگذاری اطلاعات..."});

  @override
  State<PromaxProgressLoading> createState() => _PromaxProgressLoadingState();
}

class _PromaxProgressLoadingState extends State<PromaxProgressLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _animation = Tween<double>(begin: 15.0, end: 95.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final int percent = _animation.value.toInt();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: PromaxColors.blueAction.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: _animation.value / 100,
                        strokeWidth: 4.5,
                        backgroundColor: Colors.blue.shade50,
                        valueColor: const AlwaysStoppedAnimation<Color>(PromaxColors.blueAction),
                      ),
                    ),
                    Text("$percent٪", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: PromaxColors.blueAction)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(widget.message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PromaxColors.headerGradientStart)),
                const SizedBox(height: 4),
                const Text("اتصال امن به سرور promaxmobile.ir", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ساختار هدر یکپارچه
class PromaxPageLayout extends StatelessWidget {
  final String title;
  final String adminName;
  final String subtitle;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;
  final Widget body;

  const PromaxPageLayout({
    super.key,
    required this.title,
    required this.adminName,
    required this.subtitle,
    required this.openDrawer,
    required this.onNotificationTap,
    required this.onSecurityTap,
    required this.notificationCount,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PROMAX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.5)),
                        Text("v$appVersion | by $developerName", style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onSecurityTap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                        child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: openDrawer,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              children: [
                RichText(text: TextSpan(text: "$title ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), children: [TextSpan(text: "($adminName)", style: const TextStyle(color: Color(0xFF60A5FA)))])),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: PromaxColors.cardBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInput({required TextEditingController controller, required String hint, required IconData prefixIcon, bool isNumber = false, bool isPhone = false, Function(String)? onChanged}) {
  return TextField(
    controller: controller,
    keyboardType: isNumber || isPhone ? TextInputType.number : TextInputType.text,
    inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()] : null,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint, prefixIcon: Icon(prefixIcon, color: PromaxColors.textMuted, size: 20),
      filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
    ),
  );
}

// اسکنر بارکد
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'PromaxQR');
  QRViewController? controller;
  bool isScanned = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!isScanned && scanData.code != null && scanData.code!.isNotEmpty) {
        isScanned = true;
        Navigator.pop(context, scanData.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اسکن بارکد"), backgroundColor: PromaxColors.headerGradientStart, foregroundColor: Colors.white),
      body: Stack(
        alignment: Alignment.center,
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(borderColor: PromaxColors.blueAction, borderRadius: 16, borderLength: 30, borderWidth: 6, cutOutSize: 280),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Text("بارکد را داخل کادر بگیرید", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}

Future<void> openSafeScanner(BuildContext context, Function(String) onFound) async {
  final status = await Permission.camera.request();
  if (!status.isGranted) return;
  if (!context.mounted) return;
  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScannerScreen()));
  if (result != null && result is String) onFound(result);
}

// صفحه لاگین با بیومتریک
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
        body: jsonEncode({"username": userCtl.text.trim(), "password": passCtl.text.trim()}),
      );
      final data = jsonDecode(res.body);
      setState(() => loading = false);
      if (data['status'] == 'success') {
        await storage.write(key: 'promax_user', value: userCtl.text.trim());
        await storage.write(key: 'promax_pass', value: passCtl.text.trim());
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainNavigationScreen(adminData: data['admin'])));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطا در بیومتریک: $e")));
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: PromaxColors.blueAction.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.phone_android_rounded, size: 54, color: PromaxColors.blueAction)),
                const SizedBox(height: 12),
                const Text("PROMAX MOBILE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                Text("توسعه‌دهنده: $developerName | نسخه $appVersion", style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)),
                const SizedBox(height: 24),
                TextField(controller: userCtl, decoration: InputDecoration(labelText: "نام کاربری", prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
                const SizedBox(height: 12),
                TextField(controller: passCtl, obscureText: true, decoration: InputDecoration(labelText: "رمز عبور", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : login,
                  style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ورود به سامانه", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (canCheckBiometrics) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _authenticateBiometric,
                    icon: const Icon(Icons.fingerprint, color: PromaxColors.blueAction, size: 26),
                    label: const Text("ورود با اثر انگشت / Face ID", style: TextStyle(color: PromaxColors.blueAction, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: PromaxColors.blueAction), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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

// ناوبری اصلی ۵ تبه همراه با تفکیک سطح دسترسی‌ها
class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const MainNavigationScreen({super.key, required this.adminData});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  bool hasAccess(String section) {
    if (widget.adminData['role'] == 'super_admin') return true;
    final perms = widget.adminData['permissions']?.toString().split(',') ?? [];
    return perms.contains(section);
  }

  void _showAdminManagementPanel() async {
    final res = await http.get(Uri.parse("$serverUrl?action=get_admins"));
    final logRes = await http.get(Uri.parse("$serverUrl?action=get_logs"));
    List<dynamic> adminsList = [];
    List<dynamic> logsList = [];
    if (res.statusCode == 200) adminsList = jsonDecode(res.body)['data'];
    if (logRes.statusCode == 200) logsList = jsonDecode(logRes.body)['data'];

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPanelState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.manage_accounts), text: "مدیریت و دسترسی همکاران"),
                    Tab(icon: Icon(Icons.history), text: "تاریخچه فعالیت‌ها"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          ...adminsList.map((a) {
                            final perms = a['permissions']?.toString().split(',') ?? [];
                            final isSuper = a['role'] == 'super_admin';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: isSuper ? Colors.blue : Colors.blueGrey, child: const Icon(Icons.person, color: Colors.white)),
                                title: Text("${a['full_name']} (${a['username']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(isSuper ? "مدیر کل (دسترسی کامل)" : "دسترسی‌ها: ${perms.join('، ')}", style: const TextStyle(fontSize: 10.5)),
                                trailing: isSuper
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.edit_attributes_rounded, color: PromaxColors.blueAction),
                                        onPressed: () => _editAdminPermissionsDialog(a, () async {
                                          final r = await http.get(Uri.parse("$serverUrl?action=get_admins"));
                                          setPanelState(() => adminsList = jsonDecode(r.body)['data']);
                                        }),
                                      ),
                              ),
                            );
                          }),
                        ],
                      ),
                      ListView.builder(
                        itemCount: logsList.length,
                        itemBuilder: (context, idx) {
                          final l = logsList[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: const Icon(Icons.history_toggle_off, color: PromaxColors.blueAction),
                              title: Text("${l['action_type']} توسط ${l['admin_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text("${l['description']}\nزمان: ${l['created_at']}", style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editAdminPermissionsDialog(Map<String, dynamic> admin, VoidCallback onUpdated) {
    List<String> perms = admin['permissions']?.toString().split(',') ?? [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text("دسترسی‌های: ${admin['full_name']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(title: const Text("داشبورد و آمار مالی"), value: perms.contains('analytics'), onChanged: (v) => setDState(() => v! ? perms.add('analytics') : perms.remove('analytics'))),
              CheckboxListTile(title: const Text("خرید گوشی"), value: perms.contains('buy'), onChanged: (v) => setDState(() => v! ? perms.add('buy') : perms.remove('buy'))),
              CheckboxListTile(title: const Text("فروش گوشی"), value: perms.contains('sell'), onChanged: (v) => setDState(() => v! ? perms.add('sell') : perms.remove('sell'))),
              CheckboxListTile(title: const Text("انبار و سفارش‌ها"), value: perms.contains('inventory'), onChanged: (v) => setDState(() => v! ? perms.add('inventory') : perms.remove('inventory'))),
              CheckboxListTile(title: const Text("لوازم جانبی و اکسسوری"), value: perms.contains('accessories'), onChanged: (v) => setDState(() => v! ? perms.add('accessories') : perms.remove('accessories'))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                await http.post(
                  Uri.parse("$serverUrl?action=update_admin_permissions"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"admin_id": admin['id'], "permissions": perms.join(',')}),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                onUpdated();
              },
              child: const Text("ذخیره دسترسی‌ها"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = widget.adminData['role'] == 'super_admin';

    final List<Widget> accessiblePages = [
      hasAccess('analytics')
          ? AnalyticsDashboardScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: () {}, onSecurityTap: _showAdminManagementPanel, notificationCount: 0)
          : const Scaffold(body: Center(child: Text("شما به بخش آمار دسترسی ندارید"))),
      hasAccess('buy')
          ? BuyPhoneScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: () {}, onSecurityTap: _showAdminManagementPanel, notificationCount: 0)
          : const Scaffold(body: Center(child: Text("شما به بخش خرید دسترسی ندارید"))),
      hasAccess('sell')
          ? SellPhoneScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: () {}, onSecurityTap: _showAdminManagementPanel, notificationCount: 0)
          : const Scaffold(body: Center(child: Text("شما به بخش فروش دسترسی ندارید"))),
      hasAccess('inventory')
          ? InventoryAndReportsScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: () {}, onSecurityTap: _showAdminManagementPanel, notificationCount: 0)
          : const Scaffold(body: Center(child: Text("شما به بخش انبار دسترسی ندارید"))),
      hasAccess('accessories')
          ? AccessoriesScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: () {}, onSecurityTap: _showAdminManagementPanel, notificationCount: 0)
          : const Scaffold(body: Center(child: Text("شما به بخش اکسسوری دسترسی ندارید"))),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [PromaxColors.headerGradientStart, PromaxColors.headerGradientEnd], begin: Alignment.topRight, end: Alignment.bottomLeft),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white, size: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.adminData['full_name'] ?? 'مدیر پرومکس', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(isSuperAdmin ? "مدیر کل (Super Admin)" : "ادمین فروشگاهی", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (isSuperAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: PromaxColors.blueAction),
                      title: const Text("مدیریت دسترسی همکاران و تاریخچه"),
                      onTap: () {
                        Navigator.pop(context);
                        _showAdminManagementPanel();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Colors.red.shade50,
                leading: const Icon(Icons.logout_rounded, color: PromaxColors.alertText),
                title: const Text("خروج از حساب کاربری", style: TextStyle(color: PromaxColors.alertText, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ),
          ],
        ),
      ),
      body: accessiblePages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.headphones_outlined, label: "جانبی", index: 4),
              _navItem(icon: Icons.inventory_2_outlined, label: "انبار", index: 3),
              _navItem(icon: Icons.point_of_sale_rounded, label: "فروش", index: 2),
              _navItem(icon: Icons.shopping_cart_outlined, label: "خرید", index: 1),
              _navItem(icon: Icons.insights_rounded, label: "آمار مالی", index: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: isSelected ? const Color(0xFFE0E7FF) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted)),
        ],
      ),
    );
  }
}

// ==================== داشبورد آمار کاملاً هماهنگ با سرور ====================
class AnalyticsDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;

  const AnalyticsDashboardScreen({
    super.key,
    required this.adminData,
    required this.openDrawer,
    required this.onNotificationTap,
    required this.onSecurityTap,
    required this.notificationCount,
  });

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  // کلیدهای استاندارد انگلیسی جهت حل کامل مشکل لود نشدن آمار
  final Map<String, String> periodKeys = {
    'امروز': 'today',
    'دیروز': 'yesterday',
    '۷ روز اخیر': '7days',
    '۳۰ روز اخیر': '30days',
    'این ماه': 'this_month',
    'ماه قبل': 'last_month',
  };

  String selectedPeriodTitle = 'این ماه';
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    setState(() => loading = true);
    final key = periodKeys[selectedPeriodTitle] ?? 'this_month';
    try {
      final res = await http.get(Uri.parse("$serverUrl?action=get_summary&period=$key"));
      if (res.statusCode == 200) {
        setState(() {
          data = jsonDecode(res.body)['data'];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int bankBalance = data?['bank_balance'] ?? 0;
    final int totalLiquidity = data?['total_liquidity'] ?? 0;
    final List<dynamic> salesOrders = data?['sales_orders'] ?? [];

    return PromaxPageLayout(
      title: "گزارش‌ها و آمارها",
      adminName: widget.adminData['full_name'],
      subtitle: "محاسبه زنده عملکرد بدون خطا",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال دریافت آمار و نقدینگی...")
          : RefreshIndicator(
              onRefresh: loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // بازه‌های زمانی زنده
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: periodKeys.keys.map((p) {
                        final isSel = selectedPeriodTitle == p;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(p, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : Colors.black87)),
                            selected: isSel,
                            selectedColor: PromaxColors.blueAction,
                            backgroundColor: Colors.white,
                            onSelected: (_) {
                              setState(() => selectedPeriodTitle = p);
                              loadAnalytics();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // کارت نقدینگی و سرمایه کل
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("سرمایه و نقدینگی کل فروشگاه (کارت‌ها + انبارها)", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                        const SizedBox(height: 6),
                        Text("${formatToman(totalLiquidity)} تومان", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("موجودی نقدی کارت‌ها: ${formatToman(bankBalance)} ت", style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("سود ($selectedPeriodTitle): ${formatToman(data?['selected_profit'])} ت", style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // تفکیک آمار گوشی و اکسسوری
                  Row(
                    children: [
                      Expanded(
                        child: _categoryKpi(
                          title: "موبایل ($selectedPeriodTitle)",
                          sales: "${formatToman(data?['phone_sales'])} ت",
                          profit: "${formatToman(data?['phone_profit'])} ت",
                          stock: "${data?['phone_stock_count']} موجود",
                          color: PromaxColors.blueAction,
                          icon: Icons.phone_android,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _categoryKpi(
                          title: "اکسسوری ($selectedPeriodTitle)",
                          sales: "${formatToman(data?['acc_sales'])} ت",
                          profit: "${formatToman(data?['acc_profit'])} ت",
                          stock: "${data?['acc_stock_count']} عدد موجود",
                          color: Colors.deepPurple,
                          icon: Icons.headphones,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // لیست خریداران با جزئیات تسویه
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("خریداران و تسویه‌ها ($selectedPeriodTitle)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("${salesOrders.length} معامله", style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)),
                          ],
                        ),
                        const Divider(height: 16),
                        if (salesOrders.isEmpty)
                          const Padding(padding: EdgeInsets.all(12), child: Center(child: Text("در این بازه زمانی معامله‌ای ثبت نشده است", style: TextStyle(color: Colors.grey, fontSize: 11))))
                        else
                          ...salesOrders.map((o) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("${o['buyer_name']} (${o['brand']} ${o['model']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text("${formatToman(o['sale_price'])} تومان", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: PromaxColors.blueAction)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("تسویه: ${o['payment_method']} (پرداختی: ${formatToman(o['paid_amount'])} ت)", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
                                        Text(
                                          o['remaining_amount'] > 0 ? "مانده: ${formatToman(o['remaining_amount'])} ت" : "تسویه کامل",
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: o['remaining_amount'] > 0 ? Colors.red : Colors.green),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _categoryKpi({required String title, required String sales, required String profit, required String stock, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color))]),
          const Divider(height: 14),
          Text("فروش: $sales", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text("سود: $profit", style: const TextStyle(fontSize: 10.5, color: PromaxColors.greenAction, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(stock, style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
        ],
      ),
    );
  }
}

// ==================== بخش انبار با دکمه‌های کپسولی زیبا و لودینگ مدرن ====================
class InventoryAndReportsScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;
  const InventoryAndReportsScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, required this.onSecurityTap, required this.notificationCount});

  @override
  State<InventoryAndReportsScreen> createState() => _InventoryAndReportsScreenState();
}

class _InventoryAndReportsScreenState extends State<InventoryAndReportsScreen> {
  List<dynamic> allPhones = [];
  String searchQuery = "";
  int inventoryTabIndex = 0; // ۰: موجودی انبار | ۱: فروخته‌شده‌ها
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final resPhones = await http.get(Uri.parse("$serverUrl?action=get_all_phones"));
      if (resPhones.statusCode == 200) {
        setState(() {
          allPhones = jsonDecode(resPhones.body)['data'];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void _showEditOrderDialog(Map<String, dynamic> item) {
    String selectedBrand = popularBrands.contains(item['brand']) ? item['brand'] : popularBrands[0];
    final modelCtl = TextEditingController(text: item['model']);
    final imeiCtl = TextEditingController(text: item['imei']);
    final imei2Ctl = TextEditingController(text: item['imei2'] ?? '');
    final priceCtl = TextEditingController(text: item['status'] == 'SOLD' ? item['sale_price'].toString() : item['purchase_price'].toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("ویرایش کامل محصول"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBrand,
                  decoration: const InputDecoration(labelText: "برند دستگاه", border: OutlineInputBorder()),
                  items: popularBrands.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDState(() => selectedBrand = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: modelCtl, decoration: const InputDecoration(labelText: "مدل دستگاه", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "IMEI 1", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: imei2Ctl, decoration: const InputDecoration(labelText: "IMEI 2", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: priceCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "مبلغ (تومان)", border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                await http.post(
                  Uri.parse("$serverUrl?action=update_order"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "phone_id": item['id'],
                    "brand": selectedBrand,
                    "model": modelCtl.text,
                    "imei": imeiCtl.text,
                    "imei2": imei2Ctl.text,
                    "price": int.tryParse(priceCtl.text.replaceAll(',', '')) ?? 0,
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                load();
              },
              child: const Text("ذخیره"),
            ),
          ],
        ),
      ),
    );
  }

  void showDetailsModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Text("${item['brand']} ${item['model']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              _row("نام فروشنده:", "${item['seller_name'] ?? 'متفرقه'}"),
              _row("شماره تماس فروشنده:", "${item['seller_phone'] ?? '-'}"),
              _row("کد ملی فروشنده:", "${item['seller_nid'] ?? '-'}"),
              _row("قیمت خرید:", "${formatToman(item['purchase_price'])} تومان"),
              _row("سریال IMEI 1:", "${item['imei']}"),
              if (item['imei2'] != null) _row("سریال IMEI 2:", "${item['imei2']}"),
              _row("وضعیت رجیستری:", "${item['registry_status']}"),
              if (item['status'] == 'SOLD') ...[
                const Divider(),
                _row("نام خریدار:", "${item['buyer_name']} (${item['buyer_phone']})"),
                _row("قیمت فروش:", "${formatToman(item['sale_price'])} تومان"),
                _row("روش تسویه:", "${item['payment_method']}"),
                _row("مانده طلب:", "${formatToman(item['remaining_amount'])} تومان"),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showEditOrderDialog(item);
                },
                icon: const Icon(Icons.edit),
                label: const Text("ویرایش کامل کالا"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String t, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontSize: 11.5, color: PromaxColors.textMuted)), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));

  @override
  Widget build(BuildContext context) {
    final int inStockCount = allPhones.where((p) => p['status'] == 'IN_STOCK').length;
    final int soldCount = allPhones.where((p) => p['status'] == 'SOLD').length;

    final filtered = allPhones.where((item) {
      final isMatchStatus = inventoryTabIndex == 0 ? item['status'] == 'IN_STOCK' : item['status'] == 'SOLD';
      final q = searchQuery.toLowerCase();
      final isMatchQuery = (item['imei']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['brand']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['model']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['seller_name']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['buyer_name']?.toString().toLowerCase().contains(q) ?? false);
      return isMatchStatus && isMatchQuery;
    }).toList();

    return PromaxPageLayout(
      title: "انبار موبایل پرومکس",
      adminName: widget.adminData['full_name'],
      subtitle: "تفکیک کامل موجودی‌ها و دستگاه‌های فروخته‌شده",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال بارگذاری لیست انبار...")
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "جستجو در انبار (مدل، سریال، فروشنده...)",
                      prefixIcon: const Icon(Icons.search),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder)),
                    ),
                  ),
                ),
                // طراحی کپسولی و فوق‌العاده شیک دکمه‌های سوییچ انبار
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => inventoryTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: inventoryTabIndex == 0 ? PromaxColors.blueAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: inventoryTabIndex == 0 ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 6)] : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_rounded, size: 16, color: inventoryTabIndex == 0 ? Colors.white : PromaxColors.textMuted),
                                const SizedBox(width: 6),
                                Text("موجودی ($inStockCount)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inventoryTabIndex == 0 ? Colors.white : PromaxColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => inventoryTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: inventoryTabIndex == 1 ? PromaxColors.greenAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: inventoryTabIndex == 1 ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 6)] : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 16, color: inventoryTabIndex == 1 ? Colors.white : PromaxColors.textMuted),
                                const SizedBox(width: 6),
                                Text("فروخته‌شده ($soldCount)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inventoryTabIndex == 1 ? Colors.white : PromaxColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          onTap: () => showDetailsModal(item),
                          title: Text("${item['brand']} ${item['model']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("فروشنده: ${item['seller_name'] ?? 'متفرقه'} (کد ملی: ${item['seller_nid'] ?? '-'})\nIMEI: ${item['imei']}", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
                          trailing: Text("${formatToman(item['status'] == 'IN_STOCK' ? item['purchase_price'] : item['sale_price'])} ت", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================== صفحه خرید گوشی ====================
class BuyPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;
  const BuyPhoneScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, required this.onSecurityTap, required this.notificationCount});

  @override
  State<BuyPhoneScreen> createState() => _BuyPhoneScreenState();
}

class _BuyPhoneScreenState extends State<BuyPhoneScreen> {
  final imeiCtl = TextEditingController();
  final imei2Ctl = TextEditingController();
  final modelCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final nameCtl = TextEditingController();
  final phoneCtl = TextEditingController();
  final nIdCtl = TextEditingController();
  final descCtl = TextEditingController();
  String selectedBrand = popularBrands[0];
  String selectedRegistry = registryOptions[0];
  bool hamtaVerified = true;

  Future<void> submit() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("شناسه IMEI و مبلغ خرید الزامی هستند")));
      return;
    }
    final cleanPrice = int.parse(priceCtl.text.replaceAll(',', ''));
    final now = Jalali.now();
    final timeNow = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    final res = await http.post(
      Uri.parse("$serverUrl?action=buy_phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "imei": imeiCtl.text,
        "imei2": imei2Ctl.text,
        "brand": selectedBrand,
        "model": modelCtl.text,
        "purchase_price": cleanPrice,
        "customer_name": nameCtl.text,
        "phone_number": phoneCtl.text,
        "national_id": nIdCtl.text,
        "description": descCtl.text,
        "registry_status": selectedRegistry,
        "hamta_verified": hamtaVerified ? 1 : 0,
        "entry_time": "$timeNow - ${now.year}/${now.month}/${now.day}",
        "admin_name": widget.adminData['full_name'],
      }),
    );

    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("پیش‌نمایش فاکتور رسمی")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "رسید خرید کالا",
                personName: nameCtl.text.isEmpty ? "مشتری متفرقه" : nameCtl.text,
                phone: phoneCtl.text,
                nationalId: nIdCtl.text,
                brand: selectedBrand,
                model: modelCtl.text,
                imei: "${imeiCtl.text} ${imei2Ctl.text.isNotEmpty ? '/ ' + imei2Ctl.text : ''}",
                totalPrice: cleanPrice,
                paidPrice: cleanPrice,
                remainingPrice: 0,
                paymentMethod: "نقدی",
                paymentDetails: "",
                adminName: widget.adminData['full_name'],
                description: descCtl.text,
                registryStatus: selectedRegistry,
                hamtaVerified: hamtaVerified,
                isSale: false,
              ),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PromaxPageLayout(
      title: "خرید کالای",
      adminName: widget.adminData['full_name'],
      subtitle: "ثبت دستگاه با دو IMEI و استعلام همتا",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _buildInput(controller: imeiCtl, hint: "سریال اول (IMEI 1)", prefixIcon: Icons.view_week_outlined)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => openSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(height: 52, width: 52, decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInput(controller: imei2Ctl, hint: "سریال دوم (IMEI 2 - اختیاری)", prefixIcon: Icons.view_week_outlined)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => openSafeScanner(context, (code) => setState(() => imei2Ctl.text = code)),
                child: Container(height: 52, width: 52, decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder, width: 1.2)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBrand,
                isExpanded: true,
                items: popularBrands.map((b) => DropdownMenuItem(value: b, child: Text("برند: $b", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => selectedBrand = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(controller: modelCtl, hint: "مدل دستگاه", prefixIcon: Icons.phone_android_outlined),
          const SizedBox(height: 12),
          _buildInput(controller: priceCtl, hint: "مبلغ خرید توافقی (تومان)", prefixIcon: Icons.monetization_on_outlined, isNumber: true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder, width: 1.2)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRegistry,
                isExpanded: true,
                items: registryOptions.map((r) => DropdownMenuItem(value: r, child: Text("وضعیت رجیستری: $r", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => selectedRegistry = v!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: hamtaVerified,
            activeColor: PromaxColors.blueAction,
            title: const Text("تست اصالت و رجیستری سامانه همتا انجام شد", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onChanged: (v) => setState(() => hamtaVerified = v!),
          ),
          const Divider(height: 24),
          _buildInput(controller: nameCtl, hint: "نام فروشنده", prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildInput(controller: phoneCtl, hint: "شماره تماس فروشنده", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 12),
          TextField(
            controller: nIdCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [NationalIdFormatter()],
            decoration: InputDecoration(
              hintText: "کد ملی فروشنده (دقیقاً ۱۰ رقم)",
              prefixIcon: const Icon(Icons.badge_outlined, color: PromaxColors.textMuted, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(controller: descCtl, hint: "یادداشت و توضیحات معامله", prefixIcon: Icons.note_alt_outlined),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.blueAction, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_outlined), SizedBox(width: 8), Text("ثبت در انبار و صدور فاکتور", style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==================== صفحه فروش گوشی با تقویم شمسی موعد قرض ====================
class SellPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;
  const SellPhoneScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, required this.onSecurityTap, required this.notificationCount});

  @override
  State<SellPhoneScreen> createState() => _SellPhoneScreenState();
}

class _SellPhoneScreenState extends State<SellPhoneScreen> {
  final imeiCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final paidCtl = TextEditingController();
  final payDetailsCtl = TextEditingController();
  final buyerNameCtl = TextEditingController();
  final buyerPhoneCtl = TextEditingController();
  final descCtl = TextEditingController();
  String selectedMethod = 'نقدی';
  String selectedRegistry = registryOptions[0];
  bool hamtaVerified = true;
  String? creditDueShamsi;

  int get remaining {
    int total = int.tryParse(priceCtl.text.replaceAll(',', '')) ?? 0;
    int paid = int.tryParse(paidCtl.text.replaceAll(',', '')) ?? total;
    return total - paid;
  }

  Future<void> submit() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) return;
    int total = int.parse(priceCtl.text.replaceAll(',', ''));
    int paid = int.tryParse(paidCtl.text.replaceAll(',', '')) ?? total;

    final now = Jalali.now();
    final timeNow = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    final res = await http.post(
      Uri.parse("$serverUrl?action=sell_phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "imei": imeiCtl.text,
        "sale_price": total,
        "paid_amount": paid,
        "payment_method": selectedMethod,
        "payment_details": payDetailsCtl.text,
        "buyer_name": buyerNameCtl.text.isEmpty ? "مشتری متفرقه" : buyerNameCtl.text,
        "buyer_phone": buyerPhoneCtl.text,
        "description": descCtl.text,
        "registry_status": selectedRegistry,
        "hamta_verified": hamtaVerified ? 1 : 0,
        "credit_due_shamsi": creditDueShamsi,
        "sale_time": "$timeNow - ${now.year}/${now.month}/${now.day}",
        "admin_name": widget.adminData['full_name'],
      }),
    );

    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("پیش‌نمایش فاکتور رسمی")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "فاکتور رسمی فروش کالا",
                personName: buyerNameCtl.text.isEmpty ? "مشتری فروشگاه" : buyerNameCtl.text,
                phone: buyerPhoneCtl.text,
                nationalId: "-",
                brand: "تلفن همراه",
                model: "فروخته‌شده",
                imei: imeiCtl.text,
                totalPrice: total,
                paidPrice: paid,
                remainingPrice: total - paid,
                paymentMethod: selectedMethod,
                paymentDetails: payDetailsCtl.text,
                adminName: widget.adminData['full_name'],
                description: descCtl.text,
                registryStatus: selectedRegistry,
                hamtaVerified: hamtaVerified,
                isSale: true,
              ),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    }
  }

  void _pickShamsiDate() {
    final now = Jalali.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    int selectedDay = now.day;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("انتخاب تاریخ موعد قرض (شمسی)"),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              DropdownButton<int>(
                value: selectedYear,
                items: [now.year, now.year + 1].map((y) => DropdownMenuItem(value: y, child: Text("$y"))).toList(),
                onChanged: (v) => setDState(() => selectedYear = v!),
              ),
              DropdownButton<int>(
                value: selectedMonth,
                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text("ماه $m"))).toList(),
                onChanged: (v) => setDState(() => selectedMonth = v!),
              ),
              DropdownButton<int>(
                value: selectedDay,
                items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text("$d"))).toList(),
                onChanged: (v) => setDState(() => selectedDay = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () {
                setState(() => creditDueShamsi = "$selectedYear/$selectedMonth/$selectedDay");
                Navigator.pop(ctx);
              },
              child: const Text("تایید موعد"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PromaxPageLayout(
      title: "فروش کالا",
      adminName: widget.adminData['full_name'],
      subtitle: "انتخاب کالا با IMEI انبار و ثبت تسویه",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _buildInput(controller: imeiCtl, hint: "شناسه IMEI دستگاه", prefixIcon: Icons.view_week_outlined)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => openSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(height: 52, width: 52, decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(controller: priceCtl, hint: "قیمت نهایی فروش (تومان)", prefixIcon: Icons.sell_outlined, isNumber: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder, width: 1.2)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRegistry,
                isExpanded: true,
                items: registryOptions.map((r) => DropdownMenuItem(value: r, child: Text("انتقال مالکیت / رجیستری: $r", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => selectedRegistry = v!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: hamtaVerified,
            activeColor: PromaxColors.greenAction,
            title: const Text("تست اصالت و رجیستری انجام شد", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onChanged: (v) => setState(() => hamtaVerified = v!),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder, width: 1.2)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMethod,
                isExpanded: true,
                items: ['نقدی', 'قسطی', 'چکی', 'قرضی'].map((m) => DropdownMenuItem<String>(value: m, child: Text("روش تسویه: $m", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => selectedMethod = v!),
              ),
            ),
          ),
          if (selectedMethod == 'نقدی') ...[
            const SizedBox(height: 12),
            _buildInput(controller: payDetailsCtl, hint: "واریز به کدام کارت شد یا با پوز کشیده شد؟", prefixIcon: Icons.credit_card_rounded),
          ],
          if (selectedMethod == 'قرضی') ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickShamsiDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade300)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(creditDueShamsi == null ? "انتخاب تاریخ موعد تسویه قرض (شمسی)" : "موعد پرداخت: $creditDueShamsi", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                    const Icon(Icons.calendar_month, color: Colors.brown),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildInput(controller: paidCtl, hint: "مبلغ دریافتی (پیش‌پرداخت/نقدی)", prefixIcon: Icons.payments_outlined, isNumber: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _buildInput(controller: buyerNameCtl, hint: "نام خریدار", prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildInput(controller: buyerPhoneCtl, hint: "شماره تماس خریدار", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline), SizedBox(width: 8), Text("ثبت خروج از انبار و صدور فاکتور", style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==================== صفحه لوازم جانبی با فروش توافقی و تخفیف‌دار ====================
class AccessoriesScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback onSecurityTap;
  final int notificationCount;
  const AccessoriesScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, required this.onSecurityTap, required this.notificationCount});

  @override
  State<AccessoriesScreen> createState() => _AccessoriesScreenState();
}

class _AccessoriesScreenState extends State<AccessoriesScreen> {
  List<dynamic> accessories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("$serverUrl?action=get_accessories"));
      if (res.statusCode == 200) {
        setState(() {
          accessories = jsonDecode(res.body)['data'];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void _showAddDialog() {
    final nameCtl = TextEditingController();
    final barcodeCtl = TextEditingController();
    final catCtl = TextEditingController(text: "قاب و گلس");
    final stockCtl = TextEditingController();
    final buyCtl = TextEditingController();
    final saleCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("افزودن اکسسوری جدید"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام کالا")),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: barcodeCtl, decoration: const InputDecoration(labelText: "بارکد (اختیاری)"))),
                  IconButton(icon: const Icon(Icons.qr_code_scanner, color: PromaxColors.blueAction), onPressed: () => openSafeScanner(context, (c) => barcodeCtl.text = c)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: catCtl, decoration: const InputDecoration(labelText: "دسته‌بندی")),
              TextField(controller: stockCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد موجودی")),
              TextField(controller: buyCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت خرید (تومان)")),
              TextField(controller: saleCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت فروش مصوب (تومان)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              if (nameCtl.text.isEmpty || stockCtl.text.isEmpty) return;
              await http.post(
                Uri.parse("$serverUrl?action=add_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "name": nameCtl.text,
                  "barcode": barcodeCtl.text,
                  "category": catCtl.text,
                  "stock": int.parse(stockCtl.text),
                  "buy_price": int.parse(buyCtl.text.replaceAll(',', '')),
                  "sale_price": int.parse(saleCtl.text.replaceAll(',', '')),
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("ثبت کالا"),
          ),
        ],
      ),
    );
  }

  // دیالوگ فروش سریع با قابلیت اعمال تخفیف و تغییر قیمت نهایی فروش
  void _showSellDialog(Map<String, dynamic> item) {
    final qtyCtl = TextEditingController(text: "1");
    final customPriceCtl = TextEditingController(text: formatToman(item['sale_price']));
    final buyerCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("فروش کالای: ${item['name']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("موجودی فعلی در انبار: ${item['stock']} عدد", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: PromaxColors.textMuted)),
              const SizedBox(height: 10),
              TextField(controller: qtyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد فروش", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: customPriceCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: "قیمت نهایی هر عدد با تخفیف (تومان)",
                  helperText: "در صورت تخفیف دادن مبلغ نهایی را اینجا وارد کنید",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: buyerCtl, decoration: const InputDecoration(labelText: "نام مشتری (اختیاری)", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final finalPrice = int.tryParse(customPriceCtl.text.replaceAll(',', '')) ?? item['sale_price'];
              await http.post(
                Uri.parse("$serverUrl?action=sell_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "accessory_id": item['id'],
                  "quantity": int.parse(qtyCtl.text),
                  "custom_sale_price": finalPrice,
                  "buyer_name": buyerCtl.text,
                  "admin_name": widget.adminData['full_name'],
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("ثبت فروش و کسر از انبار"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PromaxPageLayout(
      title: "لوازم جانبی و اکسسوری",
      adminName: widget.adminData['full_name'],
      subtitle: "مدیریت قاب، گلس، شارژر و کالاهای بدون IMEI",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال دریافت لیست لوازم جانبی...")
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("افزودن کالای جانبی جدید"),
                    style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(50)),
                  ),
                  const SizedBox(height: 16),
                  ...accessories.map((item) {
                    final int currentStock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.headphones, color: PromaxColors.blueAction)),
                        title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text("موجودی: $currentStock | خرید: ${formatToman(item['buy_price'])} | فروش مصوب: ${formatToman(item['sale_price'])} ت", style: const TextStyle(fontSize: 10.5)),
                        trailing: ElevatedButton(
                          onPressed: currentStock > 0 ? () => _showSellDialog(item) : null,
                          style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white),
                          child: const Text("فروش"),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
