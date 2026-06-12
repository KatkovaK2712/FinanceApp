import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class AccountSettingsService {
  static String? get _userId => ApiService.currentUserId;

  static String _getKey() {
    final userId = _userId;
    if (userId == null) return 'main_accounts_default';
    return 'main_accounts_$userId';
  }

  static Future<void> setMainAccount(String accountId, bool isMain) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    List<String> mainAccounts = prefs.getStringList(key) ?? [];

    if (isMain && !mainAccounts.contains(accountId)) {
      mainAccounts.add(accountId);
    } else if (!isMain) {
      mainAccounts.remove(accountId);
    }

    await prefs.setStringList(key, mainAccounts);
    print('⚙️ Настройки главных счетов сохранены для пользователя $_userId');
  }

  static Future<bool> isMainAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    List<String> mainAccounts = prefs.getStringList(key) ?? [];
    return mainAccounts.contains(accountId);
  }

  static Future<List<String>> getMainAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    return prefs.getStringList(key) ?? [];
  }

  // 👇 ДОБАВИТЬ ДЛЯ ВЫХОДА ИЗ АККАУНТА
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    await prefs.remove(key);
    print('🗑️ Настройки главных счетов очищены для пользователя $_userId');
  }
}
