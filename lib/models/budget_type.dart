import 'package:flutter/material.dart';

enum BudgetType {
  needs,
  wants,
  emergency;

  String get displayName {
    switch (this) {
      case BudgetType.needs:
        return 'Обязательные нужды';
      case BudgetType.wants:
        return 'Желания';
      case BudgetType.emergency:
        return 'Непредвиденные';
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetType.needs:
        return Icons.home;
      case BudgetType.wants:
        return Icons.favorite;
      case BudgetType.emergency:
        return Icons.warning;
    }
  }

  Color get color {
    switch (this) {
      case BudgetType.needs:
        return Colors.blue;
      case BudgetType.wants:
        return Colors.orange;
      case BudgetType.emergency:
        return Colors.purple;
    }
  }
}