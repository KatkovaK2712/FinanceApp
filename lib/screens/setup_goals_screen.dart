import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/goal_service.dart';
import '../services/category_service.dart';
import 'add_goal_sheet.dart';
import '../models/models.dart';
import '../utils/amount_formatter.dart';
import 'setup_categories_screen.dart';

class SetupGoalsScreen extends StatefulWidget {
  final bool isFromRegistration;
  const SetupGoalsScreen({
    super.key,
    this.isFromRegistration = false,
  });

  @override
  State<SetupGoalsScreen> createState() => _SetupGoalsScreenState();
}

class _SetupGoalsScreenState extends State<SetupGoalsScreen> {
  List<Goal> _goals = [];
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await CategoryService.loadAccounts();
    setState(() {
      _accounts = accounts;
    });
  }

  Future<void> _editGoal(Goal goal) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGoalSheet(
        onGoalAdded: (updatedGoal) {
          setState(() {
            final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
            if (index != -1) {
              _goals[index] = updatedGoal;
            }
          });
          GoalService.saveGoals(_goals);
        },
        goalToEdit: goal,
        accounts: _accounts,
      ),
    );
  }

  Future<void> _loadGoals() async {
    final goals = await GoalService.loadGoals();
    setState(() {
      _goals = goals;
    });
  }

  Future<void> _addGoal(Goal goal) async {
    setState(() {
      _goals.add(goal);
    });
    await GoalService.saveGoals(_goals);
  }

  Future<void> _deleteGoal(String id) async {
    setState(() {
      _goals.removeWhere((g) => g.id == id);
    });
    await GoalService.saveGoals(_goals);
  }

  void _showAddGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGoalSheet(
        onGoalAdded: _addGoal,
        accounts: _accounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // ✅ ВРЕМЕННО: принудительно показываем кнопки для теста
    final showButtons = widget.isFromRegistration;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Цели накопления'),
        actions: [
          if (showButtons) // ← временно используем showButtons
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetupCategoriesScreen(isFromRegistration: true),
                  ),
                );
              },
              child: const Text(
                'Пропустить',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Цели накопления',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    onPressed: _showAddGoalDialog,
                    backgroundColor: colorScheme.primary,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _goals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'У вас пока нет целей',
                            style: TextStyle(
                              fontSize: 18,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите + чтобы добавить цель',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _goals.length,
                      itemBuilder: (context, index) {
                        final goal = _goals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editGoal(goal),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Удалить цель'),
                                            content: const Text('Вы уверены?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Отмена'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _deleteGoal(goal.id);
                                                  Navigator.pop(context);
                                                },
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Удалить'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: goal.color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        goal.icon,
                                        color: goal.color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goal.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'До ${DateFormat('dd.MM.yyyy').format(goal.targetDate)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (goal.accountId != null && goal.accountId != 'none')
                                            Text(
                                              'Счёт: ${_getAccountName(goal.accountId)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Накоплено: ${AmountFormatter.formatNumber(goal.currentAmount)} ₽',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Цель: ${AmountFormatter.formatNumber(goal.targetAmount)} ₽',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: goal.progress.clamp(0.0, 1.0),
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          goal.color,
                                        ),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(goal.progress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: goal.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: showButtons // ← временно используем showButtons
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SetupCategoriesScreen(isFromRegistration: true),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Продолжить',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  String _getAccountName(String? accountId) {
    if (accountId == null || accountId == 'none') return 'Не привязан';
  
    try {
      final account = _accounts.firstWhere((a) => a.id == accountId);
      return account.name;
    } catch (e) {
      return 'Счёт удалён';
    }
  }
}