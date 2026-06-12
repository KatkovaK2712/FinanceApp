import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../models/avatar.dart';

class AvatarProvider extends ChangeNotifier {
  Avatar? _currentAvatar;

  Avatar? get currentAvatar => _currentAvatar;

  Future<void> loadAvatar() async {
    _currentAvatar = await AvatarService.getAvatar();
    notifyListeners();
  }

  Future<void> updateAvatar() async {
    _currentAvatar = await AvatarService.getAvatar();
    notifyListeners();
  }
}