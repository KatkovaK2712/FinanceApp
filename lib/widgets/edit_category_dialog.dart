// ==================== ПОЛНЫЙ edit_category_dialog.dart ====================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_models.dart';
import '../models/budget_type.dart';
import '../providers/settings_provider.dart';

class EditCategoryDialog extends StatefulWidget {
  final Category category;
  final Function(Category) onSave;
  final bool isNew;

  const EditCategoryDialog({
    super.key,
    required this.category,
    required this.onSave,
    this.isNew = false,
  });

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late TextEditingController _nameController;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late BudgetType _selectedBudgetType;
  bool _hasSubCategories = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isNew ? '' : widget.category.name,
    );
    _selectedIcon = widget.category.icon;
    _selectedColor = widget.category.color;
    _hasSubCategories = widget.category.subCategories.isNotEmpty;
    
    if (widget.category.budgetType != null) {
      _selectedBudgetType = BudgetType.values.firstWhere(
        (e) => e.toString().split('.').last == widget.category.budgetType,
        orElse: () => BudgetType.needs,
      );
    } else {
      if (widget.category.name.contains('Продукты') ||
          widget.category.name.contains('Транспорт') ||
          widget.category.name.contains('Здоровье') ||
          widget.category.name.contains('Связь') ||
          widget.category.name.contains('Коммунальные')) {
        _selectedBudgetType = BudgetType.needs;
      } else if (widget.category.name.contains('Развлечения') ||
                 widget.category.name.contains('Рестораны') ||
                 widget.category.name.contains('Подарки')) {
        _selectedBudgetType = BudgetType.wants;
      } else if (widget.category.name.contains('Непредвиденные')) {
        _selectedBudgetType = BudgetType.emergency;
      } else {
        _selectedBudgetType = BudgetType.needs;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final settings = Provider.of<SettingsProvider>(context);
    final showBudgetType = settings.showMethodCard;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: (!_hasSubCategories && showBudgetType) 
            ? MediaQuery.of(context).size.height * 0.75
            : MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.isNew ? 'Новая категория' : 'Редактировать категорию',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: viewInsets.bottom + 80,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_hasSubCategories && showBudgetType) ...[
                      const Text('Тип бюджета', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BudgetType.values.map((type) {
                          final isSelected = _selectedBudgetType == type;
                          return FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon, size: 16, color: isSelected ? Colors.white : type.color),
                                const SizedBox(width: 4),
                                Text(
                                  type.displayName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : type.color,
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedBudgetType = type;
                                });
                              }
                            },
                            backgroundColor: Colors.transparent,
                            selectedColor: type.color,
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text('Название', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      autofocus: widget.isNew,
                      decoration: InputDecoration(
                        hintText: 'Введите название категории',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Иконка', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconInfo = availableIcons[index];
                          final isSelected = _selectedIcon == iconInfo.icon;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = iconInfo.icon),
                            child: Container(
                              width: 55,
                              height: 55,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? _selectedColor.withOpacity(0.2) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _selectedColor : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                iconInfo.icon,
                                color: isSelected ? _selectedColor : Colors.grey,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Цвет', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableColors.length,
                        itemBuilder: (context, index) {
                          final color = availableColors[index];
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets.bottom),
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
                      if (_nameController.text.isNotEmpty) {
                        final updatedCategory = Category(
                          id: widget.category.id,
                          name: _nameController.text,
                          icon: _selectedIcon,
                          color: _selectedColor,
                          subCategories: widget.category.subCategories,
                          isHidden: widget.category.isHidden,
                          budgetType: (!_hasSubCategories && showBudgetType) 
                              ? _selectedBudgetType.toString().split('.').last 
                              : null,
                        );
                        widget.onSave(updatedCategory);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isNew ? 'Создать категорию' : 'Сохранить',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}