import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shamsi_date/shamsi_date.dart';

class InvoiceHelper {
  static Future<Uint8List> createInvoice({
    required String title,
    required String personName,
    required String phone,
    required String nationalId,
    required String brand,
    required String model,
    required String imei,
    required int totalPrice,
    required int paidPrice,
    required int remainingPrice,
    required String paymentMethod,
    required String adminName,
    required String description,
    required bool isSale,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.vazirmatnRegular();
    final fontBold = await PdfGoogleFonts.vazirmatnBold();
    final now = Jalali.now();
    final timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5, color: PdfColor.fromHex("#0F4C81"))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("ساعت: $timeStr | متصدی: $adminName", style: const pw.TextStyle(fontSize: 10)),
                  pw.Column(
                    children: [
                      pw.Text("فروشگاه موبایل پرومکس ($title)", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#0F4C81"))),
                      pw.SizedBox(height: 2),
                      pw.Text("سامانه هوشمند صدور فاکتور و مبایعه‌نامه", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text("تاریخ: ${now.year}/${now.month}/${now.day}", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColor.fromHex("#0F4C81")),
              pw.SizedBox(height: 8),
              pw.Text("طرف معامله: نام: $personName | شماره تماس: $phone | کد ملی: $nationalId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("نام کالا و مدل"))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("شناسه سریال (IMEI)"))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("مبلغ کل (تومان)"))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("$brand $model"))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(imei))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(fmt(totalPrice), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              if (isSale)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.grey100,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Text("روش تسویه: $paymentMethod"),
                      pw.Text("مبلغ دریافتی: ${fmt(paidPrice)} تومان"),
                      pw.Text("مانده بدهی: ${fmt(remainingPrice)} تومان", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    ],
                  ),
                ),
              if (description.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  color: PdfColors.grey50,
                  child: pw.Text("یادداشت و توضیحات معامله: $description", style: const pw.TextStyle(fontSize: 9.5)),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Text(
                  isSale
                      ? "این برگه به منزله فاکتور رسمی تحویل دستگاه بوده و خریدار محترم با مشخصات فوق موظف به تسویه الباقی مانده بدهی در موعد مقرر می‌باشد."
                      : "فروشنده با امضای این سند تصریح می‌نماید که دستگاه فوق با شناسه IMEI ثبت‌شده متعلق به شخص وی بوده و فاقد هرگونه منع رجیستری یا گزارش سرقت می‌باشد.",
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text("امضا و اثر انگشت طرف اول"),
                  pw.Text("مهر و امضای فروشگاه پرومکس"),
                ],
              ),
              pw.SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
    return pdf.save();
  }
}
