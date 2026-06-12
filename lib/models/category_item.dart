import 'transaction_models.dart';

class CategoryItem {
  Category category;
  bool isExpanded;
  bool isEditing;

  CategoryItem({
    required this.category,
    this.isExpanded = false,
    this.isEditing = false,
  });
}

class SubCategoryItem {
  SubCategory subCategory;
  bool isEditing;

  SubCategoryItem({
    required this.subCategory,
    this.isEditing = false,
  });
}