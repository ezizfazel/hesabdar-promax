import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shamsi_date/shamsi_date.dart';

class InvoiceHelper {
  static Future<Uint8List> createPdf({
    required String name,
    required String nId,
    required String phone,
    required String brand,
    required String model,
    required String imei,
    required int price,
    required String adminName,
  }) async {
    final pdf = pw.Document();
    final now = Jalali.now();
    final formattedPrice = price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColor.fromHex("#0F4C81"))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("متصدی ثبت: $adminName"),
                  pw.Text("مبایعه‌نامه رسمی خرید تلفن همراه - پرومکس", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text("تاریخ: ${now.year}/${now.month}/${now.day}"),
                ],
              ),
              pw.Divider(thickness: 1.2),
              pw.SizedBox(height: 10),
              pw.Text("مشخصات فروشنده: نام: $name | کد ملی: $nId | تلفن: $phone"),
              pw.SizedBox(height: 10),
              pw.Text("دستگاه: $brand $model | IMEI: $imei | مبلغ: $formattedPrice تومان"),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                color: PdfColors.grey200,
                child: pw.Text(
                  "تعهد قانونی: اینجانب $name صراحتاً اقرار می‌نمایم که دستگاه مذکور متعلق به اینجانب بوده و فاقد هرگونه منع قانونی یا سابقه سرقت است. کلیه مسئولیت‌های کیفری و حقوقی آتی منحصراً بر عهده اینجانب خواهد بود.",
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text("امضا و اثر انگشت فروشنده"),
                  pw.Text("مهر و امضای متصدی ($adminName)"),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
    return pdf.save();
  }
}
