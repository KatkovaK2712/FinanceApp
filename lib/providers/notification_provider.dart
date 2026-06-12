import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  List<BudgetNotification> _notifications = [];

  List<BudgetNotification> get notifications => _notifications;
  List<BudgetNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;

  NotificationProvider() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('notifications');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      _notifications = decoded.map((n) => BudgetNotification.fromJson(n)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString('notifications', data);
  }

  Future<void> addNotification(BudgetNotification notification) async {
    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = BudgetNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        message: _notifications[index].message,
        date: _notifications[index].date,
        isRead: true,
        categoryId: _notifications[index].categoryId,
        budgetAmount: _notifications[index].budgetAmount,
        spentAmount: _notifications[index].spentAmount,
      );
      await _saveNotifications();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = BudgetNotification(
        id: _notifications[i].id,
        title: _notifications[i].title,
        message: _notifications[i].message,
        date: _notifications[i].date,
        isRead: true,
        categoryId: _notifications[i].categoryId,
        budgetAmount: _notifications[i].budgetAmount,
        spentAmount: _notifications[i].spentAmount,
      );
    }
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }
}