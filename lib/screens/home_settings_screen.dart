import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/category_service.dart';
import '../models/models.dart';
import '../providers/settings_provider.dart';
import '../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';

class HomeSettingsScreen extends StatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  State<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends State<HomeSettingsScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  Map<String, bool> _showOnHomeScreen = {};
  Map<String, bool> _isMainAccount = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  String _formatBalance(double balance) {
    return NumberFormat('#,##0.00', 'ru_RU').format(balance);
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      _accounts = await CategoryService.loadAccounts();

      final prefs = await SharedPreferences.getInstance();

      for (var account in _accounts) {
        _showOnHomeScreen[account.id] =
            prefs.getBool('show_${account.id}') ?? true;
        _isMainAccount[account.id] =
            prefs.getBool('main_${account.id}') ?? false;
      }
    } catch (e) {
      print('❌ Ошибка загрузки счетов: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getMainAccountsCount() {
    return _isMainAccount.values.where((v) => v == true).length;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    for (var account in _accounts) {
      await prefs.setBool(
          'show_${account.id}', _showOnHomeScreen[account.id] ?? true);
      await prefs.setBool(
          'main_${account.id}', _isMainAccount[account.id] ?? false);
    }

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    settingsProvider.updateHomeScreenSettings();

    // Уведомляем об изменении
    CategoryService.notifyAccountsListeners();

    if (mounted) {
      SnackbarUtils.showSuccess(context, 'Настройки сохранены');
      // Возвращаем true
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mainAccountsCount = _getMainAccountsCount();
    final isMaxMainReached = mainAccountsCount >= 8; // 👈 ЛИМИТ 10 СЧЕТОВ

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки главного экрана',
            style: TextStyle(fontSize: 18)),
        elevation: 0,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Нет счетов',
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Назад',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final canBeMain =
                          (account.type == AccountType.debitCard ||
                                  account.type == AccountType.creditCard ||
                                  account.type == AccountType.cash ||
                                  account.type == AccountType.deposit ||
                                  account.type == AccountType.savings ||
                                  account.type == AccountType.loan ||
                                  account.type == AccountType.investment ||
                                  account.type == AccountType.other) &&
                              account.type != AccountType.debtOwed &&
                              account.type != AccountType.debtToPay;
                      final isMain = _isMainAccount[account.id] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: account.color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(account.icon,
                                        color: account.color, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${_formatBalance(account.balance)} ${account.currency}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: account.balance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Switch(
                                          value:
                                              _showOnHomeScreen[account.id] ??
                                                  true,
                                          onChanged: (value) {
                                            setState(() {
                                              _showOnHomeScreen[account.id] =
                                                  value;
                                              if (!value) {
                                                _isMainAccount[account.id] =
                                                    false;
                                              }
                                            });
                                          },
                                          activeColor: colorScheme.primary,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('Показывать',
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (canBeMain &&
                                      (_showOnHomeScreen[account.id] ?? true))
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Основной',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isMaxMainReached && !isMain
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                          ),
                                          Switch(
                                            value: isMain,
                                            onChanged: (isMaxMainReached &&
                                                    !isMain)
                                                ? null
                                                : (value) {
                                                    setState(() {
                                                      _isMainAccount[
                                                          account.id] = value;
                                                    });
                                                  },
                                            activeColor: colorScheme.primary,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              // 👇 ПРЕДУПРЕЖДЕНИЕ О ЛИМИТЕ (если достигнут)
                              if (isMaxMainReached &&
                                  !isMain &&
                                  canBeMain &&
                                  (_showOnHomeScreen[account.id] ?? true))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Достигнут лимит основных счетов (максимум 8)',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Сохранить',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
