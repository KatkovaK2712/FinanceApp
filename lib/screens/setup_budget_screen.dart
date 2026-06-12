import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/category_service.dart';
import '../services/category_type_service.dart';
import '../models/models.dart';
import '../utils/snackbar_utils.dart';
class SetupBudgetScreen extends StatefulWidget {
  final bool isFromRegistration;
  const SetupBudgetScreen({
    super.key,
    this.isFromRegistration = false,
  });

  @override
  State<SetupBudgetScreen> createState() => _SetupBudgetScreenState();
}

class _SetupBudgetScreenState extends State<SetupBudgetScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Category> _expenseCategories = [];
  final Map<String, TextEditingController> _budgetControllers = {};
  final Map<String, TextEditingController> _subBudgetControllers = {};
  final Map<String, bool> _expandedCategories = {};
  bool _isUpdatingFromSub = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (var controller in _budgetControllers.values) {
      controller.dispose();
    }
    for (var controller in _subBudgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final allCategories = await CategoryService.loadCategories();
      final savedTypes = await CategoryTypeService.getCategoryTypes();
      
      _expenseCategories.clear();
      
      for (var category in allCategories) {
        String? type = savedTypes[category.id];
        
        if (type == null) {
          if (category.name.contains('Транспорт') ||
              category.name.contains('Здоровье') ||
              category.name.contains('Продукты') ||
              category.name.contains('Развлечения') ||
              category.name.contains('Связь') ||
              category.name.contains('Подарки')) {
            type = 'expense';
          } else {
            type = 'income';
          }
        }
        
        if (type == 'expense') {
          _expenseCategories.add(category);
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      final String? budgetsJson = prefs.getString('budgets');
      Map<String, dynamic> savedBudgets = {};
      if (budgetsJson != null) {
        savedBudgets = jsonDecode(budgetsJson);
      }
      
      for (var category in _expenseCategories) {
        _budgetControllers[category.id] = TextEditingController();
        _expandedCategories[category.id] = false;
        
        final savedAmount = savedBudgets['cat_${category.id}'];
        double totalSubs = 0;
        
        for (var sub in category.subCategories) {
          final controller = TextEditingController();
          _subBudgetControllers[sub.id] = controller;
          
          final savedSubAmount = savedBudgets['sub_${sub.id}'];
          if (savedSubAmount != null && savedSubAmount > 0) {
            controller.text = savedSubAmount.toString();
            totalSubs += savedSubAmount;
          }
        }
        
        if (savedAmount != null && savedAmount > 0) {
          _budgetControllers[category.id]?.text = savedAmount.toString();
        } else if (totalSubs > 0) {
          _budgetControllers[category.id]?.text = totalSubs.toString();
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Ошибка загрузки категорий: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateSubCategory(String categoryId, String subId, String value) {
    if (_isUpdatingFromSub) return;
    
    setState(() {
      _subBudgetControllers[subId]?.text = value;
      _updateCategoryTotalFromSubs(categoryId);
    });
  }

  void _updateCategoryTotalFromSubs(String categoryId) {
    final category = _expenseCategories.firstWhere((c) => c.id == categoryId);
    double total = 0;
    
    for (var sub in category.subCategories) {
      final controller = _subBudgetControllers[sub.id];
      if (controller != null && controller.text.isNotEmpty) {
        final amount = double.tryParse(controller.text.replaceAll(',', '.'));
        if (amount != null && amount > 0) {
          total += amount;
        }
      }
    }
    
    final categoryController = _budgetControllers[categoryId];
    if (categoryController != null) {
      categoryController.text = total > 0 ? total.toString() : '';
    }
  }

  void _updateCategoryDirectly(String categoryId, String value) {
    setState(() {
      _budgetControllers[categoryId]?.text = value;
    });
  }

  Future<void> _saveBudgets() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final Map<String, dynamic> budgets = {};
      
      for (var category in _expenseCategories) {
        final controller = _budgetControllers[category.id];
        if (controller != null && controller.text.isNotEmpty) {
          final amount = double.tryParse(controller.text.replaceAll(',', '.'));
          if (amount != null && amount > 0) {
            budgets['cat_${category.id}'] = amount;
          }
        }
        
        for (var sub in category.subCategories) {
          final subController = _subBudgetControllers[sub.id];
          if (subController != null && subController.text.isNotEmpty) {
            final amount = double.tryParse(subController.text.replaceAll(',', '.'));
            if (amount != null && amount > 0) {
              budgets['sub_${sub.id}'] = amount;
            }
          }
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('budgets', jsonEncode(budgets));
      
      SnackbarUtils.showSuccess(context, 'Бюджеты сохранены');
      
      if (widget.isFromRegistration) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Ошибка сохранения бюджетов: $e');
      SnackbarUtils.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Установить бюджет'),
        elevation: 0,
        actions: [
          if (widget.isFromRegistration)
            TextButton(
              onPressed: _saveBudgets,
              child: const Text(
                'Пропустить',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.primary.withOpacity(0.05),
                  child: const Column(
                    children: [
                      Text(
                        'Установите бюджет расходов на месяц',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Сумма в категории автоматически суммируется из подкатегорий',
                        style: TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _expenseCategories.length,
                    itemBuilder: (context, index) {
                      final category = _expenseCategories[index];
                      final isExpanded = _expandedCategories[category.id] ?? false;
                      final hasSubCategories = category.subCategories.isNotEmpty;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () {
                                if (hasSubCategories) {
                                  setState(() {
                                    _expandedCategories[category.id] = !isExpanded;
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: category.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        category.icon,
                                        color: category.color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (hasSubCategories)
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.grey,
                                      ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: _budgetControllers[category.id],
                                        readOnly: hasSubCategories,
                                        decoration: const InputDecoration(
                                          labelText: 'Бюджет',
                                          hintText: '0',
                                          prefixIcon: Icon(Icons.currency_ruble, size: 16),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) => _updateCategoryDirectly(category.id, value),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded && hasSubCategories)
                              Padding(
                                padding: const EdgeInsets.only(left: 48, right: 12, bottom: 12),
                                child: Column(
                                  children: category.subCategories.map((sub) {
                                    final subController = _subBudgetControllers[sub.id];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: sub.color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(sub.icon, color: sub.color, size: 16),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              sub.name,
                                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: TextField(
                                              controller: subController,
                                              decoration: const InputDecoration(
                                                labelText: 'Бюджет',
                                                hintText: '0',
                                                prefixIcon: Icon(Icons.currency_ruble, size: 14),
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              keyboardType: TextInputType.number,
                                              onChanged: (value) => _updateSubCategory(category.id, sub.id, value),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey.shade900,
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
                        onPressed: _isSaving ? null : _saveBudgets,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}