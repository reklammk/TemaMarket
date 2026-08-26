String customerPhoneBarcodeValue(dynamic phone) {
  return (phone?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
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
