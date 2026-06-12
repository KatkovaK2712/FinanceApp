class AmountFormatter {
  // Форматирование для отображения (с пробелами)
  static String formatDisplay(String value) {
    if (value.isEmpty) return '';
    
    // Убираем все кроме цифр и точки
    String clean = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    if (clean.isEmpty) return '';
    
    // Добавляем пробелы между разрядами
    String result = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && (clean.length - i) % 3 == 0) {
        result += ' ';
      }
      result += clean[i];
    }
    
    return result;
  }

  // Форматирование готового числа (для отображения в списке)
  static String formatNumber(num value) {
    int intValue = value.round();
    String numberStr = intValue.toString();
    
    String result = '';
    for (int i = 0; i < numberStr.length; i++) {
      if (i > 0 && (numberStr.length - i) % 3 == 0) {
        result += ' ';
      }
      result += numberStr[i];
    }
    
    return result;
  }

  // Парсинг в double
  static double parseToDouble(String value) {
    String clean = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  // 👇 ДОБАВИТЬ ЭТОТ МЕТОД
  // Парсинг в int
  static int parseToInt(String value) {
    String clean = value.replaceAll(RegExp(r'[^\d.]'), '');
    // Если есть точка, берем только целую часть
    if (clean.contains('.')) {
      clean = clean.split('.')[0];
    }
    return int.tryParse(clean) ?? 0;
  }

  // Обработка ввода (очистка от форматирования)
  static String cleanForParse(String value) {
    return value.replaceAll(RegExp(r'[^\d.]'), '');
  }

  // Валидация ввода (только цифры)
  static String validateAndClean(String value) {
    return value.replaceAll(RegExp(r'[^\d.]'), '');
  }
}