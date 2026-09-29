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
import 'package:shimmer/shimmer.dart';
import 'invoice.dart';

const String serverUrl = "https://promaxmobile.ir/api.php";
const String appVersion = "1.9.0";
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
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;
    String value = newValue.text.replaceAll(',', '');
    if (value.isEmpty) return newValue;
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String newString = value.replaceAllMapped(
      formatter,
      (Match m) => '${m[1]},',
    );
    return newValue.copyWith(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

class NationalIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String filtered = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (filtered.length > 10) filtered = filtered.substring(0, 10);
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
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

class PromaxSkeletonLoading extends StatelessWidget {
  const PromaxSkeletonLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

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
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PROMAX",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          "v$appVersion | by $developerName",
                          style: const TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onNotificationTap,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                          ),
                          if (notificationCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "$notificationCount",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: openDrawer,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
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
                RichText(
                  text: TextSpan(
                    text: "$title ",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: "($adminName)",
                        style: const TextStyle(color: Color(0xFF60A5FA)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: PromaxColors.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInput({
  required TextEditingController controller,
  required String hint,
  required IconData prefixIcon,
  bool isNumber = false,
  bool isPhone = false,
  Function(String)? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: isNumber || isPhone ? TextInputType.number : TextInputType.text,
    inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()] : null,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: PromaxColors.textMuted, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: PromaxColors.blueAction, width: 1.5),
      ),
    ),
  );
}

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
      appBar: AppBar(
        title: const Text("اسکن بارکد"),
        backgroundColor: PromaxColors.headerGradientStart,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: PromaxColors.blueAction,
              borderRadius: 16,
              borderLength: 30,
              borderWidth: 6,
              cutOutSize: 280,
            ),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "بارکد را داخل کادر بگیرید",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
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
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
  );
  if (result != null && result is String) onFound(result);
}

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

class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const MainNavigationScreen({super.key, required this.adminData});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  List<dynamic> notifications = [];

  bool hasAccess(String section) {
    if (widget.adminData['role'] == 'super_admin') return true;
    final perms = widget.adminData['permissions']?.toString().split(',') ?? [];
    return perms.contains(section);
  }

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final res = await http.get(Uri.parse("$serverUrl?action=get_notifications"));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == 'success') setState(() => notifications = d['data']);
      }
    } catch (_) {}
  }

  void _showDirectDownloadDialog(String title, String fileType, String directUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: PromaxColors.blueAction),
            const SizedBox(width: 8),
            Text("دانلود $title"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("جهت دریافت مستقیم فایل، لینک زیر را در مرورگر باز کنید:", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                directUrl,
                style: const TextStyle(fontSize: 11, color: PromaxColors.blueAction, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("بستن")),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: directUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("لینک مستقیم دانلود کپی شد")),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text("کپی لینک دانلود"),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: PromaxColors.blueAction),
                    SizedBox(width: 8),
                    Text("مرکز اعلان‌های هوشمند", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text("${notifications.length} مورد", style: const TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text("هیچ اعلان معوقی وجود ندارد", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, idx) {
                        final n = notifications[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 6),
                                  Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(n['message'], style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.manage_accounts), text: "مدیریت و دسترسی همکاران"),
                    Tab(icon: Icon(Icons.history), text: "تاریخچه فعالیت‌ها و لاگ"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              _showCreateAdminWithPermissionsDialog(() async {
                                final r = await http.get(Uri.parse("$serverUrl?action=get_admins"));
                                setPanelState(() => adminsList = jsonDecode(r.body)['data']);
                              });
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text("افزودن همکار جدید با دسترسی دلخواه"),
                          ),
                          const SizedBox(height: 12),
                          ...adminsList.map((a) {
                            final perms = a['permissions']?.toString().split(',') ?? [];
                            final isSuper = a['role'] == 'super_admin';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSuper ? Colors.blue : Colors.blueGrey,
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(
                                  "${a['full_name']} (${a['username']})",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  isSuper ? "مدیر کل (دسترسی کامل)" : "دسترسی‌ها: ${perms.join('، ')}",
                                  style: const TextStyle(fontSize: 10.5),
                                ),
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
                              title: Text(
                                "${l['action_type']} توسط ${l['admin_name']}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              subtitle: Text(
                                "${l['description']}\nزمان: ${l['created_at']}",
                                style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted),
                              ),
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
              CheckboxListTile(
                title: const Text("داشبورد و آمار مالی"),
                value: perms.contains('analytics'),
                onChanged: (v) => setDState(() => v! ? perms.add('analytics') : perms.remove('analytics')),
              ),
              CheckboxListTile(
                title: const Text("خرید گوشی"),
                value: perms.contains('buy'),
                onChanged: (v) => setDState(() => v! ? perms.add('buy') : perms.remove('buy')),
              ),
              CheckboxListTile(
                title: const Text("فروش گوشی"),
                value: perms.contains('sell'),
                onChanged: (v) => setDState(() => v! ? perms.add('sell') : perms.remove('sell')),
              ),
              CheckboxListTile(
                title: const Text("انبار و سفارش‌ها"),
                value: perms.contains('inventory'),
                onChanged: (v) => setDState(() => v! ? perms.add('inventory') : perms.remove('inventory')),
              ),
              CheckboxListTile(
                title: const Text("لوازم جانبی و اکسسوری"),
                value: perms.contains('accessories'),
                onChanged: (v) => setDState(() => v! ? perms.add('accessories') : perms.remove('accessories')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                await http.post(
                  Uri.parse("$serverUrl?action=update_admin_permissions"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "admin_id": admin['id'],
                    "admin_name": admin['full_name'],
                    "permissions": perms.join(','),
                  }),
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

  void _showCreateAdminWithPermissionsDialog(VoidCallback onCreated) {
    final nameCtl = TextEditingController();
    final userCtl = TextEditingController();
    final passCtl = TextEditingController();
    List<String> perms = ['accessories'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("افزودن همکار با سطح دسترسی"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام کامل همکار")),
                TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
                TextField(controller: passCtl, decoration: const InputDecoration(labelText: "کلمه عبور")),
                const Divider(),
                const Text("بخش‌های مجاز برای این همکار:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                CheckboxListTile(
                  title: const Text("آمار مالی"),
                  value: perms.contains('analytics'),
                  onChanged: (v) => setDState(() => v! ? perms.add('analytics') : perms.remove('analytics')),
                ),
                CheckboxListTile(
                  title: const Text("خرید گوشی"),
                  value: perms.contains('buy'),
                  onChanged: (v) => setDState(() => v! ? perms.add('buy') : perms.remove('buy')),
                ),
                CheckboxListTile(
                  title: const Text("فروش گوشی"),
                  value: perms.contains('sell'),
                  onChanged: (v) => setDState(() => v! ? perms.add('sell') : perms.remove('sell')),
                ),
                CheckboxListTile(
                  title: const Text("انبار"),
                  value: perms.contains('inventory'),
                  onChanged: (v) => setDState(() => v! ? perms.add('inventory') : perms.remove('inventory')),
                ),
                CheckboxListTile(
                  title: const Text("اکسسوری"),
                  value: perms.contains('accessories'),
                  onChanged: (v) => setDState(() => v! ? perms.add('accessories') : perms.remove('accessories')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                if (userCtl.text.isEmpty || passCtl.text.isEmpty) return;
                await http.post(
                  Uri.parse("$serverUrl?action=create_admin"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "requester_role": widget.adminData['role'],
                    "full_name": nameCtl.text,
                    "username": userCtl.text,
                    "password": passCtl.text,
                    "permissions": perms.join(','),
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                onCreated();
              },
              child: const Text("ثبت همکار"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtl = TextEditingController(text: widget.adminData['full_name']);
    final userCtl = TextEditingController(text: widget.adminData['username']);
    final passCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ویرایش حساب من"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام کامل")),
            TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
            TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: "رمز عبور جدید (اختیاری)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final res = await http.post(
                Uri.parse("$serverUrl?action=update_profile"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "admin_id": widget.adminData['id'],
                  "full_name": nameCtl.text,
                  "username": userCtl.text,
                  "new_password": passCtl.text,
                }),
              );
              final d = jsonDecode(res.body);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'])));
            },
            child: const Text("ذخیره"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = widget.adminData['role'] == 'super_admin';

    // هماهنگی دقیق نام کلاس صفحه انبار با نام ویجت (InventoryAndReportsScreen)
    final List<Widget> accessiblePages = [
      hasAccess('analytics')
          ? AnalyticsDashboardScreen(
              adminData: widget.adminData,
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationTap: _showNotificationsSheet,
              onSecurityTap: _showAdminManagementPanel,
              notificationCount: notifications.length,
            )
          : const Scaffold(body: Center(child: Text("شما به بخش آمار دسترسی ندارید"))),
      hasAccess('buy')
          ? BuyPhoneScreen(
              adminData: widget.adminData,
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationTap: _showNotificationsSheet,
              onSecurityTap: _showAdminManagementPanel,
              notificationCount: notifications.length,
            )
          : const Scaffold(body: Center(child: Text("شما به بخش خرید دسترسی ندارید"))),
      hasAccess('sell')
          ? SellPhoneScreen(
              adminData: widget.adminData,
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationTap: _showNotificationsSheet,
              onSecurityTap: _showAdminManagementPanel,
              notificationCount: notifications.length,
            )
          : const Scaffold(body: Center(child: Text("شما به بخش فروش دسترسی ندارید"))),
      hasAccess('inventory')
          ? InventoryAndReportsScreen(
              adminData: widget.adminData,
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationTap: _showNotificationsSheet,
              onSecurityTap: _showAdminManagementPanel,
              notificationCount: notifications.length,
            )
          : const Scaffold(body: Center(child: Text("شما به بخش انبار دسترسی ندارید"))),
      hasAccess('accessories')
          ? AccessoriesScreen(
              adminData: widget.adminData,
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationTap: _showNotificationsSheet,
              onSecurityTap: _showAdminManagementPanel,
              notificationCount: notifications.length,
            )
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
                gradient: LinearGradient(
                  colors: [PromaxColors.headerGradientStart, PromaxColors.headerGradientEnd],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
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
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: PromaxColors.blueAction),
                    title: const Text("تغییر نام و پسورد من"),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditProfileDialog();
                    },
                  ),
                  if (isSuperAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: PromaxColors.greenAction),
                      title: const Text("مدیریت دسترسی همکاران و تاریخچه"),
                      onTap: () {
                        Navigator.pop(context);
                        _showAdminManagementPanel();
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined, color: Colors.teal),
                    title: const Text("دانلود مستقیم اکسل (Excel)"),
                    onTap: () {
                      Navigator.pop(context);
                      _showDirectDownloadDialog("اکسل فروشگاه", "Excel/CSV", "$serverUrl?action=export_excel");
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined, color: Colors.deepPurple),
                    title: const Text("دانلود مستقیم بک‌آپ دیتابیس (SQL)"),
                    onTap: () {
                      Navigator.pop(context);
                      _showDirectDownloadDialog("پشتیبان دیتابیس", "SQL Backup", "$serverUrl?action=backup_db");
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Text("حسابدار پرومکس موبایل", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PromaxColors.textMuted)),
                  const SizedBox(height: 2),
                  Text("نسخه $appVersion | توسعه‌دهنده: $developerName", style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
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
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0E7FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted)),
        ],
      ),
    );
  }
}

// صفحه آمار و تحلیل مالی
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
  String selectedPeriod = 'این ماه';
  String chartScale = 'روزانه';
  bool loading = true;
  Map<String, dynamic>? data;

  final List<String> periods = [
    'امروز',
    'دیروز',
    '۷ روز اخیر',
    '۳۰ روز اخیر',
    'این ماه',
    'ماه قبل',
  ];

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("$serverUrl?action=get_summary&period=${Uri.encodeComponent(selectedPeriod)}"));
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

  void _showEditBankBalanceDialog() {
    final balCtl = TextEditingController(text: formatToman(data?['bank_balance'] ?? 0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تنظیم موجودی کارت‌های بانکی"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("موجودی نقدی واقعی کارت‌های خود را وارد کنید:", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: balCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
              decoration: const InputDecoration(labelText: "موجودی کارت (تومان)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final cleanBal = int.tryParse(balCtl.text.replaceAll(',', '')) ?? 0;
              await http.post(
                Uri.parse("$serverUrl?action=update_bank_balance"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"bank_balance": cleanBal}),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              loadAnalytics();
            },
            child: const Text("ذخیره موجودی"),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final descCtl = TextEditingController();
    String cat = 'اجاره مغازه';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("برداشت سود و ثبت هزینه‌ها", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: "دسته‌بندی هزینه", border: OutlineInputBorder()),
                  items: ['اجاره مغازه', 'قبوض آب/برق/گاز', 'برداشت سود شخصی', 'پیک و اسنپ', 'حقوق و شاگرد', 'متفرقه'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDialogState(() => cat = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtl, decoration: const InputDecoration(labelText: "عنوان هزینه", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: "مبلغ برداشت (تومان)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(controller: descCtl, decoration: const InputDecoration(labelText: "توضیحات (اختیاری)", border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                if (amountCtl.text.isEmpty) return;
                await http.post(
                  Uri.parse("$serverUrl?action=add_expense"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "title": titleCtl.text.isEmpty ? cat : titleCtl.text,
                    "amount": int.parse(amountCtl.text.replaceAll(',', '')),
                    "category": cat,
                    "description": descCtl.text,
                    "admin_name": widget.adminData['full_name'],
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                loadAnalytics();
              },
              child: const Text("ثبت و کسر از نقدینگی"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int bankBalance = data?['bank_balance'] ?? 0;
    final int totalLiquidity = data?['total_liquidity'] ?? (bankBalance + (data?['stock_value'] ?? 0));
    final List<dynamic> salesOrders = data?['sales_orders'] ?? [];

    return PromaxPageLayout(
      title: "گزارش‌ها و آمارها",
      adminName: widget.adminData['full_name'],
      subtitle: "مدیریت نقدینگی، کارت‌ها و عملکرد فروشگاه",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxSkeletonLoading()
          : RefreshIndicator(
              onRefresh: loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("سرمایه و نقدینگی کل فروشگاه", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(10)),
                              child: const Text("زنده و خودکار", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("${formatToman(totalLiquidity)} تومان", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24, height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("موجودی نقدی کارت‌ها:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text("${formatToman(bankBalance)} تومان", style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: "ویرایش موجودی کارت",
                                  icon: const Icon(Icons.edit_note, color: Colors.white),
                                  onPressed: _showEditBankBalanceDialog,
                                ),
                                FilledButton.icon(
                                  onPressed: _showAddExpenseDialog,
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                                  label: const Text("برداشت / هزینه", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _categoryKpi(
                          title: "موبایل ($selectedPeriod)",
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
                          title: "اکسسوری ($selectedPeriod)",
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("خریداران و تسویه‌ها ($selectedPeriod)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("${salesOrders.length} معامله", style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)),
                          ],
                        ),
                        const Divider(height: 16),
                        if (salesOrders.isEmpty)
                          const Padding(padding: EdgeInsets.all(12), child: Center(child: Text("در این بازه زمانی سفارشی ثبت نشده است", style: TextStyle(color: Colors.grey, fontSize: 11))))
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
                                        Text("روش: ${o['payment_method']} (دریافتی: ${formatToman(o['paid_amount'])} ت)", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
                                        Text(
                                          o['remaining_amount'] > 0 ? "مانده: ${formatToman(o['remaining_amount'])} ت" : "تسویه کامل",
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: o['remaining_amount'] > 0 ? Colors.red : Colors.green),
                                        ),
                                      ],
                                    ),
                                    if (o['credit_due_shamsi'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text("موعد پرداخت: ${o['credit_due_shamsi']}", style: const TextStyle(fontSize: 10, color: Colors.brown)),
                                      ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSalesAndProfitLineChart(),
                  const SizedBox(height: 16),
                  _buildBrandDonutChart(),
                  const SizedBox(height: 16),
                  _buildWeeklyBarChart(),
                  const SizedBox(height: 16),
                  _buildLowStockTable(),
                  const SizedBox(height: 16),
                  _buildRecentActivitiesAndAiSummary(),
                  const SizedBox(height: 20),
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

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: periods.map((p) {
          final isSel = selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(p, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : Colors.black87)),
              selected: isSel,
              selectedColor: PromaxColors.blueAction,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSel ? Colors.transparent : PromaxColors.fieldBorder)),
              onSelected: (_) {
                setState(() => selectedPeriod = p);
                loadAnalytics();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSalesAndProfitLineChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stacked_line_chart_rounded, color: PromaxColors.blueAction, size: 20),
                  SizedBox(width: 8),
                  Text("مقایسه فروش و سود", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Row(
                children: ['روزانه', 'هفتگی', 'ماهانه'].map((s) {
                  final isSel = chartScale == s;
                  return GestureDetector(
                    onTap: () => setState(() => chartScale = s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isSel ? PromaxColors.blueAction : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Text(s, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : PromaxColors.textMuted, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendItem("فروش", const Color(0xFF2563EB)),
              const SizedBox(width: 14),
              _legendItem("سود", const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 150, width: double.infinity, child: CustomPaint(painter: SmoothLineChartPainter())),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("۱ تا ۷", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
              Text("۸ تا ۱۴", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
              Text("۱۵ تا ۲۱", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
              Text("۲۲ تا ۲۸", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
              Text("۲۹ تا آخر", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBrandDonutChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: PromaxColors.blueAction, size: 20),
                  SizedBox(width: 8),
                  Text("فروش بر اساس برند", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Text("مشاهده همه ←", style: TextStyle(fontSize: 10.5, color: PromaxColors.blueAction, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(size: const Size(140, 140), painter: DonutChartPainter()),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("کل فروش", style: TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
                          Text("۳.۲۵B", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _brandShareRow("اپل", "۴۲٪", const Color(0xFF2563EB)),
                    _brandShareRow("سامسونگ", "۲۸٪", const Color(0xFF6366F1)),
                    _brandShareRow("شیائومی", "۱۲٪", const Color(0xFFF97316)),
                    _brandShareRow("آنر", "۶٪", const Color(0xFF06B6D4)),
                    _brandShareRow("هواوی", "۵٪", const Color(0xFFEC4899)),
                    _brandShareRow("سایر", "۷٪", const Color(0xFF94A3B8)),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _brandShareRow(String name, String percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontSize: 11)),
            ],
          ),
          Text(percent, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: PromaxColors.blueAction, size: 20),
                  SizedBox(width: 8),
                  Text("مقایسه سود و فروش (ماه جاری)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  _legendItem("فروش", const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _legendItem("سود", const Color(0xFF10B981)),
                ],
              )
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _barGroup("هفته ۱", 90, 45),
              _barGroup("هفته ۲", 110, 60),
              _barGroup("هفته ۳", 135, 75),
              _barGroup("هفته ۴", 120, 65),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barGroup(String week, double h1, double h2) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 14, height: h1, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 4),
            Container(width: 14, height: h2, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: 6),
        Text(week, style: const TextStyle(fontSize: 9.5, color: PromaxColors.textMuted)),
      ],
    );
  }

  Widget _buildLowStockTable() {
    final items = [
      {"model": "iPhone 16 Pro 256GB", "stock": "۱", "min": "۳", "status": "نیاز به خرید", "color": Colors.red},
      {"model": "Samsung S25 Ultra 512GB", "stock": "۲", "min": "۵", "status": "نیاز به خرید", "color": Colors.red},
      {"model": "iPhone 15 128GB", "stock": "۲", "min": "۴", "status": "نیاز به خرید", "color": Colors.red},
      {"model": "AirPods Pro 2", "stock": "۳", "min": "۸", "status": "نیاز به خرید", "color": Colors.red},
      {"model": "Xiaomi 14 256GB", "stock": "۴", "min": "۱۰", "status": "نزدیک به اتمام", "color": Colors.amber.shade800},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text("کالاهای کم‌موجودی", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                ],
              ),
              Text("مشاهده همه ←", style: TextStyle(fontSize: 10.5, color: PromaxColors.blueAction, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(flex: 4, child: Text("مدل دستگاه", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted))),
              Expanded(flex: 2, child: Center(child: Text("موجودی", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted)))),
              Expanded(flex: 2, child: Center(child: Text("حداقل", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted)))),
              Expanded(flex: 3, child: Center(child: Text("وضعیت", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted)))),
            ],
          ),
          const Divider(height: 14),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(it['model'] as String, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Center(child: Text(it['stock'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text(it['min'] as String, style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)))),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(color: (it['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Center(
                          child: Text(it['status'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: it['color'] as Color)),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesAndAiSummary() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Text("تحلیل هوشمند فروش پرومکس", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF15803D))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade200, borderRadius: BorderRadius.circular(10)),
                    child: const Text("دستیار هوشمند", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "• در این ماه فروش نسبت به ماه قبل ۲۴٪ افزایش داشته است.\n• بیشترین فروش و سود مربوط به برند اپل بوده است.\n• ۵ مدل به حداقل موجودی رسیده‌اند و نیاز به شارژ انبار دارند.",
                style: TextStyle(fontSize: 11, height: 1.6, color: Color(0xFF166534)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String title, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(title, style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
      ],
    );
  }
}

class SmoothLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = const Color(0xFF2563EB)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final p2 = Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final path1 = Path();
    final path2 = Path();

    path1.moveTo(0, size.height * 0.7);
    path1.cubicTo(size.width * 0.25, size.height * 0.4, size.width * 0.4, size.height * 0.6, size.width * 0.5, size.height * 0.3);
    path1.cubicTo(size.width * 0.7, size.height * 0.8, size.width * 0.85, size.height * 0.35, size.width, size.height * 0.2);

    path2.moveTo(0, size.height * 0.85);
    path2.cubicTo(size.width * 0.25, size.height * 0.65, size.width * 0.4, size.height * 0.8, size.width * 0.5, size.height * 0.55);
    path2.cubicTo(size.width * 0.7, size.height * 0.9, size.width * 0.85, size.height * 0.6, size.width, size.height * 0.5);

    canvas.drawPath(path1, p1);
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 18;
    paint.color = const Color(0xFF2563EB);
    canvas.drawArc(rect, -1.57, 2.6, false, paint);
    paint.color = const Color(0xFF6366F1);
    canvas.drawArc(rect, 1.05, 1.7, false, paint);
    paint.color = const Color(0xFFF97316);
    canvas.drawArc(rect, 2.8, 0.7, false, paint);
    paint.color = const Color(0xFF06B6D4);
    canvas.drawArc(rect, 3.55, 0.4, false, paint);
    paint.color = const Color(0xFFEC4899);
    canvas.drawArc(rect, 4.0, 0.3, false, paint);
    paint.color = const Color(0xFF94A3B8);
    canvas.drawArc(rect, 4.35, 0.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// صفحه انبار با تفکیک تب‌های موجودی و فروخته‌شده
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
  int inventoryTabIndex = 0; // ۰: موجود در انبار | ۱: فروخته‌شده‌ها
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
    final buyerCtl = TextEditingController(text: item['buyer_name'] ?? '');
    final phoneCtl = TextEditingController(text: item['buyer_phone'] ?? '');

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
                    "buyer_name": buyerCtl.text,
                    "buyer_phone": phoneCtl.text,
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
    if (loading) return const PromaxSkeletonLoading();

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "جستجو با نام فروشنده، خریدار، کد ملی، مدل و IMEI...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("موجودی انبار")),
                    selected: inventoryTabIndex == 0,
                    selectedColor: PromaxColors.blueAction,
                    onSelected: (_) => setState(() => inventoryTabIndex = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("فروخته‌شده‌ها")),
                    selected: inventoryTabIndex == 1,
                    selectedColor: PromaxColors.greenAction,
                    onSelected: (_) => setState(() => inventoryTabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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

// صفحه خرید گوشی
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
                items: popularBrands.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
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

// صفحه فروش گوشی با تقویم شمسی موعد قرض
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

// صفحه لوازم جانبی با اسکن بارکد و ویرایش کامل
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
              TextField(controller: saleCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت فروش (تومان)")),
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

  void _showEditAccessoryDialog(Map<String, dynamic> item) {
    final nameCtl = TextEditingController(text: item['name']);
    final barcodeCtl = TextEditingController(text: item['barcode'] ?? '');
    final stockCtl = TextEditingController(text: item['stock'].toString());
    final buyCtl = TextEditingController(text: formatToman(item['buy_price']));
    final saleCtl = TextEditingController(text: formatToman(item['sale_price']));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("ویرایش کامل کالای جانبی"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام کالا")),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: barcodeCtl, decoration: const InputDecoration(labelText: "بارکد"))),
                  IconButton(icon: const Icon(Icons.qr_code_scanner, color: PromaxColors.blueAction), onPressed: () => openSafeScanner(context, (c) => barcodeCtl.text = c)),
                ],
              ),
              TextField(controller: stockCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد موجودی")),
              TextField(controller: buyCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت خرید (تومان)")),
              TextField(controller: saleCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت فروش (تومان)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              await http.post(
                Uri.parse("$serverUrl?action=update_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "id": item['id'],
                  "name": nameCtl.text,
                  "barcode": barcodeCtl.text,
                  "stock": int.parse(stockCtl.text),
                  "buy_price": int.parse(buyCtl.text.replaceAll(',', '')),
                  "sale_price": int.parse(saleCtl.text.replaceAll(',', '')),
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("ذخیره تغییرات"),
          ),
        ],
      ),
    );
  }

  void _showSellDialog(Map<String, dynamic> item) {
    final qtyCtl = TextEditingController(text: "1");
    final buyerCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("فروش سریع: ${item['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("موجودی: ${item['stock']} عدد | قیمت: ${formatToman(item['sale_price'])} ت"),
            TextField(controller: qtyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد فروش")),
            TextField(controller: buyerCtl, decoration: const InputDecoration(labelText: "نام خریدار (اختیاری)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              await http.post(
                Uri.parse("$serverUrl?action=sell_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "accessory_id": item['id'],
                  "quantity": int.parse(qtyCtl.text),
                  "buyer_name": buyerCtl.text,
                  "admin_name": widget.adminData['full_name'],
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("ثبت فروش"),
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
          ? const PromaxSkeletonLoading()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("افزودن کالای جانبی به انبار"),
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
                        subtitle: Text("موجودی: $currentStock | خرید: ${formatToman(item['buy_price'])} | فروش: ${formatToman(item['sale_price'])} ت", style: const TextStyle(fontSize: 10.5)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: () => _showEditAccessoryDialog(item)),
                            ElevatedButton(
                              onPressed: currentStock > 0 ? () => _showSellDialog(item) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white),
                              child: const Text("فروش"),
                            ),
                          ],
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
