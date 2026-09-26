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
    required String paymentDetails,
    required String adminName,
    required String description,
    required String registryStatus,
    required bool hamtaVerified,
    required bool isSale,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.vazirmatnRegular();
    final fontBold = await PdfGoogleFonts.vazirmatnBold();
    final now = Jalali.now();
    final timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    final invoiceNumber = "PMX-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${DateTime.now().millisecond}";

    String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // هدر بالای فاکتور
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("شماره فاکتور: $invoiceNumber", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                      pw.SizedBox(height: 4),
                      pw.Text("تاریخ صدور: ${now.year}/${now.month}/${now.day}  |  ساعت: $timeStr", style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("PROMAX Mobile", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#0F4C81"))),
                    pw.Text("فروشگاه تخصصی موبایل و لوازم جانبی پرومکس", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text("پشتیبانی: promaxmobile.ir  |  متصدی: $adminName", style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // کادر مشخصات طرف حساب
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(10),
                color: PdfColors.grey50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("طرف معامله: $personName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text("شماره تماس: $phone", style: const pw.TextStyle(fontSize: 9.5)),
                  pw.Text("کد ملی: $nationalId", style: const pw.TextStyle(fontSize: 9.5)),
                  pw.Text("نوع معامله: $title", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColor.fromHex("#0F4C81"))),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // جدول اقلام کالا
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F2B48)),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("ردیف", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("نام کالا و مدل", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("برند", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("سریال IMEI", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("رجیستری / همتا", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text("مبلغ کل (تومان)", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text("۱", style: const pw.TextStyle(fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text(model, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text(brand, style: const pw.TextStyle(fontSize: 9)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text(imei, style: const pw.TextStyle(fontSize: 8.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text("$registryStatus (${hamtaVerified ? 'همتا تأیید شد' : 'در انتظار'})", style: const pw.TextStyle(fontSize: 8.5)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text(fmt(totalPrice), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // کارت وضعیت پرداخت و جمع کل فاکتور
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("وضعیت پرداخت", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                        pw.Text("روش پرداخت: $paymentMethod", style: const pw.TextStyle(fontSize: 9)),
                        if (paymentDetails.isNotEmpty)
                          pw.Text("جزئیات واریز/پوز: $paymentDetails", style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey800)),
                        pw.Text("مبلغ پرداختی: ${fmt(paidPrice)} تومان", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          "مانده حساب: ${fmt(remainingPrice)} تومان",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: remainingPrice > 0 ? PdfColors.red800 : PdfColors.green800),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex("#EFF6FF"),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromHex("#BFDBFE")),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("جمع کل فاکتور", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex("#0F4C81"))),
                        pw.Divider(color: PdfColor.fromHex("#BFDBFE"), thickness: 0.8),
                        pw.Text("مبلغ نهایی: ${fmt(totalPrice)} تومان", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex("#0F4C81"))),
                        if (description.isNotEmpty)
                          pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text("توضیحات: $description", style: const pw.TextStyle(fontSize: 8.5))),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // فوتر، بارکد QR و امضاها
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.BarcodeWidget(data: "https://promaxmobile.ir/verify?imei=$imei", barcode: pw.Barcode.qrCode(), width: 44, height: 44),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        pw.Text("اسکن کد QR", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.Text("جهت استعلام اصالت فاکتور و رجیستری", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("امضا و اثر انگشت طرف اول", style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 25),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("مهر و امضای فروشگاه پرومکس", style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 25),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
