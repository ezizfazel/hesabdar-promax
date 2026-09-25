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

// اتصال قطعی به دامنه شما
const String serverUrl = "https://promaxmobile.ir/api.php";

void main() {
  runApp(const PromaxApp());
}

// فرمت‌کننده خودکار ۳ رقمی در هنگام تایپ
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

class AppColors {
  static const Color primary = Color(0xFF0F4C81);
  static const Color primaryDark = Color(0xFF0A2B4C);
  static const Color background = Color(0xFFF5F8FC);
  static const Color accentGreen = Color(0xFF059669);
  static const Color accentRed = Color(0xFFDC2626);
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
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
      ),
      home: const LoginScreen(),
    );
  }
}

// صفحه لاگین
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطا در اتصال: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 60, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text("حسابدار پرومکس موبایل", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: userCtl, decoration: const InputDecoration(labelText: "نام کاربری", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: "کلمه عبور", border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : login,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ورود"),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ناوبری اصلی
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_shopping_cart), label: "خرید از مشتری"),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: "فروش کالا"),
          NavigationDestination(icon: Icon(Icons.analytics), label: "گزارشات و انبار"),
        ],
      ),
    );
  }
}

// ماژول باز کردن مطمئن دوربین و درخواست مجوز
Future<void> openSafeScanner(BuildContext context, Function(String) onFound) async {
  var status = await Permission.camera.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("لطفاً در تنظیمات گوشی دسترسی دوربین را فعال کنید")),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: 450,
      child: MobileScanner(
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            if (b.rawValue != null) {
              onFound(b.rawValue!);
              Navigator.pop(ctx);
              break;
            }
          }
        },
      ),
    ),
  );
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

  Future<void> submit() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) return;
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
            appBar: AppBar(title: const Text("فاکتور رسمی خرید")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "رسید خرید",
                personName: nameCtl.text,
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
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, title: Text("خرید کالا (${widget.adminName})")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "شناسه بارکد IMEI", border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () => openSafeScanner(context, (c) => setState(() => imeiCtl.text = c)), icon: const Icon(Icons.qr_code_scanner)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: brandCtl, decoration: const InputDecoration(labelText: "برند", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: modelCtl, decoration: const InputDecoration(labelText: "مدل", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
            controller: priceCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
            decoration: const InputDecoration(labelText: "مبلغ خرید توافقی (تومان)", border: OutlineInputBorder()),
          ),
          const Divider(height: 30),
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام فروشنده", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "شماره تماس", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: nIdCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "کد ملی", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: submit,
            icon: const Icon(Icons.save),
            label: const Text("ثبت در انبار و چاپ رسید خرید"),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}

// ۲. صفحه فروش کالا با روش‌های متنوع تسویه و مانده بدهی
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
        "buyer_name": buyerNameCtl.text.isEmpty ? "مشتری فروشگاه" : buyerNameCtl.text,
        "buyer_phone": buyerPhoneCtl.text,
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
            appBar: AppBar(title: const Text("فاکتور رسمی فروش")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createInvoice(
                title: "فاکتور فروش کالا",
                personName: buyerNameCtl.text,
                phone: buyerPhoneCtl.text,
                nationalId: "-",
                brand: "گوشی",
                model: "فروخته‌شده",
                imei: imeiCtl.text,
                totalPrice: total,
                paidPrice: paid,
                remainingPrice: total - paid,
                paymentMethod: selectedMethod,
                adminName: widget.adminName,
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
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, title: Text("فروش کالا (${widget.adminName})")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "اسکن یا درج IMEI", border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () => openSafeScanner(context, (c) => setState(() => imeiCtl.text = c)), icon: const Icon(Icons.qr_code_scanner)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: "قیمت نهایی فروش (تومان)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedMethod,
            decoration: const InputDecoration(labelText: "روش تسویه / پرداخت", border: OutlineInputBorder()),
            items: ['نقدی', 'قسطی', 'چکی', 'قرضی'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => selectedMethod = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: paidCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: "مبلغ دریافتی (پیش‌پرداخت/نقدی)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text("مانده طلب فروشگاه: ${formatToman(remaining)} تومان", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentRed)),
          ),
          const Divider(height: 30),
          TextField(controller: buyerNameCtl, decoration: const InputDecoration(labelText: "نام خریدار", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: buyerPhoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "شماره تماس خریدار", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: submit,
            icon: const Icon(Icons.check),
            label: const Text("ثبت خروج از انبار و صدور فاکتور"),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreen, minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}

// ۳. انبار جامع و گزارشات با فیلتر جستجوی چندگانه و مشاهده ریز جزئیات
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${item['brand']} ${item['model']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(item['status'] == 'IN_STOCK' ? 'موجود در انبار' : 'فروخته‌شده'),
                  backgroundColor: item['status'] == 'IN_STOCK' ? Colors.green.shade100 : Colors.grey.shade200,
                ),
              ],
            ),
            const Divider(),
            Text("شناسه بارکد IMEI: ${item['imei']}"),
            Text("قیمت خرید: ${formatToman(item['purchase_price'])} تومان"),
            Text("فروشنده کالا: ${item['seller_name'] ?? 'نامشخص'} (${item['seller_phone'] ?? '-'})"),
            Text("ثبت خرید توسط: ${item['created_by_admin'] ?? 'مدیر'}"),
            Text("زمان خرید: ${item['purchase_date']}"),
            if (item['status'] == 'SOLD') ...[
              const Divider(),
              Text("قیمت فروش: ${formatToman(item['sale_price'])} تومان"),
              Text("سود حاصله: ${formatToman(item['profit'])} تومان", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
              Text("روش پرداخت: ${item['payment_method']}"),
              Text("مبلغ دریافتی: ${formatToman(item['paid_amount'])} تومان"),
              Text("مانده بدهی: ${formatToman(item['remaining_amount'])} تومان", style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
              Text("نام خریدار: ${item['buyer_name']} (${item['buyer_phone']})"),
              Text("فروشنده متصدی: ${item['sold_by_admin']}"),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("گزارش جامع انبار و طلب‌ها"),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // کارت سود و مطالبات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("سود امروز: ${formatToman(summary?['today_profit'])} تومان", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("سود ماه: ${formatToman(summary?['month_profit'])} ت", style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("موجودی: ${summary?['stock_count']} عدد", style: const TextStyle(color: Colors.white)),
                      Text("کل طلب/مانده مشتریان: ${formatToman(summary?['total_debt'])} ت", style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "جستجو با IMEI، مدل، برند، نام خریدار یا فروشنده...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ...filtered.map((item) => Card(
                  child: ListTile(
                    onTap: () => showDetailsModal(item),
                    leading: Icon(
                      item['status'] == 'IN_STOCK' ? Icons.phone_android : Icons.check_circle,
                      color: item['status'] == 'IN_STOCK' ? AppColors.primary : Colors.grey,
                    ),
                    title: Text("${item['brand']} ${item['model']}"),
                    subtitle: Text("IMEI: ${item['imei']}\nطرف حساب: ${item['status'] == 'IN_STOCK' ? item['seller_name'] : item['buyer_name']}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${formatToman(item['status'] == 'IN_STOCK' ? item['purchase_price'] : item['sale_price'])} ت", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(item['status'] == 'IN_STOCK' ? "موجود" : "فروخته‌شده", style: TextStyle(fontSize: 10, color: item['status'] == 'IN_STOCK' ? Colors.green : Colors.grey)),
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
