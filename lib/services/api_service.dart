import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _currentUserId;

  // ==================== УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ ====================

  static Future<bool> register(String email, String password) async {
    print('📝 Локальная регистрация: $email');

    final prefs = await SharedPreferences.getInstance();

    // Загружаем существующих пользователей
    final String? usersJson = prefs.getString('registered_users');
    Map<String, String> users = {};

    if (usersJson != null) {
      users = Map<String, String>.from(jsonDecode(usersJson));
    }

    // Проверяем, не существует ли уже такой email
    if (users.containsKey(email)) {
      print('❌ Пользователь уже существует');
      return false;
    }

    // Сохраняем нового пользователя
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    users[email] = password;
    await prefs.setString('registered_users', jsonEncode(users));

    // Автоматически входим
    await saveUserId(userId);
    await saveUserEmail(email);

    print('✅ Пользователь зарегистрирован: $userId');
    return true;
  }

  static Future<bool> login(String email, String password) async {
    print('🔐 Локальный вход: $email');

    final prefs = await SharedPreferences.getInstance();

    // Загружаем существующих пользователей
    final String? usersJson = prefs.getString('registered_users');
    if (usersJson == null) {
      print('❌ Нет зарегистрированных пользователей');
      return false;
    }

    final Map<String, String> users =
        Map<String, String>.from(jsonDecode(usersJson));

    // Проверяем email и пароль
    if (users[email] == password) {
      // Генерируем userId для существующего пользователя (если нет)
      String? userId = await getUserIdByEmail(email);
      if (userId == null) {
        userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      }
      await saveUserId(userId);
      await saveUserEmail(email);
      print('✅ Вход выполнен для: $email');
      return true;
    }

    print('❌ Неверный email или пароль');
    return false;
  }

  static Future<String?> getUserIdByEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final String? emailsToIds = prefs.getString('emails_to_ids');
    if (emailsToIds == null) return null;
    final Map<String, String> map =
        Map<String, String>.from(jsonDecode(emailsToIds));
    return map[email];
  }

  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_email', email);
  }

  static Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_email');
  }

  static Future<void> saveUserId(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);

    // Сохраняем связь email -> userId
    final email = await getCurrentUserEmail();
    if (email != null) {
      final String? emailsToIds = prefs.getString('emails_to_ids');
      Map<String, String> map = {};
      if (emailsToIds != null) {
        map = Map<String, String>.from(jsonDecode(emailsToIds));
      }
      map[email] = userId;
      await prefs.setString('emails_to_ids', jsonEncode(map));
    }

    print('👤 userId сохранен: $userId');
  }

  static Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    if (_currentUserId != null) {
      print('👤 userId загружен: $_currentUserId');
    }
  }

  static String? get currentUserId => _currentUserId;

  static Future<bool> hasSavedUser() async {
    await loadUserId();
    return _currentUserId != null;
  }

  static Future<void> logout() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('current_user_email');
    print('👤 Выход выполнен');
  }

  static Future<void> clearAllUserData() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Очищаем данные конкретного пользователя
    await prefs.remove('transactions_$userId');
    await prefs.remove('categories_$userId');
    await prefs.remove('accounts_$userId');
    await prefs.remove('goals_$userId');
    await prefs.remove('budgets_$userId');

    print('🗑️ Все данные пользователя $userId очищены');
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ ====================

  static void init() {
    print('🚀 ApiService инициализирован (локальный режим)');
  }
}
