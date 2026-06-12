import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/category_service.dart';
import '../services/category_type_service.dart';
import '../widgets/edit_category_dialog.dart';
import '../widgets/edit_subcategory_dialog.dart';
import '../utils/amount_formatter.dart';
import '../models/models.dart';
import '../screens/setup_budget_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SetupCategoriesScreen extends StatefulWidget {
  final bool isFromRegistration;
  const SetupCategoriesScreen({
    super.key,
    this.isFromRegistration = false,
  });

  @override
  State<SetupCategoriesScreen> createState() => _SetupCategoriesScreenState();
}

class _SetupCategoriesScreenState extends State<SetupCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CategoryItem> _expenseItems = [];
  List<CategoryItem> _incomeItems = [];

  final List<Category> _hiddenExpenseCategories = [];
  final List<Category> _hiddenIncomeCategories = [];
  final Map<String, List<SubCategory>> _hiddenExpenseSubCategories = {};
  final Map<String, List<SubCategory>> _hiddenIncomeSubCategories = {};
  bool _isLoading = true;

  final List<Category> _defaultExpenseCategories = [
    Category(
      id: 'exp_default_1',
      name: 'Продукты',
      icon: Icons.shopping_cart,
      color: Colors.orange.shade300,
      subCategories: [
        SubCategory(
            id: 'exp_default_1_sub1',
            name: 'Супермаркет',
            icon: Icons.store,
            color: Colors.orange.shade300),
        SubCategory(
            id: 'exp_default_1_sub2',
            name: 'Рынок',
            icon: Icons.storefront,
            color: Colors.orange.shade300),
      ],
    ),
    Category(
      id: 'exp_default_2',
      name: 'Здоровье',
      icon: Icons.health_and_safety,
      color: Colors.green.shade300,
      subCategories: [
        SubCategory(
            id: 'exp_default_2_sub1',
            name: 'Аптека',
            icon: Icons.local_pharmacy,
            color: Colors.green.shade300),
        SubCategory(
            id: 'exp_default_2_sub2',
            name: 'Врачи',
            icon: Icons.local_hospital,
            color: Colors.green.shade300),
      ],
    ),
    Category(
      id: 'exp_default_3',
      name: 'Транспорт',
      icon: Icons.directions_car,
      color: Colors.blue.shade300,
      subCategories: [
        SubCategory(
            id: 'exp_default_3_sub1',
            name: 'Такси',
            icon: Icons.local_taxi,
            color: Colors.blue.shade300),
        SubCategory(
            id: 'exp_default_3_sub2',
            name: 'Метро',
            icon: Icons.subway,
            color: Colors.blue.shade300),
      ],
    ),
  ];

  final List<Category> _defaultIncomeCategories = [
    Category(
      id: 'inc_default_1',
      name: 'Зарплата',
      icon: Icons.work,
      color: Colors.green.shade300,
      subCategories: [
        SubCategory(
            id: 'inc_default_1_sub1',
            name: 'Основная',
            icon: Icons.work_outline,
            color: Colors.green.shade300),
        SubCategory(
            id: 'inc_default_1_sub2',
            name: 'Премия',
            icon: Icons.star,
            color: Colors.green.shade300),
      ],
    ),
    Category(
      id: 'inc_default_2',
      name: 'Подарки',
      icon: Icons.card_giftcard,
      color: Colors.pink.shade300,
      subCategories: [],
    ),
    Category(
      id: 'inc_default_3',
      name: 'Оборотные',
      icon: Icons.autorenew,
      color: Colors.teal.shade300,
      subCategories: [
        SubCategory(
            id: 'inc_default_3_sub1',
            name: 'Фриланс',
            icon: Icons.computer,
            color: Colors.teal.shade300),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveAllCategories() async {
    final allCategories = [
      ..._expenseItems.map((item) => item.category),
      ..._incomeItems.map((item) => item.category),
    ];
    print('💾 Сохраняем категории: ${allCategories.length} шт.');
    await CategoryService.saveCategories(allCategories);
  }

  Future<void> _saveAllTypes() async {
    for (var item in _expenseItems) {
      await CategoryTypeService.saveCategoryType(item.category.id, 'expense');
    }
    for (var item in _incomeItems) {
      await CategoryTypeService.saveCategoryType(item.category.id, 'income');
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    try {
      final categories = await CategoryService.loadCategories();
      final savedTypes = await CategoryTypeService.getCategoryTypes();

      if (categories.isEmpty) {
        _expenseItems = _defaultExpenseCategories
            .map((c) => CategoryItem(category: c))
            .toList();
        _incomeItems = _defaultIncomeCategories
            .map((c) => CategoryItem(category: c))
            .toList();
        await _saveAllTypes();
        await CategoryService.saveCategories(
            [..._defaultExpenseCategories, ..._defaultIncomeCategories]);
      } else {
        _expenseItems = [];
        _incomeItems = [];

        for (var category in categories) {
          String? type = savedTypes[category.id];

          if (type == null) {
            type = _determineCategoryType(category);
            await CategoryTypeService.saveCategoryType(category.id, type);
          }

          if (type == 'expense') {
            _expenseItems.add(CategoryItem(category: category));
            print('📊 РАСХОД: ${category.name}');
          } else {
            _incomeItems.add(CategoryItem(category: category));
            print('📈 ДОХОД: ${category.name}');
          }
        }

        print(
            '✅ Загружено расходов: ${_expenseItems.length}, доходов: ${_incomeItems.length}');
      }

      _hiddenExpenseCategories.clear();
      _hiddenExpenseSubCategories.clear();
      for (var item in _expenseItems) {
        if (item.category.isHidden) {
          _hiddenExpenseCategories.add(item.category);
          for (var sub in item.category.subCategories) {
            if (sub.isHidden) {
              if (!_hiddenExpenseSubCategories.containsKey(item.category.id)) {
                _hiddenExpenseSubCategories[item.category.id] = [];
              }
              _hiddenExpenseSubCategories[item.category.id]!.add(sub);
            }
          }
        }
      }

      _hiddenIncomeCategories.clear();
      _hiddenIncomeSubCategories.clear();
      for (var item in _incomeItems) {
        if (item.category.isHidden) {
          _hiddenIncomeCategories.add(item.category);
          for (var sub in item.category.subCategories) {
            if (sub.isHidden) {
              if (!_hiddenIncomeSubCategories.containsKey(item.category.id)) {
                _hiddenIncomeSubCategories[item.category.id] = [];
              }
              _hiddenIncomeSubCategories[item.category.id]!.add(sub);
            }
          }
        }
      }

      print('📦 Скрытых расходов: ${_hiddenExpenseCategories.length}');
      print('📦 Скрытых доходов: ${_hiddenIncomeCategories.length}');
    } catch (e) {
      print('❌ Ошибка загрузки категорий: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _determineCategoryType(Category category) {
    final expenseColors = [
      Colors.red.shade300.value,
      Colors.blue.shade300.value,
      Colors.orange.shade300.value
    ];
    final expenseNames = [
      'Продукты',
      'Транспорт',
      'Здоровье',
      'Развлечения',
      'Связь',
      'Подарки',
      'Кафе',
      'Рестораны',
      'Одежда',
      'Коммунальные',
      'ЖКХ',
      'Аптека',
      'Такси',
      'Метро',
      'Бензин'
    ];

    if (expenseNames.contains(category.name)) {
      return 'expense';
    }

    for (var sub in category.subCategories) {
      if (expenseNames.contains(sub.name)) {
        return 'expense';
      }
    }

    if (expenseColors.contains(category.color.value)) {
      return 'expense';
    }

    return 'income';
  }

  void _addNewCategory(bool isExpense) {
    print('➕ Добавляем новую категорию, isExpense: $isExpense');

    final newCategory = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Новая категория',
      icon: Icons.category,
      color: isExpense ? Colors.red.shade300 : Colors.green.shade300,
      subCategories: [],
      budgetType: null,
    );

    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(
        category: newCategory,
        onSave: (updated) async {
          setState(() {
            if (isExpense) {
              _expenseItems.add(CategoryItem(category: updated));
              print('✅ Добавлена категория РАСХОДОВ: ${updated.name}');
            } else {
              _incomeItems.add(CategoryItem(category: updated));
              print('✅ Добавлена категория ДОХОДОВ: ${updated.name}');
            }
          });
          await _saveAllCategories();
          await CategoryTypeService.saveCategoryType(
              updated.id, isExpense ? 'expense' : 'income');
          if (isExpense) {
            await _updateBudgetWithNewCategory(updated);
          }
        },
        isNew: true,
      ),
    );
  }

  Future<void> _updateBudgetWithNewCategory(Category newCategory) async {
    final prefs = await SharedPreferences.getInstance();
    final String? budgetsJson = prefs.getString('budgets');
    Map<String, dynamic> budgets = {};
    if (budgetsJson != null) {
      budgets = jsonDecode(budgetsJson);
    }

    budgets['cat_${newCategory.id}'] = 0;
    await prefs.setString('budgets', jsonEncode(budgets));
    print('✅ Бюджет обновлен: добавлена категория ${newCategory.name}');
  }

  void _editCategory(Category category, bool isExpense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditCategoryDialog(
        category: category,
        onSave: (updated) async {
          setState(() {
            if (isExpense) {
              final index =
                  _expenseItems.indexWhere((c) => c.category.id == updated.id);
              if (index != -1) _expenseItems[index].category = updated;
            } else {
              final index =
                  _incomeItems.indexWhere((c) => c.category.id == updated.id);
              if (index != -1) _incomeItems[index].category = updated;
            }
          });
          await _saveAllCategories();
        },
      ),
    );
  }

  void _deleteCategory(String id, bool isExpense) {
    setState(() {
      if (isExpense) {
        _expenseItems.removeWhere((item) => item.category.id == id);
      } else {
        _incomeItems.removeWhere((item) => item.category.id == id);
      }
    });
    _saveAllCategories();
    CategoryTypeService.removeCategoryType(id);
  }

  void _addSubCategory(Category category, bool isExpense) {
    final newSubCategory = SubCategory(
      id: '${category.id}_sub_${category.subCategories.length}',
      name: 'Новая подкатегория',
      icon: category.icon,
      color: category.color,
      // type УБИРАЕМ
      // budgetType пока не задаём
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditSubCategoryDialog(
        subCategory: newSubCategory,
        parentCategory: category,
        onSave: (updated) {
          setState(() {
            category.subCategories.add(updated);
          });
          _saveAllCategories();
        },
        isNew: true,
        // showBudgetType УБИРАЕМ
      ),
    );
  }

  void _editSubCategory(
      SubCategory subCategory, Category parent, bool isExpense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditSubCategoryDialog(
        subCategory: subCategory,
        parentCategory: parent,
        onSave: (updated) async {
          setState(() {
            final index =
                parent.subCategories.indexWhere((s) => s.id == updated.id);
            if (index != -1) {
              parent.subCategories[index] = updated;
            }
          });
          await _saveAllCategories();
        },
        // showBudgetType УБИРАЕМ
      ),
    );
  }

  void _deleteSubCategory(SubCategory subCategory, Category parent) {
    setState(() {
      parent.subCategories.removeWhere((s) => s.id == subCategory.id);
    });
    _saveAllCategories();
  }

  void _toggleHideCategory(Category category, bool isExpense) {
    setState(() {
      category.isHidden = !category.isHidden;
      if (category.isHidden) {
        if (isExpense) {
          if (!_hiddenExpenseCategories.contains(category)) {
            _hiddenExpenseCategories.add(category);
          }
          for (var sub in category.subCategories) {
            sub.isHidden = true;
            if (!_hiddenExpenseSubCategories.containsKey(category.id)) {
              _hiddenExpenseSubCategories[category.id] = [];
            }
            if (!_hiddenExpenseSubCategories[category.id]!.contains(sub)) {
              _hiddenExpenseSubCategories[category.id]!.add(sub);
            }
          }
        } else {
          if (!_hiddenIncomeCategories.contains(category)) {
            _hiddenIncomeCategories.add(category);
          }
          for (var sub in category.subCategories) {
            sub.isHidden = true;
            if (!_hiddenIncomeSubCategories.containsKey(category.id)) {
              _hiddenIncomeSubCategories[category.id] = [];
            }
            if (!_hiddenIncomeSubCategories[category.id]!.contains(sub)) {
              _hiddenIncomeSubCategories[category.id]!.add(sub);
            }
          }
        }
      } else {
        if (isExpense) {
          _hiddenExpenseCategories.remove(category);
          for (var sub in category.subCategories) {
            sub.isHidden = false;
          }
          _hiddenExpenseSubCategories.remove(category.id);
        } else {
          _hiddenIncomeCategories.remove(category);
          for (var sub in category.subCategories) {
            sub.isHidden = false;
          }
          _hiddenIncomeSubCategories.remove(category.id);
        }
      }
    });
    _saveAllCategories();
  }

  void _toggleHideSubCategory(SubCategory subCategory, Category parent) {
    bool isExpense = _expenseItems.any((item) => item.category.id == parent.id);

    setState(() {
      subCategory.isHidden = !subCategory.isHidden;
      if (subCategory.isHidden) {
        if (isExpense) {
          if (!_hiddenExpenseSubCategories.containsKey(parent.id)) {
            _hiddenExpenseSubCategories[parent.id] = [];
          }
          if (!_hiddenExpenseSubCategories[parent.id]!.contains(subCategory)) {
            _hiddenExpenseSubCategories[parent.id]!.add(subCategory);
          }
        } else {
          if (!_hiddenIncomeSubCategories.containsKey(parent.id)) {
            _hiddenIncomeSubCategories[parent.id] = [];
          }
          if (!_hiddenIncomeSubCategories[parent.id]!.contains(subCategory)) {
            _hiddenIncomeSubCategories[parent.id]!.add(subCategory);
          }
        }
      } else {
        if (isExpense) {
          _hiddenExpenseSubCategories[parent.id]?.remove(subCategory);
        } else {
          _hiddenIncomeSubCategories[parent.id]?.remove(subCategory);
        }
      }
    });
    _saveAllCategories();
  }

  void _restoreCategory(Category category, bool isExpense) {
    setState(() {
      category.isHidden = false;
      if (isExpense) {
        _hiddenExpenseCategories.remove(category);
        for (var sub in category.subCategories) {
          sub.isHidden = false;
          _hiddenExpenseSubCategories[category.id]?.remove(sub);
        }
        if (_hiddenExpenseSubCategories[category.id]?.isEmpty ?? false) {
          _hiddenExpenseSubCategories.remove(category.id);
        }
      } else {
        _hiddenIncomeCategories.remove(category);
        for (var sub in category.subCategories) {
          sub.isHidden = false;
          _hiddenIncomeSubCategories[category.id]?.remove(sub);
        }
        if (_hiddenIncomeSubCategories[category.id]?.isEmpty ?? false) {
          _hiddenIncomeSubCategories.remove(category.id);
        }
      }
    });
    _saveAllCategories();
  }

  void _restoreSubCategory(SubCategory subCategory, Category parent) {
    bool isExpense = _expenseItems.any((item) => item.category.id == parent.id);

    setState(() {
      parent.isHidden = false;
      subCategory.isHidden = false;
      if (isExpense) {
        _hiddenExpenseCategories.remove(parent);
        _hiddenExpenseSubCategories[parent.id]?.remove(subCategory);
        if (_hiddenExpenseSubCategories[parent.id]?.isEmpty ?? false) {
          _hiddenExpenseSubCategories.remove(parent.id);
        }
      } else {
        _hiddenIncomeCategories.remove(parent);
        _hiddenIncomeSubCategories[parent.id]?.remove(subCategory);
        if (_hiddenIncomeSubCategories[parent.id]?.isEmpty ?? false) {
          _hiddenIncomeSubCategories.remove(parent.id);
        }
      }
    });
    _saveAllCategories();
  }

  void _showRestoreDialog(bool isExpense) {
    final categories = isExpense
        ? _expenseItems.map((i) => i.category).toList()
        : _incomeItems.map((i) => i.category).toList();
    final color = isExpense ? Colors.red.shade300 : Colors.green.shade300;
    final hiddenCategories =
        isExpense ? _hiddenExpenseCategories : _hiddenIncomeCategories;
    final hiddenSubCategories =
        isExpense ? _hiddenExpenseSubCategories : _hiddenIncomeSubCategories;

    final selectedCategories = <Category>{};
    final selectedSubIds = <String>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Восстановить скрытые'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: [
                    if (hiddenCategories.isNotEmpty) ...[
                      const Text('Категории:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...hiddenCategories.map(
                        (category) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: selectedCategories.contains(category)
                                ? color.withOpacity(0.2)
                                : null,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (selectedCategories.contains(category)) {
                                  selectedCategories.remove(category);
                                  for (var sub in category.subCategories) {
                                    selectedSubIds.remove(sub.id);
                                  }
                                } else {
                                  selectedCategories.add(category);
                                  for (var sub in category.subCategories) {
                                    selectedSubIds.add(sub.id);
                                  }
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selectedCategories
                                                .contains(category)
                                            ? color
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color:
                                          selectedCategories.contains(category)
                                              ? color
                                              : Colors.transparent,
                                    ),
                                    child: selectedCategories.contains(category)
                                        ? Center(
                                            child: Icon(Icons.check,
                                                size: 18, color: Colors.white))
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: category.color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(category.icon,
                                        color: category.color, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        fontWeight: selectedCategories
                                                .contains(category)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (selectedCategories.contains(category))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${category.subCategories.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (hiddenSubCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Подкатегории:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...hiddenSubCategories.entries.expand((entry) {
                        final category = categories.firstWhere(
                          (c) => c.id == entry.key,
                          orElse: () => categories.isNotEmpty
                              ? categories.first
                              : _defaultExpenseCategories.first,
                        );
                        return entry.value.map((sub) {
                          final isCategorySelected =
                              selectedCategories.contains(category);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: selectedSubIds.contains(sub.id)
                                  ? color.withOpacity(0.2)
                                  : null,
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (selectedSubIds.contains(sub.id)) {
                                    selectedSubIds.remove(sub.id);
                                  } else {
                                    selectedSubIds.add(sub.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              selectedSubIds.contains(sub.id) ||
                                                      isCategorySelected
                                                  ? color
                                                  : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        color:
                                            selectedSubIds.contains(sub.id) ||
                                                    isCategorySelected
                                                ? color
                                                : Colors.transparent,
                                      ),
                                      child: selectedSubIds.contains(sub.id) ||
                                              isCategorySelected
                                          ? Center(
                                              child: Icon(Icons.check,
                                                  size: 14,
                                                  color: Colors.white))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: sub.color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(sub.icon,
                                          color: sub.color, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${category.name} → ${sub.name}',
                                        style: TextStyle(
                                          fontWeight:
                                              selectedSubIds.contains(sub.id) ||
                                                      isCategorySelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color: isCategorySelected &&
                                                  !selectedSubIds
                                                      .contains(sub.id)
                                              ? Colors.grey
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                      }),
                    ],
                    if (hiddenCategories.isEmpty && hiddenSubCategories.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Нет скрытых элементов'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    for (var category in selectedCategories) {
                      _restoreCategory(category, isExpense);
                    }
                    for (var subId in selectedSubIds) {
                      bool alreadyRestored = false;
                      for (var category in selectedCategories) {
                        if (category.subCategories.any((s) => s.id == subId)) {
                          alreadyRestored = true;
                          break;
                        }
                      }
                      if (!alreadyRestored) {
                        for (var entry in hiddenSubCategories.entries) {
                          final category = categories.firstWhere(
                            (c) => c.id == entry.key,
                            orElse: () => categories.isNotEmpty
                                ? categories.first
                                : _defaultExpenseCategories.first,
                          );
                          final sub = entry.value.firstWhere(
                            (s) => s.id == subId,
                            orElse: () => null as SubCategory,
                          );
                          _restoreSubCategory(sub, category);
                          break;
                        }
                      }
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                      'Восстановить (${selectedCategories.length + selectedSubIds.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final primaryColor = settingsProvider.primaryColor; // 👈 выбранный цвет
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Категории',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '💰 Расходы'),
            Tab(text: '📈 Доходы'),
          ],
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.isFromRegistration)
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupBudgetScreen(isFromRegistration: true),
                  ),
                );
              },
              child: Text(
                'Пропустить',
                style: TextStyle(
                  color: primaryColor,
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
              primaryColor.withOpacity(0.1),
              colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '← удалить   редактировать →',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _addNewCategory(_tabController.index == 0),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Добавить категорию',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                        if ((_tabController.index == 0 &&
                                (_hiddenExpenseCategories.isNotEmpty ||
                                    _hiddenExpenseSubCategories.isNotEmpty)) ||
                            (_tabController.index == 1 &&
                                (_hiddenIncomeCategories.isNotEmpty ||
                                    _hiddenIncomeSubCategories.isNotEmpty)))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: Colors.white),
                              onPressed: () =>
                                  _showRestoreDialog(_tabController.index == 0),
                              style: IconButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryList(_expenseItems, true),
                        _buildCategoryList(_incomeItems, false),
                      ],
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
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      print(
                          '🔘 Нажата кнопка "Продолжить" - переход в SetupBudgetScreen');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SetupBudgetScreen(isFromRegistration: true),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Продолжить',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryList(List<CategoryItem> items, bool isExpense) {
    final visibleItems =
        items.where((item) => !item.category.isHidden).toList();

    if (visibleItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpense ? Icons.trending_down : Icons.trending_up,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет категорий',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите + чтобы добавить',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return Dismissible(
          key: ValueKey(item.category.id),
          direction: DismissDirection.horizontal,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text('Ред.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Удал.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.delete, color: Colors.white, size: 24),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить категорию'),
                  content: const Text(
                      'Все подкатегории также будут удалены. Вы уверены?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _deleteCategory(item.category.id, isExpense);
              }
              return false;
            } else {
              _editCategory(item.category, isExpense);
              return false;
            }
          },
          child: _buildCategoryCard(item, isExpense),
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex--;
          }
          final item = visibleItems.removeAt(oldIndex);
          visibleItems.insert(newIndex, item);
          items.clear();
          items.addAll(visibleItems);
        });
        _saveAllCategories();
      },
    );
  }

  Widget _buildCategoryCard(CategoryItem item, bool isExpense) {
    final category = item.category;
    final color = isExpense ? Colors.red.shade300 : Colors.green.shade300;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final visibleSubs =
        category.subCategories.where((sub) => !sub.isHidden).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _addSubCategory(category, isExpense),
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.all(8),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    category.isHidden ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleHideCategory(category, isExpense),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        category.isHidden ? Colors.grey.shade400 : color,
                    padding: const EdgeInsets.all(8),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          if (visibleSubs.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: visibleSubs.length,
              itemBuilder: (context, index) {
                final sub = visibleSubs[index];
                return Container(
                  key: Key('sub_${sub.id}'),
                  padding:
                      const EdgeInsets.only(left: 64, right: 12, bottom: 4),
                  child: _buildSubCategoryTile(sub, category, isExpense),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = visibleSubs.removeAt(oldIndex);
                  visibleSubs.insert(newIndex, item);
                  category.subCategories.clear();
                  category.subCategories.addAll(visibleSubs);
                });
                _saveAllCategories();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSubCategoryTile(
      SubCategory sub, Category parent, bool isExpense) {
    final color = isExpense ? Colors.red.shade300 : Colors.green.shade300;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dismissible(
      key: Key('sub_${sub.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.blue.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Ред.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Удал.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.delete, color: Colors.white, size: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить подкатегорию'),
              content: const Text('Вы уверены?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            _deleteSubCategory(sub, parent);
          }
          return false;
        } else {
          _editSubCategory(sub, parent, isExpense);
          return false;
        }
      },
      child: Row(
        children: [
          Icon(Icons.drag_handle, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: sub.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(sub.icon, color: sub.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sub.name,
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ),
          IconButton(
            icon: Icon(
              sub.isHidden ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => _toggleHideSubCategory(sub, parent),
            style: IconButton.styleFrom(
              backgroundColor: sub.isHidden ? Colors.grey.shade400 : color,
              padding: const EdgeInsets.all(6),
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
