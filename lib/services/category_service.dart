import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class CategoryService {
  static final List<VoidCallback> _listeners = [];
  static final List<VoidCallback> _accountsListeners = [];
  static final List<VoidCallback> _transactionListeners = [];
  // ✅ ИСПОЛЬЗУЕМ ApiService.currentUserId
  static String? get _userId => ApiService.currentUserId;

  static Future<String> _getUserIdSafe() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      print('⚠️ userId не найден, используем default_user');
      return 'default_user';
    }
    return userId;
  }

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  static void addTransactionListener(VoidCallback listener) {
    _transactionListeners.add(listener);
  }

  static void removeTransactionListener(VoidCallback listener) {
    _transactionListeners.remove(listener);
  }

  static void notifyTransactionListeners() {
    for (var listener in _transactionListeners) {
      listener();
    }
  }

  static void addAccountsListener(VoidCallback listener) {
    _accountsListeners.add(listener);
  }

  static void removeAccountsListener(VoidCallback listener) {
    _accountsListeners.remove(listener);
  }

  static void notifyAccountsListeners() {
    for (var listener in _accountsListeners) {
      listener();
    }
  }

  static Future<void> saveCategories(List<Category> categories) async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_categories_$userId';

      List<Map<String, dynamic>> categoriesJson =
          categories.map((c) => c.toJson()).toList();
      await prefs.setString(key, jsonEncode(categoriesJson));
      print(
          '✅ Категории сохранены для пользователя $userId: ${categories.length} шт.');
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка сохранения категорий: $e');
    }
  }

  static Future<List<Category>> loadCategories() async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_categories_$userId';

      String? jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      List<dynamic> categoriesJson = jsonDecode(jsonString);
      List<Category> categories =
          categoriesJson.map((json) => Category.fromJson(json)).toList();
      print(
          '✅ Категории загружены для пользователя $userId: ${categories.length} шт.');
      return categories;
    } catch (e) {
      print('❌ Ошибка загрузки категорий: $e');
      return [];
    }
  }

  static Future<void> saveAccounts(List<Account> accounts) async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_accounts_$userId';

      final accountsJson = accounts.map((a) => a.toJson()).toList();
      await prefs.setString(key, jsonEncode(accountsJson));
      print(
          '✅ Счета сохранены для пользователя $userId: ${accounts.length} шт.');

      // Сохраняем настройки также с привязкой к userId
      for (var account in accounts) {
        await prefs.setBool(
            'show_${account.id}_$userId', account.showOnHomeScreen);
        await prefs.setBool('main_${account.id}_$userId', account.isMain);
        await prefs.setString(
            'type_${account.id}_$userId', account.type.toString());
      }

      notifyAccountsListeners();
    } catch (e) {
      print('❌ Ошибка сохранения счетов: $e');
    }
  }

  static Future<List<Account>> loadAccounts() async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_accounts_$userId';

      String? jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        print('📭 Нет сохраненных счетов для пользователя $userId');
        return [];
      }

      List<dynamic> accountsJson = jsonDecode(jsonString);

      // ✅ Добавить проверку на дубликаты по id
      final Map<String, Account> uniqueMap = {};
      for (var json in accountsJson) {
        final account = Account.fromJson(json);
        if (!uniqueMap.containsKey(account.id)) {
          uniqueMap[account.id] = account;
        }
      }

      List<Account> accounts = uniqueMap.values.toList();

      // Восстанавливаем настройки с привязкой к userId
      for (var account in accounts) {
        final show = prefs.getBool('show_${account.id}_$userId');
        final isMain = prefs.getBool('main_${account.id}_$userId');
        if (show != null) account.showOnHomeScreen = show;
        if (isMain != null) account.isMain = isMain;
      }

      print(
          '✅ Счета загружены для пользователя $userId: ${accounts.length} шт.');
      return accounts;
    } catch (e) {
      print('❌ Ошибка загрузки счетов: $e');
      return [];
    }
  }

  static Future<void> clearAllData() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_categories_$userId');
    await prefs.remove('user_accounts_$userId');

    // Очищаем настройки счетов
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('show_') && key.endsWith('_$userId')) {
        await prefs.remove(key);
      }
      if (key.startsWith('main_') && key.endsWith('_$userId')) {
        await prefs.remove(key);
      }
      if (key.startsWith('type_') && key.endsWith('_$userId')) {
        await prefs.remove(key);
      }
    }

    print('🗑️ Все данные категорий и счетов удалены для пользователя $userId');
  }
}
