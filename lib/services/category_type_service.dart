import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class CategoryTypeService {
  static String? get _userId => ApiService.currentUserId;

  static String _getKey() {
    final userId = _userId;
    if (userId == null) return 'category_types_default';
    return 'category_types_$userId';
  }

  static Future<void> saveCategoryType(String categoryId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    final types = await getCategoryTypes();
    types[categoryId] = type;
    await prefs.setString(key, jsonEncode(types));
    print(
        '📁 Тип категории сохранен: $categoryId -> $type для пользователя $_userId');
  }

  static Future<Map<String, String>> getCategoryTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    final String? jsonString = prefs.getString(key);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }
    return Map<String, String>.from(jsonDecode(jsonString));
  }

  static Future<void> removeCategoryType(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    final types = await getCategoryTypes();
    types.remove(categoryId);
    await prefs.setString(key, jsonEncode(types));
    print('📁 Тип категории удален: $categoryId для пользователя $_userId');
  }

  // 👇 ДОБАВИТЬ ДЛЯ ВЫХОДА ИЗ АККАУНТА
  static Future<void> clearAllTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    await prefs.remove(key);
    print('📁 Все типы категорий очищены для пользователя $_userId');
  }
}
