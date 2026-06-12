import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'category_service.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class GoalService {
  static String? get _userId => ApiService.currentUserId;

  static Future<String> _getUserIdSafe() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      print('⚠️ userId не найден, используем default_user');
      return 'default_user';
    }
    return userId;
  }

  static Future<void> saveGoals(List<Goal> goals) async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_goals_$userId';

      List<Map<String, dynamic>> goalsJson =
          goals.map((g) => g.toJson()).toList();
      await prefs.setString(key, jsonEncode(goalsJson));
      print('✅ Цели сохранены для пользователя $userId: ${goals.length} шт.');
    } catch (e) {
      print('❌ Ошибка сохранения целей: $e');
    }
  }

  static Future<void> syncGoalsWithAccounts() async {
    final goals = await loadGoals();
    final accounts = await CategoryService.loadAccounts();
    bool needSave = false;

    for (var goal in goals) {
      if (goal.accountId != null) {
        final linkedAccount = accounts.firstWhere(
          (a) => a.id == goal.accountId,
          orElse: () => null as Account,
        );
        if (linkedAccount != null &&
            goal.currentAmount != linkedAccount.balance) {
          goal.currentAmount = linkedAccount.balance;
          needSave = true;
        }
      }
    }

    if (needSave) {
      await saveGoals(goals);
    }
  }

  static Future<void> updateGoalsFromTransaction(
      Transaction transaction) async {
    final goals = await loadGoals();
    bool needSave = false;

    for (var goal in goals) {
      if (goal.accountId != null && goal.accountId == transaction.accountId) {
        if (transaction.type == TransactionType.income) {
          goal.currentAmount += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          goal.currentAmount -= transaction.amount;
        }
        if (goal.currentAmount < 0) goal.currentAmount = 0;
        needSave = true;
      }
    }

    if (needSave) {
      await saveGoals(goals);
    }
  }

  static Future<List<Goal>> loadGoals() async {
    try {
      final userId = await _getUserIdSafe();
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_goals_$userId';

      String? jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      List<dynamic> goalsJson = jsonDecode(jsonString);
      List<Goal> goals = goalsJson.map((json) => Goal.fromJson(json)).toList();
      print('✅ Цели загружены для пользователя $userId: ${goals.length} шт.');
      return goals;
    } catch (e) {
      print('❌ Ошибка загрузки целей: $e');
      return [];
    }
  }

  static Future<void> clearGoals() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_goals_$userId');
    print('🗑️ Все цели удалены для пользователя $userId');
  }

  // 👇 ДОБАВИТЬ ДЛЯ ВЫХОДА ИЗ АККАУНТА
  static Future<void> clearAllGoals() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_goals_$userId');
    print('🗑️ Все данные целей очищены для пользователя $userId');
  }
}
