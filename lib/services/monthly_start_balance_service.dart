import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import '../services/category_service.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class MonthlyStartBalanceService {
  static String? get _userId => ApiService.currentUserId;

  static String _getKey(int year, int month) {
    final userId = _userId;
    if (userId == null) {
      return 'start_balance_${year}_${month}_default';
    }
    return 'start_balance_${year}_${month}_$userId';
  }

  // Сохраняем баланс на ПЕРВОЕ число месяца
  static Future<void> saveStartBalance(
      int year, int month, List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(year, month);

    final Map<String, double> balances = {};
    for (var account in accounts) {
      balances[account.id] = account.balance;
    }

    await prefs.setString(key, jsonEncode(balances));
    print(
        '📊 Сохранен начальный баланс за $year.$month для пользователя $_userId: ${balances.length} счетов');
  }

  // Загружаем баланс на ПЕРВОЕ число месяца
  static Future<Map<String, double>> loadStartBalance(
      int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(year, month);
    final String? data = prefs.getString(key);

    if (data == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(data);
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  // Проверяем, нужно ли сохранить начальный баланс для нового месяца
  static Future<void> checkAndSaveStartBalance() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Проверяем, есть ли уже сохраненный баланс для этого месяца
    final existing = await loadStartBalance(now.year, now.month);
    if (existing.isNotEmpty) return;

    // Сохраняем текущие балансы как начальные для этого месяца
    final accounts = await CategoryService.loadAccounts();
    await saveStartBalance(now.year, now.month, accounts);
    print(
        '📊 Автосохранение начального баланса за ${now.year}.${now.month} для пользователя $_userId');
  }

  // 👇 ДОБАВИТЬ ДЛЯ ВЫХОДА ИЗ АККАУНТА
  static Future<void> clearAllStartBalances() async {
    final userId = _userId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (var key in keys) {
      if (key.startsWith('start_balance_') && key.endsWith('_$userId')) {
        await prefs.remove(key);
      }
    }
    print('📊 Все начальные балансы очищены для пользователя $userId');
  }
}
