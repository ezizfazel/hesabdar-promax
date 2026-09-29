import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
