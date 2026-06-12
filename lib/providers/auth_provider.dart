import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userId;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkSavedUser();
  }

  Future<void> _checkSavedUser() async {
    final hasUser = await ApiService.hasSavedUser();
    _isAuthenticated = hasUser;
    _userId = ApiService.currentUserId;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final success = await ApiService.login(email, password);

    if (success) {
      _isAuthenticated = true;
      _userId = ApiService.currentUserId;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final success = await ApiService.register(email, password);

    if (success) {
      _isAuthenticated = true;
      _userId = ApiService.currentUserId;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await ApiService.logout();
    await ApiService.clearAllUserData();

    _isAuthenticated = false;
    _userId = null;
    _isLoading = false;
    notifyListeners();
  }
}
