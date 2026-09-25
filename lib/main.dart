import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';
import 'invoice.dart';

// آدرس وب‌سرویس هاست شما
const String serverUrl = "https://promaxmobile.ir/api.php";

void main() {
  runApp(const PromaxApp());
}

class AppColors {
  static const Color primary = Color(0xFF0F4C81);
  static const Color primaryLight = Color(0xFF1E88E5);
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
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// صفحه ورود ادمین‌ها (Login)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    if (userCtl.text.isEmpty || passCtl.text.isEmpty) return;
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
        final adminName = data['admin']['full_name'];
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainNavigationScreen(currentAdmin: adminName)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.accentRed, content: Text(data['message'])));
      }
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطا در برقراری ارتباط با هاست")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.shield_outlined, size: 50, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    const Text("ورود به حسابدار پرومکس", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    const Text("مدیریت هوشمند چند ادمینی مغازه", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: userCtl,
                      decoration: InputDecoration(
                        labelText: "نام کاربری ادمین",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "کلمه عبور",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ورود به سامانه", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

// ==========================================
// ناوبری اصلی برنامه
// ==========================================
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
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: "فروش سریع"),
          NavigationDestination(icon: Icon(Icons.insights), label: "داشبورد و سود"),
        ],
      ),
    );
  }
}

// ۱. خرید گوشی و درج نام ادمین ثبت‌کننده
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

  void scanBarcode() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 380,
        child: MobileScanner(
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              if (b.rawValue != null) {
                setState(() => imeiCtl.text = b.rawValue!);
                Navigator.pop(ctx);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> submitPurchase() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) return;

    final data = {
      "customer_name": nameCtl.text.isEmpty ? "مشتری متفرقه" : nameCtl.text,
      "phone_number": phoneCtl.text,
      "national_id": nIdCtl.text,
      "imei": imeiCtl.text,
      "brand": brandCtl.text,
      "model": modelCtl.text,
      "purchase_price": int.parse(priceCtl.text),
      "admin_name": widget.adminName,
    };

    final res = await http.post(
      Uri.parse("$serverUrl?action=buy_phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    final resData = jsonDecode(res.body);
    if (!mounted) return;

    if (resData['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("پیش‌نمایش و چاپ فاکتور")),
            body: PdfPreview(
              build: (format) => InvoiceHelper.createPdf(
                name: nameCtl.text,
                nId: nIdCtl.text,
                phone: phoneCtl.text,
                brand: brandCtl.text,
                model: modelCtl.text,
                imei: imeiCtl.text,
                price: int.parse(priceCtl.text),
                adminName: widget.adminName,
              ),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.accentRed, content: Text(resData['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text("خرید کالا (متصدی: ${widget.adminName})"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "بارکد یا شناسه IMEI"))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: scanBarcode, icon: const Icon(Icons.qr_code_scanner)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: brandCtl, decoration: const InputDecoration(labelText: "برند")),
          const SizedBox(height: 10),
          TextField(controller: modelCtl, decoration: const InputDecoration(labelText: "مدل")),
          const SizedBox(height: 10),
          TextField(controller: priceCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "مبلغ خرید (تومان)")),
          const Divider(height: 30),
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: "نام فروشنده")),
          const SizedBox(height: 10),
          TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "شماره تماس")),
          const SizedBox(height: 10),
          TextField(controller: nIdCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "کد ملی")),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: submitPurchase,
            icon: const Icon(Icons.print),
            label: const Text("ثبت در انبار و صدور فاکتور"),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}

// ۲. فروش گوشی با ثبت نام ادمین فروشنده
class SellPhoneScreen extends StatefulWidget {
  final String adminName;
  const SellPhoneScreen({super.key, required this.adminName});

  @override
  State<SellPhoneScreen> createState() => _SellPhoneScreenState();
}

class _SellPhoneScreenState extends State<SellPhoneScreen> {
  final imeiCtl = TextEditingController();
  final priceCtl = TextEditingController();

  void scanBarcode() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 380,
        child: MobileScanner(
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              if (b.rawValue != null) {
                setState(() => imeiCtl.text = b.rawValue!);
                Navigator.pop(ctx);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> submitSale() async {
    if (imeiCtl.text.isEmpty || priceCtl.text.isEmpty) return;

    final res = await http.post(
      Uri.parse("$serverUrl?action=sell_phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"imei": imeiCtl.text, "sale_price": int.parse(priceCtl.text), "admin_name": widget.adminName}),
    );

    final data = jsonDecode(res.body);
    if (!mounted) return;

    if (data['status'] == 'success') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("فروش ثبت شد"),
          content: Text("سود این معامله: ${data['profit']} تومان\nفروشنده: ${widget.adminName}"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("تایید"))],
        ),
      );
      imeiCtl.clear();
      priceCtl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.accentRed, content: Text(data['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text("فروش دستگاه (متصدی: ${widget.adminName})"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: imeiCtl, decoration: const InputDecoration(labelText: "اسکن بارکد IMEI"))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: scanBarcode, icon: const Icon(Icons.qr_code_scanner)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: priceCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "قیمت نهایی فروش (تومان)")),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: submitSale,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreen, minimumSize: const Size.fromHeight(50)),
              child: const Text("ثبت فروش و محاسبه سود"),
            ),
          ],
        ),
      ),
    );
  }
}

// ۳. داشبورد و مشاهده این که کدام ادمین چه خریدی انجام داده است
class InventoryAndReportsScreen extends StatefulWidget {
  final String adminName;
  const InventoryAndReportsScreen({super.key, required this.adminName});

  @override
  State<InventoryAndReportsScreen> createState() => _InventoryAndReportsScreenState();
}

class _InventoryAndReportsScreenState extends State<InventoryAndReportsScreen> {
  Map<String, dynamic>? summary;
  List<dynamic> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res1 = await http.get(Uri.parse("$serverUrl?action=get_summary"));
      final res2 = await http.get(Uri.parse("$serverUrl?action=get_inventory"));
      if (res1.statusCode == 200 && res2.statusCode == 200) {
        setState(() {
          summary = jsonDecode(res1.body)['data'];
          items = jsonDecode(res2.body)['data'];
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text("گزارشات و انبار"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text("سود امروز مغازه: ${summary?['today_profit']} تومان", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text("سود ماه: ${summary?['month_profit']} تومان", style: const TextStyle(color: Colors.white70)),
                  const Divider(color: Colors.white24),
                  Text("موجودی کل انبار: ${summary?['stock_count']} عدد دستگاه", style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("لیست گوشی‌ها و ادمین ثبت‌کننده:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_android, color: AppColors.primary),
                  title: Text("${item['brand']} ${item['model']}"),
                  subtitle: Text("IMEI: ${item['imei']}\nثبت‌شده توسط ادمین: ${item['created_by_admin'] ?? 'نامشخص'}"),
                  trailing: Text("${item['purchase_price']} ت", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
