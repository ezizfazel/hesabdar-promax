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
import 'invoice.dart';

const String serverUrl = "https://promaxmobile.ir/api.php";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PromaxApp());
}

// فرمت‌دهنده سه‌رقمی مبالغ مالی هنگام تایپ
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

String formatToman(dynamic numValue) {
  if (numValue == null) return "۰";
  return numValue.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

class PromaxColors {
  static const Color headerGradientStart = Color(0xFF092B4C);
  static const Color background = Color(0xFF0A2B4C);
  static const Color cardBackground = Colors.white;
  static const Color fieldBorder = Color(0xFFE2E8F0);
  static const Color blueAction = Color(0xFF0265FF);
  static const Color greenAction = Color(0xFF059669);
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

// ==================== اسکنر مستقل دوربین (موتور آفلاین ZXing) ====================
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
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
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
        title: const Text("اسکن بارکد IMEI"),
        backgroundColor: PromaxColors.headerGradientStart,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
        ],
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
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Text("بارکد خطی یا QR جعبه را داخل کادر بگیرید", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}

Future<void> openSafeScanner(BuildContext context, Function(String) onFound) async {
  final status = await Permission.camera.request();
  if (!status.isGranted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("دسترسی به دوربین داده نشد")));
    }
    return;
  }
  if (!context.mounted) return;
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
  );
  if (result != null && result is String) {
    onFound(result);
  }
}

// ==================== صفحه ورود ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtl = TextEditingController(text: 'admin1');
  final passCtl = TextEditingController(text: '123456');
  bool loading = false;

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
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainNavigationScreen(adminData: data['admin'])),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطا در شبکه: $e")));
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded, size: 55, color: PromaxColors.blueAction),
                const SizedBox(height: 10),
                const Text("PROMAX MOBILE", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const Text("حسابدار هوشمند موبایل و لوازم جانبی", style: TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
                const SizedBox(height: 24),
                TextField(controller: userCtl, decoration: InputDecoration(labelText: "نام کاربری", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: passCtl, obscureText: true, decoration: InputDecoration(labelText: "رمز عبور", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : login,
                  style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ورود به سامانه", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ساختار هدر و منوی سایدبار کشویی[cite: 2]
class PromaxScaffold extends StatelessWidget {
  final String title;
  final Map<String, dynamic> adminData;
  final String subtitle;
  final Widget body;

  const PromaxScaffold({
    super.key,
    required this.title,
    required this.adminData,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = adminData['role'] == 'super_admin';

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: PromaxColors.headerGradientStart),
              accountName: Text(adminData['full_name'] ?? 'مدیر'),
              accountEmail: Text(isSuperAdmin ? 'مدیر کل (Super Admin)' : 'همکار / ادمین'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: PromaxColors.blueAction,
                child: Text((adminData['full_name'] ?? 'P')[0], style: const TextStyle(color: Colors.white, fontSize: 24)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: PromaxColors.blueAction),
              title: const Text("ویرایش مشخصات و رمز عبور"),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context, adminData);
              },
            ),
            if (isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined, color: PromaxColors.greenAction),
                title: const Text("افزودن همکار/ادمین جدید"),
                subtitle: const Text("مخصوص مدیر اصلی", style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateAdminDialog(context, adminData);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: Colors.green),
              title: const Text("دانلود فایل اکسل کامل (Excel / CSV)"),
              subtitle: const Text("خروجی کلیه دستگاه‌ها، سودها و فروش", style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("جهت دانلود اکسل به آدرس promaxmobile.ir/api.php?action=export_excel در مرورگر مراجعه کنید")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined, color: PromaxColors.blueAction),
              title: const Text("دانلود پشتیبان دیتابیس (SQL Backup)"),
              subtitle: const Text("دریافت بک‌آپ کامل اطلاعات پایگاه‌داده", style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("جهت دانلود بک‌آپ به آدرس promaxmobile.ir/api.php?action=backup_db در مرورگر مراجعه کنید")),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: PromaxColors.alertText),
              title: const Text("خروج از حساب کاربری"),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("PROMAX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                            Text("Mobile", style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(scaffoldContext).openDrawer())
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        children: [
                          TextSpan(text: "(${adminData['full_name']})", style: const TextStyle(color: Color(0xFF60A5FA))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, Map<String, dynamic> admin) {
    final nameCtl = TextEditingController(text: admin['full_name']);
    final userCtl = TextEditingController(text: admin['username']);
    final passCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ویرایش مشخصات من"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام و نام خانوادگی")),
            TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
            TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: "رمز جدید (اختیاری)")),
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
                  "admin_id": admin['id'],
                  "full_name": nameCtl.text,
                  "username": userCtl.text,
                  "new_password": passCtl.text,
                }),
              );
              final d = jsonDecode(res.body);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'])));
            },
            child: const Text("ذخیره تغییرات"),
          ),
        ],
      ),
    );
  }

  void _showCreateAdminDialog(BuildContext context, Map<String, dynamic> admin) {
    final nameCtl = TextEditingController();
    final userCtl = TextEditingController();
    final passCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("افزودن همکار / ادمین جدید"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام همکار")),
            TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری")),
            TextField(controller: passCtl, decoration: const InputDecoration(labelText: "کلمه عبور")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              if (userCtl.text.isEmpty || passCtl.text.isEmpty) return;
              final res = await http.post(
                Uri.parse("$serverUrl?action=create_admin"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "requester_role": admin['role'],
                  "full_name": nameCtl.text,
                  "username": userCtl.text,
                  "password": passCtl.text,
                }),
              );
              final d = jsonDecode(res.body);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'])));
            },
            child: const Text("ثبت ادمین"),
          ),
        ],
      ),
    );
  }
}

// ناوبری اصلی برنامه
class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const MainNavigationScreen({super.key, required this.adminData});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuyPhoneScreen(adminData: widget.adminData),
      SellPhoneScreen(adminData: widget.adminData),
      InventoryAndReportsScreen(adminData: widget.adminData),
      AccessoriesScreen(adminData: widget.adminData),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.headphones_outlined, label: "لوازم جانبی", index: 3),
              _navItem(icon: Icons.bar_chart_rounded, label: "گزارشات", index: 2),
              _navItem(icon: Icons.point_of_sale_rounded, label: "فروش کالا", index: 1),
              _navItem(icon: Icons.shopping_cart_outlined, label: "خرید کالا", index: 0),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0E7FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ۱. صفحه خرید کالا ====================
class BuyPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const BuyPhoneScreen({super.key, required this.adminData});

  @override
  State<BuyPhoneScreen> createState() => _BuyPhoneScreenState();
}

class _BuyPhoneScreenState extends State<BuyPhoneScreen> {
  final imeiCtl = TextEditingController();
  final brandCtl = TextEditingController();
  final modelCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final nameCtl = TextEditingController();
  final phoneCtl = TextEditingController();
  final nIdCtl = TextEditingController();
  final descCtl = TextEditingController();
  String registryStatus = 'شرکتی';
  bool hamtaVerified = true;

  Future<void> submit() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IMEI و مبلغ خرید الزامی هستند")));
      return;
    }
    final cleanPrice = int.parse(priceCtl.text.replaceAll(',', ''));

    final res = await http.post(
      Uri.parse("$serverUrl?action=buy_phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "imei": imeiCtl.text,
        "brand": brandCtl.text,
        "model": modelCtl.text,
        "purchase_price": cleanPrice,
        "customer_name": nameCtl.text,
        "phone_number": phoneCtl.text,
        "national_id": nIdCtl.text,
        "description": descCtl.text,
        "registry_status": registryStatus,
        "hamta_verified": hamtaVerified ? 1 : 0,
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
                brand: brandCtl.text,
                model: modelCtl.text,
                imei: imeiCtl.text,
                totalPrice: cleanPrice,
                paidPrice: cleanPrice,
                remainingPrice: 0,
                paymentMethod: "نقدی",
                adminName: widget.adminData['full_name'],
                description: descCtl.text,
                registryStatus: registryStatus,
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
    return PromaxScaffold(
      title: "خرید کالای",
      adminData: widget.adminData,
      subtitle: "اطلاعات دقیق دستگاه خود را وارد کنید تا استعلام بگیرید.",
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            children: [
              Expanded(child: _buildInput(controller: imeiCtl, hint: "شناسه بارکد IMEI", prefixIcon: Icons.view_week_outlined)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => openSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(controller: brandCtl, hint: "برند", prefixIcon: Icons.local_offer_outlined),
          const SizedBox(height: 12),
          _buildInput(controller: modelCtl, hint: "مدل", prefixIcon: Icons.phone_android_outlined),
          const SizedBox(height: 12),
          _buildInput(controller: priceCtl, hint: "مبلغ خرید توافقی (تومان)", prefixIcon: Icons.monetization_on_outlined, isNumber: true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder, width: 1.2)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: registryStatus,
                isExpanded: true,
                items: ['شرکتی', 'مسافری', 'انجام شد', 'در انتظار خریدار'].map((m) => DropdownMenuItem(value: m, child: Text("وضعیت رجیستری: $m"))).toList(),
                onChanged: (v) => setState(() => registryStatus = v!),
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
          _buildInput(controller: phoneCtl, hint: "شماره تماس", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 12),
          _buildInput(controller: nIdCtl, hint: "کد ملی", prefixIcon: Icons.badge_outlined, isNumber: true),
          const SizedBox(height: 12),
          _buildInput(controller: descCtl, hint: "یادداشت و توضیحات معامله", prefixIcon: Icons.note_alt_outlined),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.blueAction, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_outlined), SizedBox(width: 8), Text("ثبت در انبار و چاپ رسید خرید", style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==================== ۲. صفحه فروش کالا ====================
class SellPhoneScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const SellPhoneScreen({super.key, required this.adminData});

  @override
  State<SellPhoneScreen> createState() => _SellPhoneScreenState();
}

class _SellPhoneScreenState extends State<SellPhoneScreen> {
  final imeiCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final paidCtl = TextEditingController();
  final buyerNameCtl = TextEditingController();
  final buyerPhoneCtl = TextEditingController();
  final descCtl = TextEditingController();
  String selectedMethod = 'نقدی';
  String registryStatus = 'انجام شد';
  bool hamtaVerified = true;

  int get remaining {
    int total = int.tryParse(priceCtl.text.replaceAll(',', '')) ?? 0;
    int paid = int.tryParse(paidCtl.text.replaceAll(',', '')) ?? 0;
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
        "buyer_name": buyerNameCtl.text.isEmpty ? "مشتری متفرقه" : buyerNameCtl.text,
        "buyer_phone": buyerPhoneCtl.text,
        "description": descCtl.text,
        "registry_status": registryStatus,
        "hamta_verified": hamtaVerified ? 1 : 0,
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
                adminName: widget.adminData['full_name'],
                description: descCtl.text,
                registryStatus: registryStatus,
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

  @override
  Widget build(BuildContext context) {
    return PromaxScaffold(
      title: "فروش کالا",
      adminData: widget.adminData,
      subtitle: "اطلاعات فروش را به درستی ثبت کنید.",
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            children: [
              Expanded(child: _buildInput(controller: imeiCtl, hint: "اسکن با درج IMEI", prefixIcon: Icons.view_week_outlined)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => openSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
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
                value: registryStatus,
                isExpanded: true,
                items: ['انجام شد', 'در انتظار خریدار', 'شرکتی', 'مسافری'].map((m) => DropdownMenuItem(value: m, child: Text("انتقال مالکیت: $m"))).toList(),
                onChanged: (v) => setState(() => registryStatus = v!),
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
                items: ['نقدی', 'قسطی', 'چکی', 'قرضی'].map((m) => DropdownMenuItem(value: m, child: Text("روش تسویه: $m"))).toList(),
                onChanged: (v) => setState(() => selectedMethod = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(controller: paidCtl, hint: "مبلغ دریافتی (پیش‌پرداخت/نقدی)", prefixIcon: Icons.payments_outlined, isNumber: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: PromaxColors.alertBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: PromaxColors.alertText, size: 20),
                const SizedBox(width: 8),
                Text("مانده طلب فروشگاه: ${formatToman(remaining)} تومان", style: const TextStyle(color: PromaxColors.alertText, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(controller: buyerNameCtl, hint: "نام خریدار", prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildInput(controller: buyerPhoneCtl, hint: "شماره تماس خریدار", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 12),
          _buildInput(controller: descCtl, hint: "یادداشت و توضیحات معامله", prefixIcon: Icons.note_alt_outlined),
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

// ==================== ۳. صفحه گزارشات و انبار گوشی ====================
class InventoryAndReportsScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const InventoryAndReportsScreen({super.key, required this.adminData});

  @override
  State<InventoryAndReportsScreen> createState() => _InventoryAndReportsScreenState();
}

class _InventoryAndReportsScreenState extends State<InventoryAndReportsScreen> {
  Map<String, dynamic>? summary;
  List<dynamic> allPhones = [];
  String searchQuery = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final resSum = await http.get(Uri.parse("$serverUrl?action=get_summary"));
      final resPhones = await http.get(Uri.parse("$serverUrl?action=get_all_phones"));
      if (resSum.statusCode == 200 && resPhones.statusCode == 200) {
        setState(() {
          summary = jsonDecode(resSum.body)['data'];
          allPhones = jsonDecode(resPhones.body)['data'];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void _showWarrantyActionDialog(Map<String, dynamic> item) {
    final reasonCtl = TextEditingController();
    final discountCtl = TextEditingController();
    String selectedAction = 'return';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("مدیریت مهلت تست ۳۰ روزه"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text("پس گرفته شده (مرجوع به انبار)"),
                value: 'return',
                groupValue: selectedAction,
                onChanged: (v) => setDialogState(() => selectedAction = v!),
              ),
              RadioListTile<String>(
                title: const Text("تخفیف داده شده بدلیل مشکل در محصول"),
                value: 'defect_discount',
                groupValue: selectedAction,
                onChanged: (v) => setDialogState(() => selectedAction = v!),
              ),
              if (selectedAction == 'defect_discount')
                TextField(
                  controller: discountCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: "مبلغ تخفیف نقص فنی (تومان)"),
                ),
              TextField(controller: reasonCtl, decoration: const InputDecoration(labelText: "دلیل / ایراد فنی اعلام‌شده")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
            FilledButton(
              onPressed: () async {
                final res = await http.post(
                  Uri.parse("$serverUrl?action=handle_warranty_action"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "phone_id": item['id'],
                    "type": selectedAction,
                    "reason": reasonCtl.text,
                    "discount_amount": int.tryParse(discountCtl.text.replaceAll(',', '')) ?? 0,
                  }),
                );
                final d = jsonDecode(res.body);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'])));
                  load();
                }
              },
              child: const Text("ثبت تغییرات مهلت تست"),
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${item['brand']} ${item['model']}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(item['status'] == 'IN_STOCK' ? 'موجود' : 'فروخته‌شده', style: const TextStyle(fontSize: 11)),
                  backgroundColor: item['status'] == 'IN_STOCK' ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                ),
              ],
            ),
            const Divider(height: 20),
            Text("سریال IMEI: ${item['imei']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("قیمت خرید: ${formatToman(item['purchase_price'])} تومان"),
            Text("فروشنده: ${item['seller_name'] ?? 'نامشخص'} (${item['seller_phone'] ?? '-'})"),
            Text("متصدی ثبت خرید: ${item['created_by_admin'] ?? 'مدیر'}"),
            if (item['description'] != null && item['description'].toString().isNotEmpty)
              Text("توضیحات: ${item['description']}", style: const TextStyle(color: PromaxColors.blueAction)),
            if (item['status'] == 'SOLD') ...[
              const Divider(height: 20),
              Text("قیمت فروش: ${formatToman(item['sale_price'])} تومان"),
              Text("سود حاصله: ${formatToman(item['profit'])} تومان", style: const TextStyle(color: PromaxColors.greenAction, fontWeight: FontWeight.bold)),
              Text("روش پرداخت: ${item['payment_method']}"),
              Text("مبلغ دریافتی: ${formatToman(item['paid_amount'])} تومان"),
              Text("مانده طلب: ${formatToman(item['remaining_amount'])} تومان", style: const TextStyle(color: PromaxColors.alertText, fontWeight: FontWeight.bold)),
              Text("خریدار: ${item['buyer_name']} (${item['buyer_phone']})"),
              Text("زمان فروش: ${item['sale_time'] ?? item['sale_date']}"),
              if (item['return_status'] != 'عادی') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text("وضعیت مهلت تست: ${item['return_status']} - دلیل: ${item['return_reason'] ?? ''}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.published_with_changes),
                label: const Text("ویرایش مهلت تست تا ۱ ماه (مرجوعی / تخفیف عیب)"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showWarrantyActionDialog(item);
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final filtered = allPhones.where((item) {
      final q = searchQuery.toLowerCase();
      return (item['imei']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['brand']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['model']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['seller_name']?.toString().toLowerCase().contains(q) ?? false) ||
          (item['buyer_name']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return PromaxScaffold(
      title: "گزارشات و انبار",
      adminData: widget.adminData,
      subtitle: "خلاصه سودآوری، آمار انبار و مطالبات فروشگاه",
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [PromaxColors.headerGradientStart, PromaxColors.blueAction]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("سود امروز (کل): ${formatToman(summary?['today_profit'])} تومان", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("سود ماه: ${formatToman(summary?['month_profit'])} ت", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("موجودی: ${summary?['stock_count']} دستگاه", style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Text("کل مطالبات: ${formatToman(summary?['total_debt'])} ت", style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "جستجو (IMEI، برند، مدل، نام مشتری...)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder)),
              ),
            ),
            const SizedBox(height: 14),
            ...filtered.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PromaxColors.fieldBorder)),
                  child: ListTile(
                    onTap: () => showDetailsModal(item),
                    leading: Icon(item['status'] == 'IN_STOCK' ? Icons.phone_android_rounded : Icons.check_circle_outline, color: item['status'] == 'IN_STOCK' ? PromaxColors.blueAction : Colors.grey),
                    title: Text("${item['brand']} ${item['model']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text("IMEI: ${item['imei']}\nطرف حساب: ${item['status'] == 'IN_STOCK' ? (item['seller_name'] ?? 'متفرقه') : (item['buyer_name'] ?? 'متفرقه')}", style: const TextStyle(fontSize: 10.5, color: PromaxColors.textMuted)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${formatToman(item['status'] == 'IN_STOCK' ? item['purchase_price'] : item['sale_price'])} ت", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(item['status'] == 'IN_STOCK' ? "موجود" : "فروخته‌شده", style: TextStyle(fontSize: 10, color: item['status'] == 'IN_STOCK' ? PromaxColors.greenAction : Colors.grey)),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ==================== ۴. بخش لوازم جانبی (اکسسوری) ====================
class AccessoriesScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const AccessoriesScreen({super.key, required this.adminData});

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

  void _showAddAccessoryDialog() {
    final nameCtl = TextEditingController();
    final catCtl = TextEditingController(text: "قاب و گلس");
    final stockCtl = TextEditingController();
    final buyCtl = TextEditingController();
    final saleCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("افزودن کالای جانبی به انبار"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام کالا (مثلاً شارژر ۲۰ وات اپل)")),
              TextField(controller: catCtl, decoration: const InputDecoration(labelText: "دسته‌بندی (شارژر، قاب، ایرپاد)")),
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
                  "category": catCtl.text,
                  "stock": int.parse(stockCtl.text),
                  "buy_price": int.parse(buyCtl.text.replaceAll(',', '')),
                  "sale_price": int.parse(saleCtl.text.replaceAll(',', '')),
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              load();
            },
            child: const Text("ثبت در انبار"),
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
            Text("موجودی در انبار: ${item['stock']} عدد"),
            Text("قیمت هر عدد: ${formatToman(item['sale_price'])} تومان"),
            TextField(controller: qtyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "تعداد فروش")),
            TextField(controller: buyerCtl, decoration: const InputDecoration(labelText: "نام خریدار (اختیاری)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("انصراف")),
          FilledButton(
            onPressed: () async {
              final res = await http.post(
                Uri.parse("$serverUrl?action=sell_accessory"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "accessory_id": item['id'],
                  "quantity": int.parse(qtyCtl.text),
                  "buyer_name": buyerCtl.text,
                  "admin_name": widget.adminData['full_name'],
                }),
              );
              final d = jsonDecode(res.body);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'])));
                load();
              }
            },
            child: const Text("ثبت فروش و کسر از انبار"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PromaxScaffold(
      title: "لوازم جانبی و اکسسوری",
      adminData: widget.adminData,
      subtitle: "مدیریت قاب، گلس، شارژر و کالاهای تعدادی بدون IMEI",
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            FilledButton.icon(
              onPressed: _showAddAccessoryDialog,
              icon: const Icon(Icons.add),
              label: const Text("افزودن کالای جانبی جدید به انبار"),
              style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (accessories.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("هیچ کالای جانبی در انبار موجود نیست")))
            else
              ...accessories.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.headphones, color: PromaxColors.blueAction)),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("موجودی: ${item['stock']} عدد | قیمت فروش: ${formatToman(item['sale_price'])} ت", style: const TextStyle(fontSize: 11)),
                      trailing: ElevatedButton(
                        onPressed: item['stock'] > 0 ? () => _showSellDialog(item) : null,
                        style: ElevatedButton.styleFrom(backgroundColor: PromaxColors.greenAction, foregroundColor: Colors.white),
                        child: const Text("فروش"),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ساخت فیلدهای ورودی گرد منطبق با طرح[cite: 2]
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.blueAction, width: 1.5)),
    ),
  );
}
