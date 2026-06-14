import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/category_service.dart';
import 'add_account_sheet.dart';
import '../utils/amount_formatter.dart';
import '../models/models.dart';
import 'setup_goals_screen.dart';
import '../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';

const List<Color> availableColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
];

class SetupAccountsScreen extends StatefulWidget {
  final bool isFromRegistration;
  const SetupAccountsScreen({
    super.key,
    this.isFromRegistration = false,
  });

  @override
  State<SetupAccountsScreen> createState() => _SetupAccountsScreenState();
}

class _SetupAccountsScreenState extends State<SetupAccountsScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await CategoryService.loadAccounts();
      // ✅ Убираем дубликаты по id
      final uniqueAccounts = accounts
          .fold<Map<String, Account>>({}, (map, a) {
            map[a.id] = a;
            return map;
          })
          .values
          .toList();
      _accounts = uniqueAccounts;
      print('✅ Загружено счетов: ${_accounts.length} (уникальных)');
    } catch (e) {
      print('❌ Ошибка загрузки счетов: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAccounts() async {
    // ✅ Убираем дубликаты перед сохранением
    final uniqueAccounts = _accounts
        .fold<Map<String, Account>>({}, (map, a) {
          map[a.id] = a;
          return map;
        })
        .values
        .toList();

    if (uniqueAccounts.length != _accounts.length) {
      print(
          '⚠️ Обнаружены дубликаты! Было: ${_accounts.length}, стало: ${uniqueAccounts.length}');
      _accounts = uniqueAccounts;
    }

    await CategoryService.saveAccounts(_accounts);
    CategoryService.notifyAccountsListeners();
    final prefs = await SharedPreferences.getInstance();
    for (var account in _accounts) {
      await prefs.setBool('show_${account.id}', account.showOnHomeScreen);
      await prefs.setBool('main_${account.id}', account.isMain);
    }
    setState(() => _hasChanges = false);
    print('✅ Счета сохранены: ${_accounts.length} шт.');
  }

  Future<void> _syncAccountSettings(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_${account.id}', account.showOnHomeScreen);
    await prefs.setBool('main_${account.id}', account.isMain);
    print(
        '✅ Синхронизация: show=${account.showOnHomeScreen}, main=${account.isMain}');
  }

  void _addAccount(Account account) async {
    // ✅ Проверяем, нет ли уже такого счета
    final exists = _accounts.any((a) => a.id == account.id);
    if (!exists) {
      setState(() {
        _accounts.add(account);
        _hasChanges = true;
      });
      await _saveAccounts();
      CategoryService.notifyAccountsListeners();
    } else {
      print('⚠️ Счет с id ${account.id} уже существует, пропускаем');
    }
  }

  void _editAccount(Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAccountSheet(
        onAccountAdded: (updated) async {
          setState(() {
            final index = _accounts.indexWhere((a) => a.id == updated.id);
            if (index != -1) {
              _accounts[index] = updated;
            } else {
              _accounts.add(updated);
            }
            _hasChanges = true;
          });
          await _saveAccounts();
          SnackbarUtils.showSuccess(context, 'Счет обновлен');
        },
        accountToEdit: account,
      ),
    );
  }

  void _showAddAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAccountSheet(
        onAccountAdded: _addAccount,
      ),
    );
  }

  void _deleteAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('show_${account.id}');
    await prefs.remove('main_${account.id}');

    setState(() {
      _accounts.removeWhere((a) => a.id == account.id);
      _hasChanges = true;
    });
    await _saveAccounts();
    CategoryService.notifyAccountsListeners();

    SnackbarUtils.showWarning(context, 'Счет "${account.name}" удален');
  }

  void _saveAndContinue() async {
    if (_accounts.isEmpty) {
      SnackbarUtils.showError(
          context, 'Добавьте хотя бы один счет для продолжения');
      return;
    }
    await _saveAccounts();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SetupGoalsScreen(isFromRegistration: true),
      ),
    );
  }

  String _formatBalance(double balance) {
    final formatter = NumberFormat('#,##0.00', 'ru_RU');
    return formatter.format(balance);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Счета',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (widget.isFromRegistration)
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupGoalsScreen(isFromRegistration: true),
                  ),
                );
              },
              child: const Text(
                'Пропустить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            if (widget.isFromRegistration)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Добавьте хотя бы один счёт для корректной работы приложения',
                        style: TextStyle(
                            color: Colors.orange.shade900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _showAddAccountDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Добавить счет',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _accounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Нет счетов',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Нажмите + чтобы добавить счет',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _accounts.length,
                          itemBuilder: (context, index) {
                            final account = _accounts[index];
                            return Dismissible(
                              key: Key('account_${account.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Удалить',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                final confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Удалить счет'),
                                    content: const Text('Вы уверены?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                                );
                                return confirm;
                              },
                              onDismissed: (direction) =>
                                  _deleteAccount(account),
                              child: GestureDetector(
                                onTap: () => _editAccount(account),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color:
                                                account.color.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            account.icon,
                                            color: account.color,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                account.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                account.type.displayName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                'Баланс: ${_formatBalance(account.balance)} ${account.currency}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: account.balance >= 0
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.isFromRegistration
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Продолжить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
