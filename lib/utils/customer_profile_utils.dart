String customerPhoneBarcodeValue(dynamic phone) {
  return (phone?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
}

/// 17 haneli Tema Avantaj Kart Numarası Üretici:
/// Başta 7 hane 9 (9999999) + 10 haneli telefon numarası.
/// Örn: 0537 266 80 92 -> 99999995372668092
String temaAvantajCardNumber(dynamic phone) {
  if (phone == null) return '';
  var digits = phone.toString().replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length >= 10) {
    digits = digits.substring(digits.length - 10);
    return '9999999$digits';
  }
  if (digits.isEmpty) return '';
  return '9999999${digits.padLeft(10, '0')}';
}

/// Kart numarasını okunabilir bloklara ayırır:
/// 9999999 537 266 8092
String formatTemaAvantajCardNumber(String cardNumber) {
  if (cardNumber.length < 17) return cardNumber;
  final prefix = cardNumber.substring(0, 7);
  final p1 = cardNumber.substring(7, 10);
  final p2 = cardNumber.substring(10, 13);
  final p3 = cardNumber.substring(13);
  return '$prefix $p1 $p2 $p3';
}

Set<String> parseDiscountPreferences(dynamic value) {
  if (value is! List) return <String>{};

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(12)
      .toSet();
}

