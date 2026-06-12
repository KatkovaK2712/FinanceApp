import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class PeriodsService {
  static String? get _userId => ApiService.currentUserId;

  static String _getSavedPeriodsKey() {
    final userId = _userId;
    if (userId == null) return 'saved_periods_default';
    return 'saved_periods_$userId';
  }

  static String _getDefaultPeriodKey() {
    final userId = _userId;
    if (userId == null) return 'default_period_default';
    return 'default_period_$userId';
  }

  static Future<void> savePeriod(DateTimeRange range,
      {bool setAsDefault = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final periods = await getSavedPeriods();

    final periodId = DateTime.now().millisecondsSinceEpoch.toString();
    final periodData = {
      'id': periodId,
      'start': range.start.toIso8601String(),
      'end': range.end.toIso8601String(),
      'name':
          '${DateFormat('dd.MM.yyyy').format(range.start)} - ${DateFormat('dd.MM.yyyy').format(range.end)}',
    };

    periods.add(periodData);
    await prefs.setString(_getSavedPeriodsKey(), jsonEncode(periods));

    if (setAsDefault) {
      await prefs.setString(_getDefaultPeriodKey(), periodId);
    }
    print(
        '📅 Период сохранен для пользователя $_userId: ${periodData['name']}');
  }

  static Future<List<Map<String, dynamic>>> getSavedPeriods() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_getSavedPeriodsKey());
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  static Future<void> deletePeriod(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final periods = await getSavedPeriods();
    periods.removeWhere((p) => p['id'] == id);
    await prefs.setString(_getSavedPeriodsKey(), jsonEncode(periods));
    print('📅 Период удален для пользователя $_userId');
  }

  static Future<DateTimeRange?> getDefaultPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultId = prefs.getString(_getDefaultPeriodKey());
    if (defaultId == null) return null;

    final periods = await getSavedPeriods();
    final defaultPeriod =
        periods.firstWhere((p) => p['id'] == defaultId, orElse: () => {});
    if (defaultPeriod.isEmpty) return null;

    return DateTimeRange(
      start: DateTime.parse(defaultPeriod['start']),
      end: DateTime.parse(defaultPeriod['end']),
    );
  }

  // 👇 ДОБАВИТЬ ДЛЯ ВЫХОДА ИЗ АККАУНТА
  static Future<void> clearAllPeriods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getSavedPeriodsKey());
    await prefs.remove(_getDefaultPeriodKey());
    print('📅 Все периоды очищены для пользователя $_userId');
  }
}
