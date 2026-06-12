import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showSuccess(BuildContext context, String message) {
    _showSnackbar(context, message, Icons.check_circle);
  }
  
  static void showError(BuildContext context, String message) {
    _showSnackbar(context, message, Icons.error);
  }
  
  static void showInfo(BuildContext context, String message) {
    _showSnackbar(context, message, Icons.info);
  }
  
  static void showWarning(BuildContext context, String message) {
    _showSnackbar(context, message, Icons.warning_amber);
  }
  
  static void _showSnackbar(BuildContext context, String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
        elevation: 0,
      ),
    );
  }
}