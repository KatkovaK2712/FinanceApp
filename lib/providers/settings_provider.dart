import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsProvider extends ChangeNotifier {
  static const String _primaryColorIndexKey = 'primary_color_index';
  static const String _budgetMethodKey = 'budget_method';
  static const String _fontScaleKey = 'font_scale';
  static const String _homeScreenSettingsKey = 'home_screen_settings';
  static const String _showMethodCardKey = 'show_method_card';
  static const String _showBudgetMethodKey = 'show_budget_method';

  int _colorIndex = 4; // Индекс фиолетового цвета (из 8 цветов)
  String _budgetMethod = '50/30/20';
  double _fontScale = 1.0;
  Map<String, bool> _homeScreenSettings = {};
  bool _showMethodCard = true;
  bool _showBudgetMethod = true;
  Map<String, String> _categoryTypes = {};

  // Доступные цвета (8 цветов)
  static const List<Color> availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  static const List<String> colorNames = [
    'Синий',
    'Красный',
    'Зеленый',
    'Оранжевый',
    'Фиолетовый',
    'Бирюзовый',
    'Розовый',
    'Индиго',
  ];

  int get colorIndex => _colorIndex;
  String get colorName => colorNames[_colorIndex];
  Color get primaryColor => availableColors[_colorIndex];
  String get budgetMethod => _budgetMethod;
  double get fontScale => _fontScale;
  double get fontSize => _fontScale * 16;
  Map<String, bool> get homeScreenSettings => _homeScreenSettings;
  bool get showMethodCard => _showMethodCard;
  bool get showBudgetMethod => _showBudgetMethod;
  Map<String, String> get categoryTypes => _categoryTypes;

  double getFontScale() => _fontScale;

  SettingsProvider() {
    _loadSettings();
  }

  // ==================== ОСНОВНЫЕ НАСТРОЙКИ ====================

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _colorIndex = prefs.getInt(_primaryColorIndexKey) ?? 4;
      _budgetMethod = prefs.getString(_budgetMethodKey) ?? '50/30/20';
      _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
      _showMethodCard = prefs.getBool(_showMethodCardKey) ?? true;
      _showBudgetMethod = prefs.getBool(_showBudgetMethodKey) ?? true;

      final String? homeSettingsJson = prefs.getString(_homeScreenSettingsKey);
      if (homeSettingsJson != null) {
        _homeScreenSettings = Map<String, bool>.from(
          jsonDecode(homeSettingsJson) as Map,
        );
      }

      final String? categoryTypesJson = prefs.getString('category_types');
      if (categoryTypesJson != null) {
        _categoryTypes =
            Map<String, String>.from(jsonDecode(categoryTypesJson));
      }

      notifyListeners();
    } catch (e) {
      print('❌ Ошибка загрузки настроек: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorIndexKey, _colorIndex);
    await prefs.setString(_budgetMethodKey, _budgetMethod);
    await prefs.setDouble(_fontScaleKey, _fontScale);
    await prefs.setBool(_showMethodCardKey, _showMethodCard);
    await prefs.setBool(_showBudgetMethodKey, _showBudgetMethod);
    await prefs.setString(
        _homeScreenSettingsKey, jsonEncode(_homeScreenSettings));
    await prefs.setString('category_types', jsonEncode(_categoryTypes));
  }

  // ==================== ЦВЕТ ====================

  Future<void> setColorIndex(int index) async {
    if (_colorIndex == index) return;
    _colorIndex = index;
    await _saveSettings();
    notifyListeners();
  }

  // 👇 ИСПРАВЛЕННЫЙ МЕТОД для profile_screen.dart
  Future<void> setPrimaryColor(Color color) async {
    final index = availableColors.indexWhere((c) => c.value == color.value);
    if (index != -1 && _colorIndex != index) {
      _colorIndex = index;
      await _saveSettings();
      notifyListeners();
    }
  }

  // ==================== БЮДЖЕТ ====================

  Future<void> setBudgetMethod(String method) async {
    if (_budgetMethod == method) return;
    _budgetMethod = method;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleShowMethodCard() async {
    _showMethodCard = !_showMethodCard;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowMethodCard(bool value) async {
    _showMethodCard = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowBudgetMethod(bool value) async {
    _showBudgetMethod = value;
    await _saveSettings();
    notifyListeners();
  }

  // ==================== ШРИФТ ====================

  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;
    _fontScale = scale;
    await _saveSettings();
    notifyListeners();
  }

  // Для обратной совместимости с profile_screen.dart
  Future<void> setFontSize(int size) async {
    final scale = size / 16.0;
    await setFontScale(scale);
  }

  // ==================== ТИПЫ КАТЕГОРИЙ ====================

  Future<void> setCategoryType(String categoryId, String type) async {
    _categoryTypes[categoryId] = type;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> loadCategoryTypes() async {
    await _loadSettings();
  }

  // ==================== НАСТРОЙКИ ГЛАВНОГО ЭКРАНА ====================

  Future<void> updateHomeScreenSetting(String accountId, bool show) async {
    _homeScreenSettings[accountId] = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateHomeScreenSettings() async {
    await _saveSettings();
    notifyListeners();
  }
}
