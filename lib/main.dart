import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'invoice.dart';

const String serverUrl = String.fromEnvironment("API_URL", defaultValue: "https://promaxmobile.ir/api.php");
const String appVersion = "2.8.0";
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
  Api.loginScreenBuilder = () => const LoginScreen();
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

const List<String> _jalaliMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

/// تبدیل تاریخ میلادی سرور (مثل "2026-11-24 22:32:37") به شمسی خوانا: "۳ آذر ۱۴۰۵ - 22:32"
String formatShamsi(dynamic raw, {bool withTime = true}) {
  if (raw == null) return '-';
  final text = raw.toString().trim();
  if (text.isEmpty) return '-';
  final dt = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (dt == null) return text;
  final j = Jalali.fromDateTime(dt);
  final date = '${j.day} ${_jalaliMonths[j.month - 1]} ${j.year}';
  if (!withTime || (dt.hour == 0 && dt.minute == 0 && !text.contains(':'))) return date;
  final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '$date - $time';
}

class PromaxColors {
  static const Color headerGradientStart = Color(0xFF0B1220);
  static const Color headerGradientEnd = Color(0xFF1E3A8A);
  static const Color background = Color(0xFF0B1220);
  // پس‌زمینه‌ی روشن بدنه‌ی صفحات؛ کارت‌های سفید روی آن برجسته دیده می‌شوند
  static const Color cardBackground = Color(0xFFF4F6FB);
  static const Color surface = Colors.white;
  static const Color fieldBorder = Color(0xFFE2E8F0);
  static const Color blueAction = Color(0xFF2563EB);
  static const Color greenAction = Color(0xFF16A34A);
  static const Color alertBg = Color(0xFFFEE2E2);
  static const Color alertText = Color(0xFFDC2626);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}

class PromaxApp extends StatelessWidget {
  const PromaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابدار پرومکس',
      navigatorKey: Api.navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(),
      home: const LoginScreen(),
    );
  }
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PromaxColors.blueAction,
    primary: PromaxColors.blueAction,
    surface: PromaxColors.surface,
  );
  final radius = BorderRadius.circular(14);
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Vazirmatn',
    colorScheme: scheme,
    scaffoldBackgroundColor: PromaxColors.background,
    textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Vazirmatn',
          bodyColor: PromaxColors.textMain,
          displayColor: PromaxColors.textMain,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      labelStyle: const TextStyle(color: PromaxColors.textMuted, fontSize: 13),
      prefixIconColor: const Color(0xFF94A3B8),
      suffixIconColor: const Color(0xFF94A3B8),
      border: border(PromaxColors.fieldBorder),
      enabledBorder: border(PromaxColors.fieldBorder),
      focusedBorder: border(PromaxColors.blueAction, 1.6),
      errorBorder: border(PromaxColors.alertText),
      focusedErrorBorder: border(PromaxColors.alertText, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: const BorderSide(color: PromaxColors.fieldBorder),
        textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold, color: PromaxColors.textMain),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PromaxColors.fieldBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PromaxColors.textMain,
      contentTextStyle: const TextStyle(fontFamily: 'Vazirmatn', color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFEEF2F7), thickness: 1),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    drawerTheme: const DrawerThemeData(surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: PromaxColors.blueAction),
  );
}

/// انتخاب‌گر بازه‌ی زمانی مشترک بین داشبورد موبایل و اکسسوری
class PeriodSelector extends StatefulWidget {
  final List<String> periods;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  const PeriodSelector({
    super.key,
    required this.periods,
    required this.selected,
    required this.onSelected,
    this.color = PromaxColors.blueAction,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String p) => _keys.putIfAbsent(p, () => GlobalKey());

  void _revealSelected({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(widget.selected).currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant PeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in widget.periods)
            Padding(
              key: _keyFor(p),
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _chip(p),
            ),
        ],
      ),
    );
  }

  Widget _chip(String p) {
    final isSel = p == widget.selected;
    final color = widget.color;
    return GestureDetector(
      onTap: () => widget.onSelected(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? color : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: isSel ? color : PromaxColors.fieldBorder),
          boxShadow: isSel ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          p,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : PromaxColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ==================== لودینگ اختصاصی گوشی پرشونده ====================
class PromaxProgressLoading extends StatefulWidget {
  final String message;
  const PromaxProgressLoading({super.key, this.message = "در حال بارگذاری اطلاعات..."});

  @override
  State<PromaxProgressLoading> createState() => _PromaxProgressLoadingState();
}

class _PromaxProgressLoadingState extends State<PromaxProgressLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _animation = Tween<double>(begin: 0.12, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
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
          final double progress = _animation.value;
          final int percent = (progress * 100).toInt();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: PromaxColors.blueAction.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF334155), width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 24,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: 114 * progress,
                          margin: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$percent٪",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PromaxColors.headerGradientStart,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "دریافت امن اطلاعات از سرور promaxmobile.ir",
                  style: TextStyle(fontSize: 10, color: PromaxColors.textMuted),
                ),
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
  final VoidCallback? onSecurityTap;
  final int notificationCount;
  final Widget body;

  const PromaxPageLayout({
    super.key,
    required this.title,
    required this.adminName,
    required this.subtitle,
    required this.openDrawer,
    required this.onNotificationTap,
    this.onSecurityTap,
    required this.notificationCount,
    required this.body,
  });

  Widget _headerButton({required IconData icon, required VoidCallback onTap, int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: PromaxColors.background, width: 2),
                ),
                child: Text("$badge", style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold, height: 1.2)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PromaxColors.headerGradientStart, Color(0xFF13213F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("پرومکس", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.3)),
                        Text(
                          "سلام، $adminName",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  if (onSecurityTap != null) ...[
                    _headerButton(icon: Icons.admin_panel_settings_outlined, onTap: onSecurityTap!),
                    const SizedBox(width: 8),
                  ],
                  _headerButton(icon: Icons.notifications_none_rounded, onTap: onNotificationTap, badge: notificationCount),
                  const SizedBox(width: 8),
                  _headerButton(icon: Icons.menu_rounded, onTap: openDrawer),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: PromaxColors.cardBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), child: body),
              ),
            ),
          ],
        ),
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
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20),
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

// ------------------- صفحه ورود -------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;
  bool canCheckBiometrics = false;
  bool hasSavedSession = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    userCtl.dispose();
    passCtl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // نسخه‌های قبلی رمز عبور را روی گوشی ذخیره می‌کردند؛ پاکش می‌کنیم.
    await Api.purgeLegacyPassword();
    final savedUser = await Api.savedUsername();
    final savedAdmin = await Api.loadSavedAdmin();
    await _checkBiometricSupport();
    if (!mounted) return;
    setState(() {
      if (savedUser != null) userCtl.text = savedUser;
      hasSavedSession = savedAdmin != null;
    });
    if (hasSavedSession && canCheckBiometrics) {
      _biometricLogin(biometricOnly: true, silent: true);
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final bool supported = await auth.isDeviceSupported();
      final bool canCheck = await auth.canCheckBiometrics;
      canCheckBiometrics = supported && canCheck;
    } catch (_) {
      canCheckBiometrics = false;
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openMain(Map<String, dynamic> admin) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainNavigationScreen(adminData: admin)),
    );
  }

  Future<void> login() async {
    final username = userCtl.text.trim();
    final password = passCtl.text;
    if (username.isEmpty || password.isEmpty) {
      _showMessage("نام کاربری و رمز عبور را وارد کنید");
      return;
    }
    setState(() => loading = true);
    try {
      await Api.clearSession();
      final res = await Api.post(
        Uri.parse("$serverUrl?action=login"),
        body: jsonEncode({"username": username, "password": password}),
      );
      final data = jsonDecode(res.body);
      if (data is! Map || data['status'] != 'success' || data['admin'] is! Map) {
        _showMessage(data is Map && data['message'] != null ? data['message'].toString() : "ورود ناموفق بود");
        return;
      }
      final admin = Map<String, dynamic>.from(data['admin'] as Map);
      final token = data['token'];
      if (token is String && token.isNotEmpty) {
        await Api.saveSession(token: token, admin: admin, username: username);
      } else {
        // سرور هنوز توکن صادر نمی‌کند (نسخه‌ی قدیمی api.php).
        // رمز عبور ذخیره نمی‌شود، پس ورود با اثر انگشت تا به‌روزرسانی سرور غیرفعال است.
        _showMessage("هشدار: سرور هنوز از ورود امن (توکن) پشتیبانی نمی‌کند.");
      }
      passCtl.clear();
      _openMain(admin);
    } on TimeoutException {
      _showMessage("پاسخی از سرور دریافت نشد. اتصال اینترنت را بررسی کنید.");
    } catch (_) {
      _showMessage("خطا در ارتباط با سرور");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _biometricLogin({bool biometricOnly = false, bool silent = false}) async {
    final admin = await Api.loadSavedAdmin();
    if (admin == null) {
      if (!silent) _showMessage("ابتدا یک بار با نام کاربری و رمز عبور وارد شوید");
      return;
    }
    try {
      final bool authenticated = await auth.authenticate(
        localizedReason: 'ورود سریع به حسابدار پرومکس',
        options: AuthenticationOptions(biometricOnly: biometricOnly),
      );
      if (!authenticated) return;
      if (!await Api.restoreToken()) return;
      // اعتبار توکن با اولین درخواست بررسی می‌شود؛ اگر منقضی باشد سرور 401 می‌دهد
      // و Api کاربر را به صفحه‌ی ورود برمی‌گرداند.
      _openMain(admin);
    } catch (e) {
      if (!silent) _showMessage("خطا در احراز هویت بیومتریک");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [PromaxColors.headerGradientStart, Color(0xFF13213F), PromaxColors.headerGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.phone_iphone_rounded, size: 38, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "حسابدار پرومکس",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "مدیریت خرید، فروش و انبار موبایل‌فروشی",
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 12))],
                      ),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text("ورود به حساب", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text("نام کاربری و رمز عبور خود را وارد کنید", style: TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
                            const SizedBox(height: 20),
                            TextField(
                              controller: userCtl,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: "نام کاربری",
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: passCtl,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => loading ? null : login(),
                              decoration: const InputDecoration(
                                labelText: "رمز عبور",
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: loading ? null : login,
                              style: FilledButton.styleFrom(
                                backgroundColor: PromaxColors.blueAction,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text("ورود به سامانه", style: TextStyle(fontSize: 15)),
                            ),
                            if (canCheckBiometrics && hasSavedSession) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => _biometricLogin(),
                                icon: const Icon(Icons.fingerprint_rounded, color: PromaxColors.blueAction, size: 24),
                                label: const Text("ورود با اثر انگشت", style: TextStyle(color: PromaxColors.blueAction)),
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "نسخه $appVersion  •  توسعه‌دهنده: $developerName",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- ناوبری اصلی -------------------
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
      final res = await Api.get(Uri.parse("$serverUrl?action=get_notifications"));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == 'success') setState(() => notifications = d['data']);
      }
    } catch (_) {}
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: PromaxColors.blueAction),
                    SizedBox(width: 8),
                    Text("مرکز اعلان‌های هوشمند پرومکس", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text("${notifications.length} مورد معوق", style: const TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text("تمامی حساب‌ها و رجیستری‌ها تسویه هستند", style: TextStyle(color: Colors.green, fontSize: 13)))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, idx) {
                        final n = notifications[idx];
                        final isDebt = n['type'] == 'debt';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDebt ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDebt ? Colors.red.shade200 : Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(isDebt ? Icons.warning_amber_rounded : Icons.sync_alt_rounded, color: isDebt ? Colors.red : Colors.brown, size: 18),
                                  const SizedBox(width: 6),
                                  Text(n['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDebt ? Colors.red : Colors.brown)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(n['message'], style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                              if (n['buyer_phone'] != null && n['buyer_phone'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text("شماره تماس: ${n['buyer_phone']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PromaxColors.blueAction)),
                                ),
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
    final res = await Api.get(Uri.parse("$serverUrl?action=get_admins"));
    final logRes = await Api.get(Uri.parse("$serverUrl?action=get_logs"));
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
                    Tab(icon: Icon(Icons.manage_accounts), text: "مدیریت دسترسی همکاران"),
                    Tab(icon: Icon(Icons.history), text: "تاریخچه فعالیت‌ها"),
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
                              _showCreateAdminDialog(() async {
                                final r = await Api.get(Uri.parse("$serverUrl?action=get_admins"));
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
                                leading: CircleAvatar(backgroundColor: isSuper ? Colors.blue : Colors.blueGrey, child: const Icon(Icons.person, color: Colors.white)),
                                title: Text("${a['full_name']} (${a['username']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(isSuper ? "مدیر کل (دسترسی کامل)" : "دسترسی‌ها: ${perms.join('، ')}", style: const TextStyle(fontSize: 10.5)),
                                trailing: isSuper
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: "تغییر دسترسی",
                                            icon: const Icon(Icons.edit_attributes_rounded, color: PromaxColors.blueAction),
                                            onPressed: () => _editAdminPermissionsDialog(a, () async {
                                              final r = await Api.get(Uri.parse("$serverUrl?action=get_admins"));
                                              setPanelState(() => adminsList = jsonDecode(r.body)['data']);
                                            }),
                                          ),
                                          IconButton(
                                            tooltip: "حذف همکار",
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteAdminDialog(a, () async {
                                              final r = await Api.get(Uri.parse("$serverUrl?action=get_admins"));
                                              setPanelState(() => adminsList = jsonDecode(r.body)['data']);
                                            }),
                                          ),
                                        ],
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
                              subtitle: Text("${l['description']}\n${formatShamsi(l['created_at'])}", style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
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

  void _showCreateAdminDialog(VoidCallback onCreated) {
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
                const SizedBox(height: 12),
                TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
                const SizedBox(height: 12),
                TextField(controller: passCtl, decoration: const InputDecoration(labelText: "کلمه عبور")),
                const Divider(),
                const Text("بخش‌های مجاز برای این همکار:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                CheckboxListTile(title: const Text("داشبورد و آمار"), value: perms.contains('analytics'), onChanged: (v) => setDState(() => v! ? perms.add('analytics') : perms.remove('analytics'))),
                CheckboxListTile(title: const Text("خرید گوشی"), value: perms.contains('buy'), onChanged: (v) => setDState(() => v! ? perms.add('buy') : perms.remove('buy'))),
                CheckboxListTile(title: const Text("فروش گوشی"), value: perms.contains('sell'), onChanged: (v) => setDState(() => v! ? perms.add('sell') : perms.remove('sell'))),
                CheckboxListTile(title: const Text("انبار گوشی"), value: perms.contains('inventory'), onChanged: (v) => setDState(() => v! ? perms.add('inventory') : perms.remove('inventory'))),
                CheckboxListTile(title: const Text("اکسسوری"), value: perms.contains('accessories'), onChanged: (v) => setDState(() => v! ? perms.add('accessories') : perms.remove('accessories'))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                if (userCtl.text.isEmpty || passCtl.text.isEmpty) return;
                await Api.post(
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

  void _deleteAdminDialog(Map<String, dynamic> admin, VoidCallback onDeleted) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف همکار", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("آیا از حذف کامل حساب کاربری ${admin['full_name']} اطمینان دارید؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Api.post(
                Uri.parse("$serverUrl?action=delete_admin"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "requester_role": widget.adminData['role'],
                  "admin_id": admin['id'],
                  "admin_name": admin['full_name'],
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              onDeleted();
            },
            child: const Text("حذف قطعی"),
          ),
        ],
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
                await Api.post(
                  Uri.parse("$serverUrl?action=update_admin_permissions"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "requester_role": widget.adminData['role'],
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
            const SizedBox(height: 12),
            TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
            const SizedBox(height: 12),
            TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: "رمز عبور جدید (اختیاری)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final res = await Api.post(
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

    final List<Widget> accessiblePages = [
      hasAccess('analytics')
          ? AnalyticsDashboardScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: _showNotificationsSheet, onSecurityTap: isSuperAdmin ? _showAdminManagementPanel : null, notificationCount: notifications.length)
          : const Scaffold(body: Center(child: Text("شما به بخش آمار دسترسی ندارید"))),
      hasAccess('buy')
          ? BuyPhoneScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: _showNotificationsSheet, onSecurityTap: isSuperAdmin ? _showAdminManagementPanel : null, notificationCount: notifications.length)
          : const Scaffold(body: Center(child: Text("شما به بخش خرید دسترسی ندارید"))),
      hasAccess('sell')
          ? SellPhoneScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: _showNotificationsSheet, onSecurityTap: isSuperAdmin ? _showAdminManagementPanel : null, notificationCount: notifications.length)
          : const Scaffold(body: Center(child: Text("شما به بخش فروش دسترسی ندارید"))),
      hasAccess('inventory')
          ? InventoryAndReportsScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: _showNotificationsSheet, onSecurityTap: isSuperAdmin ? _showAdminManagementPanel : null, notificationCount: notifications.length)
          : const Scaffold(body: Center(child: Text("شما به بخش انبار دسترسی ندارید"))),
      hasAccess('accessories')
          ? AccessoriesScreen(adminData: widget.adminData, openDrawer: () => _scaffoldKey.currentState?.openDrawer(), onNotificationTap: _showNotificationsSheet, onSecurityTap: isSuperAdmin ? _showAdminManagementPanel : null, notificationCount: notifications.length)
          : const Scaffold(body: Center(child: Text("شما به بخش اکسسوری دسترسی ندارید"))),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: PromaxColors.cardBackground,
        shape: const RoundedRectangleBorder(
          // منو در چینش راست‌به‌چپ از سمت راست باز می‌شود؛ لبه‌ی داخلی آن سمت چپ است
          borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 28, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [PromaxColors.headerGradientStart, PromaxColors.headerGradientEnd], begin: Alignment.topRight, end: Alignment.bottomLeft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: Text(
                      _initial(widget.adminData['full_name']),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.adminData['full_name'] ?? 'مدیر پرومکس',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSuperAdmin ? "مدیر کل" : "همکار فروشگاه",
                          style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "@${widget.adminData['username'] ?? ''}",
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                children: [
                  _drawerSection("حساب کاربری"),
                  _drawerTile(
                    icon: Icons.manage_accounts_outlined,
                    color: PromaxColors.blueAction,
                    title: "ویرایش پروفایل",
                    subtitle: "تغییر نام، نام کاربری و رمز عبور",
                    onTap: () {
                      Navigator.pop(context);
                      _showEditProfileDialog();
                    },
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: 14),
                    _drawerSection("مدیریت"),
                    _drawerTile(
                      icon: Icons.admin_panel_settings_outlined,
                      color: PromaxColors.greenAction,
                      title: "همکاران و دسترسی‌ها",
                      subtitle: "افزودن همکار، تعیین دسترسی و تاریخچه‌ی فعالیت",
                      onTap: () {
                        Navigator.pop(context);
                        _showAdminManagementPanel();
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: _drawerTile(
                icon: Icons.logout_rounded,
                color: PromaxColors.alertText,
                title: "خروج از حساب",
                danger: true,
                onTap: () async {
                  await Api.logout(serverUrl);
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "حسابدار پرومکس  •  نسخه $appVersion",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
      ),
      body: accessiblePages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: PromaxColors.fieldBorder)),
        ),
        child: SafeArea(
          top: false,
          // در چینش راست‌به‌چپ اولین آیتم (آمار) در سمت راست قرار می‌گیرد
          child: Row(
            children: [
              _navItem(icon: Icons.insights_rounded, label: "آمار مالی", index: 0),
              _navItem(icon: Icons.add_shopping_cart_rounded, label: "خرید", index: 1),
              _navItem(icon: Icons.point_of_sale_rounded, label: "فروش", index: 2),
              _navItem(icon: Icons.inventory_2_outlined, label: "انبار", index: 3),
              _navItem(icon: Icons.headphones_outlined, label: "جانبی", index: 4),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(dynamic name) {
    final n = (name ?? '').toString().trim();
    return n.isEmpty ? 'پ' : n.characters.first;
  }

  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: danger ? const Color(0xFFFEF2F2) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: danger ? const Color(0xFFFECACA) : PromaxColors.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: danger ? color : PromaxColors.textMain)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)),
                    ],
                  ],
                ),
              ),
              if (!danger) const Icon(Icons.chevron_left_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? PromaxColors.blueAction : const Color(0xFF94A3B8);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8EFFE) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ------------------- داشبورد آمار مالی کامل و تفکیک‌شده بخش موبایل -------------------
class AnalyticsDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSecurityTap;
  final int notificationCount;

  const AnalyticsDashboardScreen({
    super.key,
    required this.adminData,
    required this.openDrawer,
    required this.onNotificationTap,
    this.onSecurityTap,
    required this.notificationCount,
  });

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
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
  bool hasError = false;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    setState(() {
      loading = true;
      hasError = false;
    });

    final key = periodKeys[selectedPeriodTitle] ?? 'this_month';
    try {
      final res = await Api.get(Uri.parse("$serverUrl?action=get_summary&period=$key")).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        if (parsed['status'] == 'success') {
          setState(() {
            data = parsed['data'];
            loading = false;
          });
          return;
        }
      }
      setState(() {
        loading = false;
        hasError = true;
      });
    } catch (_) {
      setState(() {
        loading = false;
        hasError = true;
      });
    }
  }

  void _showPayDebtDialog(Map<String, dynamic> debtor) {
    final payCtl = TextEditingController(text: formatToman(debtor['remaining_amount']));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("ثبت تسویه بدهی: ${debtor['buyer_name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("دستگاه: ${debtor['brand']} ${debtor['model']}", style: const TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
            const SizedBox(height: 4),
            Text("مانده بدهی فعلی: ${formatToman(debtor['remaining_amount'])} تومان", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            TextField(
              controller: payCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
              decoration: const InputDecoration(labelText: "مبلغ دریافتی (تومان)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PromaxColors.greenAction),
            onPressed: () async {
              final int cleanPay = int.tryParse(payCtl.text.replaceAll(',', '')) ?? 0;
              if (cleanPay <= 0) return;
              final res = await Api.post(
                Uri.parse("$serverUrl?action=pay_debt"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "phone_id": debtor['id'],
                  "amount": cleanPay,
                  "admin_name": widget.adminData['full_name'],
                }),
              );
              final d = jsonDecode(res.body);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? 'ثبت شد')));
                loadAnalytics();
              }
            },
            child: const Text("ثبت دریافت وجه"),
          ),
        ],
      ),
    );
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
              decoration: const InputDecoration(labelText: "موجودی کارت (تومان)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final cleanBal = int.tryParse(balCtl.text.replaceAll(',', '')) ?? 0;
              await Api.post(
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
                  decoration: const InputDecoration(labelText: "دسته‌‌بندی هزینه"),
                  items: ['اجاره مغازه', 'قبوض آب/برق/گاز', 'برداشت سود شخصی', 'پیک و اسنپ', 'حقوق و شاگرد', 'متفرقه'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDialogState(() => cat = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtl, decoration: const InputDecoration(labelText: "عنوان هزینه")),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: "مبلغ برداشت (تومان)"),
                ),
                const SizedBox(height: 10),
                TextField(controller: descCtl, decoration: const InputDecoration(labelText: "توضیحات (اختیاری)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                if (amountCtl.text.isEmpty) return;
                await Api.post(
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

  void _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      await launchUrl(launchUri);
    } catch (_) {}
  }

  void _showExpenseDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(item['title'] ?? 'جزئیات هزینه', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailText("دسته‌بندی:", "${item['category'] ?? 'هزینه جاری'}"),
            _detailText("مبلغ برداشت شده:", "${formatToman(item['amount'])} تومان", isBold: true, color: Colors.red),
            _detailText("ادمین ثبت‌کننده:", "${item['recorded_by'] ?? 'مدیر'}"),
            _detailText("تاریخ و ساعت ثبت:", formatShamsi(item['expense_date'])),
            const Divider(height: 18),
            const Text("توضیحات و یادداشت:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PromaxColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              (item['description'] != null && item['description'].toString().trim().isNotEmpty)
                  ? item['description']
                  : "توضیحاتی ثبت نشده است.",
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("بستن")),
        ],
      ),
    );
  }

  Widget _detailText(String title, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 11.5, color: PromaxColors.textMuted)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int bankBalance = data?['bank_balance'] ?? 0;
    final int totalLiquidity = data?['total_liquidity'] ?? 0;
    final List<dynamic> salesOrders = data?['sales_orders'] ?? [];
    final List<dynamic> debtors = data?['debtors'] ?? [];
    final List<dynamic> expenses = data?['expenses'] ?? [];
    final int totalExpenses = data?['total_expenses'] ?? 0;

    return PromaxPageLayout(
      title: "گزارش مالی موبایل",
      adminName: widget.adminData['full_name'],
      subtitle: "نقدینگی و عملکرد مالی اختصاصی موبایل",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال محاسبه زنده آمار موبایل...")
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.redAccent),
                      const SizedBox(height: 10),
                      const Text("عدم برقراری ارتباط با سرور", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 14),
                      FilledButton.icon(onPressed: loadAnalytics, icon: const Icon(Icons.refresh), label: const Text("تلاش مجدد")),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadAnalytics,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    children: [
                      PeriodSelector(
                        periods: periodKeys.keys.toList(),
                        selected: selectedPeriodTitle,
                        onSelected: (p) {
                          setState(() => selectedPeriodTitle = p);
                          loadAnalytics();
                        },
                      ),
                      const SizedBox(height: 14),

                      // کارت نقدینگی اختصاصی بخش موبایل
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
                            const Text("نقدینگی و سرمایه بخش موبایل (کارت‌ها + انبار گوشی)", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                            const SizedBox(height: 6),
                            FittedBox(fit: BoxFit.scaleDown, child: Text("${formatToman(totalLiquidity)} تومان", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                            const Divider(color: Colors.white24, height: 20),
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

                      // کارت‌های آماری فروش و سود موبایل
                      Row(
                        children: [
                          Expanded(
                            child: _statCard("فروش موبایل ($selectedPeriodTitle)", "${formatToman(data?['phone_sales'])} ت", PromaxColors.blueAction, Icons.phone_android),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard("سود موبایل ($selectedPeriodTitle)", "${formatToman(data?['phone_profit'])} ت", PromaxColors.greenAction, Icons.monetization_on_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard("موجودی انبار گوشی", "${data?['phone_stock_count']} دستگاه", Colors.indigo, Icons.inventory_2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard("ارزش ریالی انبار گوشی", "${formatToman(data?['phone_stock_value'])} ت", Colors.teal, Icons.account_balance),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // بخش برداشت سود و هزینه‌ها
                      Container(
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
                                    Icon(Icons.account_balance_wallet_outlined, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text("برداشت سود و هزینه‌های مغازه", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                  ],
                                ),
                                Text("جمع: ${formatToman(totalExpenses)} ت", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const Divider(height: 16),
                            if (expenses.isEmpty)
                              const Padding(padding: EdgeInsets.all(10), child: Center(child: Text("هزینه‌ای در این بازه ثبت نشده است", style: TextStyle(color: Colors.grey, fontSize: 11))))
                            else
                              ...expenses.map((ex) => InkWell(
                                    onTap: () => _showExpenseDetailDialog(ex),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade100),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(ex['title'] ?? 'هزینه', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                const SizedBox(height: 3),
                                                Text("${ex['recorded_by']}  •  ${formatShamsi(ex['expense_date'])}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            children: [
                                              Text("${formatToman(ex['amount'])} تومان", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // کارت اختصاصی بدهکاران با تسویه و تماس سریع
                      Container(
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
                                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text("لیست بدهکاران فروشگاه", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                  ],
                                ),
                                Text("${debtors.length} نفر", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PromaxColors.textMuted)),
                              ],
                            ),
                            const Divider(height: 16),
                            if (debtors.isEmpty)
                              const Padding(padding: EdgeInsets.all(10), child: Center(child: Text("تمامی حساب‌ها تسویه کامل هستند", style: TextStyle(color: Colors.green, fontSize: 11))))
                            else
                              ...debtors.map((d) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("${d['buyer_name']} (${d['brand']} ${d['model']})", overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(height: 3),
                                              Text("مانده: ${formatToman(d['remaining_amount'])} ت | موعد: ${d['credit_due_shamsi'] ?? '-'}", style: const TextStyle(fontSize: 10, color: Colors.brown)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Row(
                                          children: [
                                            FilledButton(
                                              onPressed: () => _showPayDebtDialog(d),
                                              style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                              child: const Text("تسویه", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              onPressed: () => _makePhoneCall(d['buyer_phone']),
                                              icon: const Icon(Icons.phone_in_talk, size: 18, color: Colors.green),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // لیست سفارش‌ها
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
                              const Padding(padding: EdgeInsets.all(12), child: Center(child: Text("معامله‌ای در این بازه ثبت نشده است", style: TextStyle(color: Colors.grey, fontSize: 11))))
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
                                            Expanded(child: Text("${o['buyer_name']} (${o['brand']} ${o['model']})", overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                            const SizedBox(width: 8),
                                            Text("${formatToman(o['sale_price'])} تومان", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: PromaxColors.blueAction)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(formatShamsi(o['sale_date']), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.blueGrey))),
                                            const SizedBox(width: 8),
                                            Text(o['remaining_amount'] > 0 ? "مانده: ${formatToman(o['remaining_amount'])} ت" : "تسویه کامل", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: o['remaining_amount'] > 0 ? Colors.red : Colors.green)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSalesTrendChart(salesOrders),
                      const SizedBox(height: 16),
                      _buildBrandShareChart(salesOrders),
                      const SizedBox(height: 16),
                      _buildPeriodSummary(salesOrders),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String title, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 4), Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ------------------- نمودارها و خلاصه (بر اساس داده‌ی واقعی دوره) -------------------

  static const List<Color> _brandColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF94A3B8),
  ];

  /// آمار روزانه: از خروجی تجمیعی سرور (daily)، یا اگر سرور قدیمی است از لیست سفارش‌ها
  List<_DayStat> _dailyStats(List<dynamic> salesOrders) => _fillMissingDays(_rawDailyStats(salesOrders));

  /// روزهای بدون فروش با صفر پر می‌شوند تا فاصله‌ی زمانی میله‌ها درست باشد
  List<_DayStat> _fillMissingDays(List<_DayStat> days) {
    if (days.length < 2) return days;
    final first = DateTime(days.first.date.year, days.first.date.month, days.first.date.day);
    final last = DateTime(days.last.date.year, days.last.date.month, days.last.date.day);
    final span = last.difference(first).inDays;
    if (span > 62) return days;
    final byKey = {for (final d in days) '${d.date.year}-${d.date.month}-${d.date.day}': d};
    final hasProfit = days.any((d) => d.profit != null);
    return [
      for (var i = 0; i <= span; i++)
        () {
          final day = DateTime(first.year, first.month, first.day + i);
          return byKey['${day.year}-${day.month}-${day.day}'] ??
              _DayStat(date: day, sales: 0, profit: hasProfit ? 0 : null, count: 0);
        }(),
    ];
  }

  List<_DayStat> _rawDailyStats(List<dynamic> salesOrders) {
    final raw = data?['daily'];
    if (raw is List) {
      return raw
          .map((e) => _DayStat(
                date: DateTime.tryParse('${e['date']}') ?? DateTime.now(),
                sales: (e['sales'] as num?)?.toInt() ?? 0,
                profit: (e['profit'] as num?)?.toInt(),
                count: (e['count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }
    final Map<String, _DayStat> byDay = {};
    for (final o in salesOrders) {
      final dt = DateTime.tryParse('${o['sale_date']}'.replaceFirst(' ', 'T'));
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      final prev = byDay[key];
      byDay[key] = _DayStat(
        date: DateTime(dt.year, dt.month, dt.day),
        sales: (prev?.sales ?? 0) + ((o['sale_price'] as num?)?.toInt() ?? 0),
        profit: null,
        count: (prev?.count ?? 0) + 1,
      );
    }
    return byDay.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  }

  /// سهم برندها: از خروجی تجمیعی سرور (brands)، یا از لیست سفارش‌ها
  List<MapEntry<String, int>> _brandStats(List<dynamic> salesOrders) {
    final Map<String, int> totals = {};
    final raw = data?['brands'];
    if (raw is List) {
      for (final e in raw) {
        totals[_shortBrand(e['brand'])] = (totals[_shortBrand(e['brand'])] ?? 0) + ((e['sales'] as num?)?.toInt() ?? 0);
      }
    } else {
      for (final o in salesOrders) {
        final b = _shortBrand(o['brand']);
        totals[b] = (totals[b] ?? 0) + ((o['sale_price'] as num?)?.toInt() ?? 0);
      }
    }
    final list = totals.entries.where((e) => e.value > 0).toList()..sort((x, y) => y.value.compareTo(x.value));
    if (list.length <= 6) return list;
    final others = list.skip(5).fold<int>(0, (sum, e) => sum + e.value);
    return [...list.take(5), MapEntry('سایر', others)];
  }

  String _shortBrand(dynamic brand) {
    final b = (brand ?? '').toString().trim();
    if (b.isEmpty) return 'نامشخص';
    return b.split(' (').first.trim();
  }

  String _compactToman(num value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)} میلیارد';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} میلیون';
    return formatToman(value.toInt());
  }

  Widget _sectionCard({required IconData icon, required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PromaxColors.fieldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PromaxColors.blueAction, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyChart(String text) {
    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: PromaxColors.cardBackground, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
    );
  }

  Widget _buildSalesTrendChart(List<dynamic> salesOrders) {
    final days = _dailyStats(salesOrders);
    final hasProfit = days.any((d) => d.profit != null);
    final maxVal = days.fold<int>(0, (m, d) => d.sales > m ? d.sales : m);

    return _sectionCard(
      icon: Icons.bar_chart_rounded,
      title: "روند فروش روزانه",
      trailing: Row(
        children: [
          _legendItem("فروش", const Color(0xFF93C5FD)),
          if (hasProfit) ...[
            const SizedBox(width: 10),
            _legendItem("سود", const Color(0xFF10B981)),
          ],
        ],
      ),
      child: days.isEmpty || maxVal == 0
          ? _emptyChart("در این بازه فروشی ثبت نشده است")
          : Column(
              children: [
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Expanded(
                          child: Tooltip(
                            message: "${formatShamsi(d.date.toIso8601String(), withTime: false)}\nفروش: ${formatToman(d.sales)} ت"
                                "${d.profit != null ? '\nسود: ${formatToman(d.profit)} ت' : ''}",
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: days.length > 15 ? 1 : 3),
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    height: 140 * d.sales / maxVal,
                                    decoration: BoxDecoration(color: const Color(0xFF93C5FD), borderRadius: BorderRadius.circular(4)),
                                  ),
                                  if (d.profit != null && d.profit! > 0)
                                    Container(
                                      height: 140 * (d.profit! / maxVal).clamp(0.0, 1.0),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Text(
                          (days.length <= 10 || i % 5 == 0 || i == days.length - 1) ? '${Jalali.fromDateTime(days[i].date).day}' : '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9.5, color: PromaxColors.textMuted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${formatShamsi(days.first.date.toIso8601String(), withTime: false)}  تا  ${formatShamsi(days.last.date.toIso8601String(), withTime: false)}",
                  style: const TextStyle(fontSize: 10, color: PromaxColors.textMuted),
                ),
              ],
            ),
    );
  }

  Widget _buildBrandShareChart(List<dynamic> salesOrders) {
    final brands = _brandStats(salesOrders);
    final total = brands.fold<int>(0, (s, e) => s + e.value);

    return _sectionCard(
      icon: Icons.pie_chart_outline_rounded,
      title: "سهم برندها از فروش",
      child: brands.isEmpty
          ? _emptyChart("در این بازه فروشی ثبت نشده است")
          : Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: DonutChartPainter(
                          values: brands.map((e) => e.value.toDouble()).toList(),
                          colors: _brandColors,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("کل فروش", style: TextStyle(fontSize: 10, color: PromaxColors.textMuted)),
                          Text(_compactToman(total), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < brands.length; i++)
                        _brandShareRow(
                          brands[i].key,
                          "${(brands[i].value * 100 / total).round()}٪",
                          _brandColors[i % _brandColors.length],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _brandShareRow(String name, String percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          Text(percent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary(List<dynamic> salesOrders) {
    final days = _dailyStats(salesOrders);
    final count = days.fold<int>(0, (s, d) => s + d.count);
    final int sales = data?['phone_sales'] ?? 0;
    final int profit = data?['phone_profit'] ?? 0;
    final brands = _brandStats(salesOrders);
    final bestDay = days.isEmpty ? null : (days.toList()..sort((a, b) => b.sales.compareTo(a.sales))).first;

    final rows = <MapEntry<String, String>>[
      MapEntry("تعداد دستگاه فروخته‌شده", "$count دستگاه"),
      if (count > 0) MapEntry("میانگین مبلغ هر فروش", "${formatToman(sales ~/ count)} ت"),
      if (count > 0) MapEntry("میانگین سود هر دستگاه", "${formatToman(profit ~/ count)} ت"),
      if (sales > 0) MapEntry("حاشیه‌ی سود", "${(profit * 100 / sales).toStringAsFixed(1)}٪"),
      if (brands.isNotEmpty) MapEntry("پرفروش‌ترین برند", brands.first.key),
      if (bestDay != null) MapEntry("پرفروش‌ترین روز", "${formatShamsi(bestDay.date.toIso8601String(), withTime: false)} (${_compactToman(bestDay.sales)})"),
    ];

    return _sectionCard(
      icon: Icons.insights_rounded,
      title: "خلاصه‌ی دوره ($selectedPeriodTitle)",
      child: count == 0
          ? _emptyChart("در این بازه فروشی ثبت نشده است")
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(child: Text(rows[i].key, style: const TextStyle(fontSize: 12, color: PromaxColors.textMuted))),
                      Text(rows[i].value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
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

class _DayStat {
  final DateTime date;
  final int sales;
  final int? profit; // اگر سرور قدیمی باشد سود روزانه در دسترس نیست
  final int count;
  const _DayStat({required this.date, required this.sales, required this.profit, required this.count});
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final total = values.fold<double>(0, (s, v) => s + v);
    final bg = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = const Color(0xFFF1F5F9);
    canvas.drawArc(rect, 0, 6.2832, false, bg);
    if (total <= 0) return;
    const gap = 0.04;
    var start = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.2832;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, start + (values.length > 1 ? gap / 2 : 0), (sweep - (values.length > 1 ? gap : 0)).clamp(0.01, 6.2832), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString();
}

// ------------------- بخش انبار گوشی -------------------
class InventoryAndReportsScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSecurityTap;
  final int notificationCount;
  const InventoryAndReportsScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, this.onSecurityTap, required this.notificationCount});

  @override
  State<InventoryAndReportsScreen> createState() => _InventoryAndReportsScreenState();
}

class _InventoryAndReportsScreenState extends State<InventoryAndReportsScreen> {
  List<dynamic> allPhones = [];
  String searchQuery = "";
  int inventoryTabIndex = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final resPhones = await Api.get(Uri.parse("$serverUrl?action=get_all_phones"));
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

  void _deleteOrder(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف سفارش", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("آیا از حذف کامل دستگاه ${item['brand']} ${item['model']} اطمینان دارید؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Api.post(
                Uri.parse("$serverUrl?action=delete_phone"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"phone_id": item['id'], "admin_name": widget.adminData['full_name']}),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("حذف قطعی"),
          ),
        ],
      ),
    );
  }

  void _showChangeRegistryDialog(Map<String, dynamic> item) {
    String currentReg = item['registry_status'] ?? registryOptions[0];
    bool verified = item['hamta_verified'] == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("تغییر وضعیت انتقال رجیستری"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: currentReg,
                decoration: const InputDecoration(labelText: "وضعیت رجیستری"),
                items: registryOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setDState(() => currentReg = v!),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: verified,
                title: const Text("تست اصالت و همتا انجام شد", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onChanged: (v) => setDState(() => verified = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                await Api.post(
                  Uri.parse("$serverUrl?action=update_registry_status"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "phone_id": item['id'],
                    "registry_status": currentReg,
                    "hamta_verified": verified ? 1 : 0,
                    "admin_name": widget.adminData['full_name'],
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                load();
              },
              child: const Text("ذخیره تغییرات"),
            ),
          ],
        ),
      ),
    );
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
                  decoration: const InputDecoration(labelText: "برند دستگاه"),
                  items: popularBrands.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setDState(() => selectedBrand = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: modelCtl, decoration: const InputDecoration(labelText: "مدل دستگاه")),
                const SizedBox(height: 10),
                TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "IMEI 1")),
                const SizedBox(height: 10),
                TextField(controller: imei2Ctl, decoration: const InputDecoration(labelText: "IMEI 2")),
                const SizedBox(height: 10),
                TextField(controller: priceCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "مبلغ (تومان)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                await Api.post(
                  Uri.parse("$serverUrl?action=update_order"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "phone_id": item['id'],
                    "brand": selectedBrand,
                    "model": modelCtl.text,
                    "imei": imeiCtl.text,
                    "imei2": imei2Ctl.text,
                    "price": int.tryParse(priceCtl.text.replaceAll(',', '')) ?? 0,
                    "admin_name": widget.adminData['full_name'],
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
              _row("ادمین ثبت خرید:", "${item['created_by_admin'] ?? 'مدیر اصلی'}"),
              _row("زمان ثبت خرید:", "${item['entry_time'] ?? item['purchase_date']}"),
              _row("نام فروشنده:", "${item['seller_name'] ?? 'متفرقه'}"),
              _row("شماره تماس فروشنده:", "${item['seller_phone'] ?? '-'}"),
              _row("کد ملی فروشنده:", "${item['seller_nid'] ?? '-'}"),
              _row("قیمت خرید:", "${formatToman(item['purchase_price'])} تومان"),
              _row("سریال IMEI 1:", "${item['imei']}"),
              if (item['imei2'] != null) _row("سریال IMEI 2:", "${item['imei2']}"),
              _row("وضعیت رجیستری:", "${item['registry_status']}"),
              if (item['status'] == 'SOLD') ...[
                const Divider(),
                _row("ادمین فروشنده:", "${item['sold_by_admin'] ?? 'مدیر اصلی'}"),
                _row("نام خریدار:", "${item['buyer_name']} (${item['buyer_phone']})"),
                _row("قیمت فروش:", "${formatToman(item['sale_price'])} تومان"),
                _row("روش تسویه:", "${item['payment_method']}"),
                _row("مانده طلب:", "${formatToman(item['remaining_amount'])} تومان"),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showChangeRegistryDialog(item);
                      },
                      icon: const Icon(Icons.sync_alt, size: 16),
                      label: const Text("تغییر رجیستری", style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditOrderDialog(item);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("ویرایش کالا", style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteOrder(item);
                },
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text("حذف قطعی سفارش از انبار"),
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
      title: "انبار موبایل",
      adminName: widget.adminData['full_name'],
      subtitle: "تفکیک کامل موجودی‌ها و دستگاه‌های فروخته‌شده",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال دریافت اقلام انبار...")
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "جستجو با مدل، سریال، نام فروشنده یا خریدار...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder)),
                    ),
                  ),
                ),
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
                          subtitle: Text("ادمین ثبت: ${item['created_by_admin'] ?? 'مدیر'}\nفروشنده: ${item['seller_name'] ?? 'متفرقه'} | IMEI: ${item['imei']}", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
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

// ------------------- صفحه ثبت خرید گوشی -------------------
class BuyPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSecurityTap;
  final int notificationCount;
  const BuyPhoneScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, this.onSecurityTap, required this.notificationCount});

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

    final res = await Api.post(
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
      title: "خرید کالا",
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

// ------------------- صفحه ثبت فروش گوشی -------------------
class SellPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSecurityTap;
  final int notificationCount;
  const SellPhoneScreen({super.key, required this.adminData, required this.openDrawer, required this.onNotificationTap, this.onSecurityTap, required this.notificationCount});

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
  bool isSubmitting = false;

  int get remaining {
    int total = int.tryParse(priceCtl.text.replaceAll(',', '').trim()) ?? 0;
    int paid = int.tryParse(paidCtl.text.replaceAll(',', '').trim()) ?? total;
    return total - paid;
  }

  Future<void> submit() async {
    final String cleanImei = imeiCtl.text.trim();
    final String cleanPriceStr = priceCtl.text.replaceAll(',', '').trim();

    if (cleanImei.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("شناسه IMEI دستگاه الزامی است")),
      );
      return;
    }

    if (cleanPriceStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("مبلغ نهایی فروش را وارد کنید")),
      );
      return;
    }

    final int total = int.tryParse(cleanPriceStr) ?? 0;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("مبلغ فروش نامعتبر است")),
      );
      return;
    }

    final String cleanPaidStr = paidCtl.text.replaceAll(',', '').trim();
    final int paid = cleanPaidStr.isNotEmpty ? (int.tryParse(cleanPaidStr) ?? total) : total;

    setState(() => isSubmitting = true);

    final now = Jalali.now();
    final timeNow = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    try {
      final res = await Api.post(
        Uri.parse("$serverUrl?action=sell_phone"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "imei": cleanImei,
          "sale_price": total,
          "paid_amount": paid,
          "payment_method": selectedMethod,
          "payment_details": payDetailsCtl.text.trim(),
          "buyer_name": buyerNameCtl.text.trim().isEmpty ? "مشتری متفرقه" : buyerNameCtl.text.trim(),
          "buyer_phone": buyerPhoneCtl.text.trim(),
          "description": descCtl.text.trim(),
          "registry_status": selectedRegistry,
          "hamta_verified": hamtaVerified ? 1 : 0,
          "credit_due_shamsi": creditDueShamsi,
          "sale_time": "$timeNow - ${now.year}/${now.month}/${now.day}",
          "admin_name": widget.adminData['full_name'],
        }),
      );

      final data = jsonDecode(res.body);
      setState(() => isSubmitting = false);

      if (!mounted) return;

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فروش دستگاه با موفقیت ثبت شد")),
        );

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
                  imei: cleanImei,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "خطا در ثبت فروش کالا")),
        );
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطای ارتباط با سرور: $e")),
        );
      }
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
            onPressed: isSubmitting ? null : submit,
            style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            child: isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline), SizedBox(width: 8), Text("ثبت خروج از انبار و صدور فاکتور", style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ------------------- صفحه اکسسوری با داشبورد آمار مالی کامل و مستقل درون صفحه -------------------
class AccessoriesScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final VoidCallback openDrawer;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSecurityTap;
  final int notificationCount;

  const AccessoriesScreen({
    super.key,
    required this.adminData,
    required this.openDrawer,
    required this.onNotificationTap,
    this.onSecurityTap,
    required this.notificationCount,
  });

  @override
  State<AccessoriesScreen> createState() => _AccessoriesScreenState();
}

class _AccessoriesScreenState extends State<AccessoriesScreen> {
  final Map<String, String> periodKeys = {
    'امروز': 'today',
    'دیروز': 'yesterday',
    '۷ روز اخیر': '7days',
    '۳۰ روز اخیر': '30days',
    'این ماه': 'this_month',
    'ماه قبل': 'last_month',
  };

  String selectedPeriodTitle = 'این ماه';
  List<dynamic> accessories = [];
  String searchQuery = "";
  bool loading = true;
  Map<String, dynamic>? accSummary;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final key = periodKeys[selectedPeriodTitle] ?? 'this_month';
    try {
      final res = await Api.get(Uri.parse("$serverUrl?action=get_accessories"));
      final summaryRes = await Api.get(Uri.parse("$serverUrl?action=get_acc_summary&period=$key"));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        Map<String, dynamic>? sMap;
        if (summaryRes.statusCode == 200) {
          final s = jsonDecode(summaryRes.body);
          if (s['status'] == 'success') sMap = s['data'];
        }

        setState(() {
          accessories = d['data'] ?? [];
          accSummary = sMap;
          loading = false;
        });
      } else {
        setState(() => loading = false);
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: barcodeCtl, decoration: const InputDecoration(labelText: "بارکد (اختیاری)"))),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: PromaxColors.blueAction),
                    onPressed: () => openSafeScanner(context, (c) => barcodeCtl.text = c),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: catCtl, decoration: const InputDecoration(labelText: "دسته‌‌بندی")),
              const SizedBox(height: 12),
              TextField(controller: stockCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد موجودی")),
              const SizedBox(height: 12),
              TextField(controller: buyCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت خرید (تومان)")),
              const SizedBox(height: 12),
              TextField(controller: saleCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت فروش مصوب (تومان)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              if (nameCtl.text.isEmpty || stockCtl.text.isEmpty) return;
              await Api.post(
                Uri.parse("$serverUrl?action=add_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "name": nameCtl.text,
                  "barcode": barcodeCtl.text,
                  "category": catCtl.text,
                  "stock": int.parse(stockCtl.text),
                  "buy_price": int.parse(buyCtl.text.replaceAll(',', '')),
                  "sale_price": int.parse(saleCtl.text.replaceAll(',', '')),
                  "admin_name": widget.adminData['full_name'],
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: barcodeCtl, decoration: const InputDecoration(labelText: "بارکد"))),
                  IconButton(icon: const Icon(Icons.qr_code_scanner, color: PromaxColors.blueAction), onPressed: () => openSafeScanner(context, (c) => barcodeCtl.text = c)),
                ],
              ),
              TextField(controller: stockCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد موجودی")),
              const SizedBox(height: 12),
              TextField(controller: buyCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت خرید (تومان)")),
              const SizedBox(height: 12),
              TextField(controller: saleCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()], decoration: const InputDecoration(labelText: "قیمت فروش (تومان)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              await Api.post(
                Uri.parse("$serverUrl?action=update_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "id": item['id'],
                  "name": nameCtl.text,
                  "barcode": barcodeCtl.text,
                  "stock": int.parse(stockCtl.text),
                  "buy_price": int.parse(buyCtl.text.replaceAll(',', '')),
                  "sale_price": int.parse(saleCtl.text.replaceAll(',', '')),
                  "admin_name": widget.adminData['full_name'],
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
    final customPriceCtl = TextEditingController(text: formatToman(item['sale_price']));
    final buyerCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("فروش سریع: ${item['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("موجودی: ${item['stock']} عدد | قیمت مصوب: ${formatToman(item['sale_price'])} ت"),
            const SizedBox(height: 8),
            TextField(controller: qtyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد فروش")),
            const SizedBox(height: 8),
            TextField(
              controller: customPriceCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
              decoration: const InputDecoration(labelText: "قیمت نهایی فروش هر عدد (تومان)", helperText: "در صورت تخفیف مبلغ را تغییر دهید"),
            ),
            const SizedBox(height: 8),
            TextField(controller: buyerCtl, decoration: const InputDecoration(labelText: "نام خریدار (اختیاری)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final finalPrice = int.tryParse(customPriceCtl.text.replaceAll(',', '')) ?? item['sale_price'];
              await Api.post(
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
            child: const Text("ثبت فروش"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int accStockCount = accSummary?['acc_stock_count'] ?? 0;
    final int accStockValue = accSummary?['acc_stock_value'] ?? 0;
    final int accSales = accSummary?['acc_sales'] ?? 0;
    final int accProfit = accSummary?['acc_profit'] ?? 0;

    final filteredAccessories = accessories.where((item) {
      final q = searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      final name = (item['name'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      return name.contains(q) || barcode.contains(q) || cat.contains(q);
    }).toList();

    return PromaxPageLayout(
      title: "لوازم جانبی و اکسسوری",
      adminName: widget.adminData['full_name'],
      subtitle: "داشبورد اختصاصی و انبار کالاهای جانبی",
      openDrawer: widget.openDrawer,
      onNotificationTap: widget.onNotificationTap,
      onSecurityTap: widget.onSecurityTap,
      notificationCount: widget.notificationCount,
      body: loading
          ? const PromaxProgressLoading(message: "در حال محاسبه آمار اکسسوری...")
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PeriodSelector(
                    periods: periodKeys.keys.toList(),
                    selected: selectedPeriodTitle,
                    color: Colors.purple.shade700,
                    onSelected: (p) {
                      setState(() => selectedPeriodTitle = p);
                      load();
                    },
                  ),
                  const SizedBox(height: 12),

                  // کارت جامع نقدینگی و ارزش انبار اختصاصی اکسسوری
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF311042), Color(0xFF581C87)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("ارزش کل انبار لوازم جانبی", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.purple.shade400, borderRadius: BorderRadius.circular(10)),
                              child: Text("$accStockCount قلم موجود", style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(fit: BoxFit.scaleDown, child: Text("${formatToman(accStockValue)} تومان", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("فروش ($selectedPeriodTitle): ${formatToman(accSales)} ت", style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                            Text("سود خالص: ${formatToman(accProfit)} ت", style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    decoration: InputDecoration(
                      hintText: "جستجوی کالا بر اساس نام یا بارکد...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: PromaxColors.blueAction),
                        onPressed: () => openSafeScanner(context, (code) {
                          setState(() => searchQuery = code);
                        }),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("افزودن کالای جانبی جدید"),
                    style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                  const SizedBox(height: 14),

                  if (filteredAccessories.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("کالایی با این مشخصات یافت نشد", style: TextStyle(color: Colors.grey))))
                  else
                    ...filteredAccessories.map((item) {
                      final int currentStock = int.tryParse(item['stock']?.toString() ?? '0') ?? 0;
                      final String barcode = (item['barcode'] != null && item['barcode'].toString().isNotEmpty) ? " | بارکد: ${item['barcode']}" : "";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFF3E8FF), child: Icon(Icons.headphones, color: Colors.purple)),
                          title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("موجودی: $currentStock عدد | فروش: ${formatToman(item['sale_price'])} ت$barcode", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: () => _showEditAccessoryDialog(item)),
                              ElevatedButton(
                                onPressed: currentStock > 0 ? () => _showSellDialog(item) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
