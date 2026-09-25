import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'invoice.dart';

const String serverUrl = "https://promaxmobile.ir/api.php";

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

String formatToman(dynamic numValue) {
  if (numValue == null) return "۰";
  return numValue.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

class PromaxColors {
  static const Color headerGradientStart = Color(0xFF092B4C);
  static const Color headerGradientEnd = Color(0xFF0D4B82);
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
        scaffoldBackgroundColor: PromaxColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: PromaxColors.blueAction),
      ),
      home: const LoginScreen(),
    );
  }
}

// اسکنر ایمن با آزادسازی کامل کنترلر سخت‌افزاری دوربین
class BarcodeScannerModal extends StatefulWidget {
  final Function(String) onScanned;
  const BarcodeScannerModal({super.key, required this.onScanned});

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("بارکد یا IMEI جعبه را مقابل دوربین بگیرید", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (isDisposed) return;
                  for (final b in capture.barcodes) {
                    if (b.rawValue != null) {
                      widget.onScanned(b.rawValue!);
                      Navigator.pop(context);
                      break;
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

Future<void> launchSafeScanner(BuildContext context, Function(String) onFound) async {
  final status = await Permission.camera.request();
  if (status.isPermanentlyDenied) {
    openAppSettings();
    return;
  }
  if (!status.isGranted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اجازه دسترسی به دوربین داده نشد")));
    }
    return;
  }
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BarcodeScannerModal(onScanned: onFound),
  );
}

// صفحه ورود
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
          MaterialPageRoute(builder: (_) => MainNavigationScreen(currentAdmin: data['admin']['full_name'])),
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
                const Text("حسابدار هوشمند فروشگاه", style: TextStyle(fontSize: 12, color: PromaxColors.textMuted)),
                const SizedBox(height: 24),
                TextField(controller: userCtl, decoration: InputDecoration(labelText: "نام کاربری", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: passCtl, obscureText: true, decoration: InputDecoration(labelText: "رمز عبور", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : login,
                  style: FilledButton.styleFrom(backgroundColor: PromaxColors.blueAction, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ورود به سیستم", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ساختار هدر و بدنه مطابق تصویر ارائه‌شده[cite: 2]
class PromaxScaffold extends StatelessWidget {
  final String title;
  final String adminName;
  final String subtitle;
  final Widget body;

  const PromaxScaffold({
    super.key,
    required this.title,
    required this.adminName,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {},
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      children: [
                        TextSpan(text: "($adminName)", style: const TextStyle(color: Color(0xFF60A5FA))),
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
    );
  }
}

// ناوبری اصلی برنامه مطابق ظاهر پایین تصویر[cite: 2]
class MainNavigationScreen extends StatefulWidget {
  final String currentAdmin;
  const MainNavigationScreen({super.key, required this.currentAdmin});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuyPhoneScreen(adminName: widget.currentAdmin),
      SellPhoneScreen(adminName: widget.currentAdmin),
      InventoryAndReportsScreen(adminName: widget.currentAdmin),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.bar_chart_rounded, label: "گزارشات و انبار", index: 2),
              _navItem(icon: Icons.point_of_sale_rounded, label: "فروش کالا", index: 1),
              _navItem(icon: Icons.shopping_cart_outlined, label: "خرید از مشتری", index: 0),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? PromaxColors.blueAction : PromaxColors.textMuted,
            ),
          ),
          if (isSelected)
            Container(margin: const EdgeInsets.only(top: 3), width: 36, height: 2.5, decoration: BoxDecoration(color: PromaxColors.blueAction, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }
}

// ۱. صفحه خرید کالا
class BuyPhoneScreen extends StatefulWidget {
  final String adminName;
  const BuyPhoneScreen({super.key, required this.adminName});

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

  Future<void> submit() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IMEI و قیمت الزامی است")));
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
        "admin_name": widget.adminName,
      }),
    );

    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("پیش‌نمایش رسید رسمی")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "رسید خرید دستگاه",
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
                adminName: widget.adminName,
                description: descCtl.text,
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
      adminName: widget.adminName,
      subtitle: "اطلاعات دقیق دستگاه خود را وارد کنید تا استعلام بگیرید.",
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: imeiCtl,
                  hint: "شناسه بارکد IMEI",
                  prefixIcon: Icons.view_week_outlined,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => launchSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: PromaxColors.blueAction,
                    borderRadius: BorderRadius.circular(14),
                  ),
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
          _buildInput(
            controller: priceCtl,
            hint: "مبلغ خرید توافقی (تومان)",
            prefixIcon: Icons.monetization_on_outlined,
            isNumber: true,
          ),
          const SizedBox(height: 12),
          _buildInput(controller: nameCtl, hint: "نام فروشنده", prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildInput(controller: phoneCtl, hint: "شماره تماس", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 12),
          _buildInput(controller: nIdCtl, hint: "کد ملی", prefixIcon: Icons.badge_outlined, isNumber: true),
          const SizedBox(height: 12),
          _buildInput(controller: descCtl, hint: "یادداشت و توضیحات اختیاری", prefixIcon: Icons.note_alt_outlined),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: PromaxColors.blueAction,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_outlined, size: 20),
                SizedBox(width: 8),
                Text("ثبت در انبار و چاپ رسید خرید", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ۲. صفحه فروش کالا
class SellPhoneScreen extends StatefulWidget {
  final String adminName;
  const SellPhoneScreen({super.key, required this.adminName});

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
        "sale_time": "$timeNow - ${now.year}/${now.month}/${now.day}",
        "admin_name": widget.adminName,
      }),
    );

    final data = jsonDecode(res.body);
    if (!mounted) return;
    if (data['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("پیش‌نمایش فاکتور رسمی فروش")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "فاکتور فروش کالا",
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
                adminName: widget.adminName,
                description: descCtl.text,
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
      adminName: widget.adminName,
      subtitle: "اطلاعات فروش را به درستی ثبت کنید.",
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: imeiCtl,
                  hint: "اسکن یا درج IMEI",
                  prefixIcon: Icons.view_week_outlined,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => launchSafeScanner(context, (code) => setState(() => imeiCtl.text = code)),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: PromaxColors.blueAction,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: priceCtl,
            hint: "قیمت نهایی فروش (تومان)",
            prefixIcon: Icons.sell_outlined,
            isNumber: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PromaxColors.fieldBorder, width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMethod,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: PromaxColors.textMuted),
                items: ['نقدی', 'قسطی', 'چکی', 'قرضی'].map((m) => DropdownMenuItem(value: m, child: Text("روش تسویه: $m", style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => selectedMethod = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: paidCtl,
            hint: "مبلغ دریافتی (پیش‌پرداخت/نقدی)",
            prefixIcon: Icons.payments_outlined,
            isNumber: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: PromaxColors.alertBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: PromaxColors.alertText, size: 20),
                const SizedBox(width: 8),
                Text(
                  "مانده طلب فروشگاه: ${formatToman(remaining)} تومان",
                  style: const TextStyle(color: PromaxColors.alertText, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(controller: buyerNameCtl, hint: "نام خریدار", prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildInput(controller: buyerPhoneCtl, hint: "شماره تماس خریدار", prefixIcon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 12),
          _buildInput(controller: descCtl, hint: "یادداشت و توضیحات اختیاری معامله", prefixIcon: Icons.note_alt_outlined),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: PromaxColors.greenAction,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text("ثبت خروج از انبار و صدور فاکتور", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ۳. صفحه گزارشات و انبار جامع با فیلترها و مشاهده ریز جزئیات
class InventoryAndReportsScreen extends StatefulWidget {
  final String adminName;
  const InventoryAndReportsScreen({super.key, required this.adminName});

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

  void showDetailsModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 6),
            Text("فروشنده: ${item['seller_name'] ?? 'نامشخص'} (${item['seller_phone'] ?? '-'})"),
            const SizedBox(height: 6),
            Text("متصدی ثبت خرید: ${item['created_by_admin'] ?? 'مدیر'}"),
            if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text("توضیحات: ${item['description']}", style: const TextStyle(color: PromaxColors.blueAction)),
            ],
            if (item['status'] == 'SOLD') ...[
              const Divider(height: 20),
              Text("قیمت فروش: ${formatToman(item['sale_price'])} تومان"),
              const SizedBox(height: 6),
              Text("سود حاصله: ${formatToman(item['profit'])} تومان", style: const TextStyle(color: PromaxColors.greenAction, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("روش پرداخت: ${item['payment_method']}"),
              const SizedBox(height: 6),
              Text("مبلغ دریافتی: ${formatToman(item['paid_amount'])} تومان"),
              const SizedBox(height: 6),
              Text("مانده طلب: ${formatToman(item['remaining_amount'])} تومان", style: const TextStyle(color: PromaxColors.alertText, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("خریدار: ${item['buyer_name']} (${item['buyer_phone']})"),
              const SizedBox(height: 6),
              Text("زمان و تاریخ فروش: ${item['sale_time'] ?? item['sale_date']}"),
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
      adminName: widget.adminName,
      subtitle: "خلاصه سودآوری، آمار انبار و مطالبات فروشگاه",
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PromaxColors.headerGradientStart, PromaxColors.blueAction],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("سود امروز: ${formatToman(summary?['today_profit'])} تومان", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("سود ماه: ${formatToman(summary?['month_profit'])} ت", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("موجودی: ${summary?['stock_count']} دستگاه", style: const TextStyle(color: Colors.white, fontSize: 13)),
                      Text("کل مطالبات: ${formatToman(summary?['total_debt'])} ت", style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 13)),
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
                hintStyle: const TextStyle(fontSize: 12, color: PromaxColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: PromaxColors.textMuted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PromaxColors.fieldBorder, width: 1.2)),
              ),
            ),
            const SizedBox(height: 14),
            ...filtered.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PromaxColors.fieldBorder),
                  ),
                  child: ListTile(
                    onTap: () => showDetailsModal(item),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item['status'] == 'IN_STOCK' ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item['status'] == 'IN_STOCK' ? Icons.phone_android_rounded : Icons.check_circle_outline,
                        color: item['status'] == 'IN_STOCK' ? PromaxColors.blueAction : Colors.grey,
                      ),
                    ),
                    title: Text("${item['brand']} ${item['model']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("IMEI: ${item['imei']}\nطرف حساب: ${item['status'] == 'IN_STOCK' ? (item['seller_name'] ?? 'متفرقه') : (item['buyer_name'] ?? 'متفرقه')}", style: const TextStyle(fontSize: 11, color: PromaxColors.textMuted)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${formatToman(item['status'] == 'IN_STOCK' ? item['purchase_price'] : item['sale_price'])} ت", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(item['status'] == 'IN_STOCK' ? "موجود" : "فروخته‌شده", style: TextStyle(fontSize: 10, color: item['status'] == 'IN_STOCK' ? PromaxColors.greenAction : Colors.grey)),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ویجت فیلدهای ورودی گرد منطبق با طرح مرجع[cite: 2]
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
      hintStyle: const TextStyle(fontSize: 12, color: PromaxColors.textMuted),
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
