import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/avatar.dart';
import 'api_service.dart';

class AvatarService {
  static String? get _userId => ApiService.currentUserId;

  static Future<String> _getUserIdSafe() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return 'default_user';
    }
    return userId;
  }

  static Future<void> saveAvatar(
      String avatarId, IconData icon, Color color) async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('avatar_id_$userId', avatarId);
    await prefs.setInt('avatar_icon_$userId', icon.codePoint);
    await prefs.setInt('avatar_color_$userId', color.value);
    await prefs.remove('avatar_image_path_$userId');
    print('💾 Системный аватар сохранен для пользователя $userId');
  }

  static Future<void> saveCustomImage(File imageFile) async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'avatar_$userId.png';
    final newPath = '${appDir.path}/$fileName';
    await imageFile.copy(newPath);

    await prefs.setString('avatar_image_path_$userId', newPath);
    await prefs.remove('avatar_id_$userId');
    await prefs.remove('avatar_icon_$userId');
    await prefs.remove('avatar_color_$userId');

    print(
        '💾 Пользовательское изображение сохранено для пользователя $userId: $newPath');
  }

  static Future<Avatar?> getAvatar() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();

    final imagePath = prefs.getString('avatar_image_path_$userId');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        print('✅ Файл найден для пользователя $userId: $imagePath');
        return Avatar(
          id: 'custom_$userId',
          name: 'Мое фото',
          icon: Icons.person,
          color: Colors.blue,
          isSystem: false,
          imagePath: imagePath,
        );
      } else {
        print('❌ Файл не найден для пользователя $userId: $imagePath');
        await prefs.remove('avatar_image_path_$userId');
      }
    }

    final avatarId = prefs.getString('avatar_id_$userId');
    final iconCodePoint = prefs.getInt('avatar_icon_$userId');
    final colorValue = prefs.getInt('avatar_color_$userId');

    if (avatarId != null && iconCodePoint != null && colorValue != null) {
      return Avatar(
        id: avatarId,
        name: 'Пользовательский',
        icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
        color: Color(colorValue),
        isSystem: true,
      );
    }
    return null;
  }

  static Future<String?> getCustomImagePath() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('avatar_image_path_$userId');
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  static Future<void> clearAvatar() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();

    // Удаляем файл изображения если он есть
    final imagePath = prefs.getString('avatar_image_path_$userId');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Файл аватара удален: $imagePath');
      }
    }

    await prefs.remove('avatar_id_$userId');
    await prefs.remove('avatar_icon_$userId');
    await prefs.remove('avatar_color_$userId');
    await prefs.remove('avatar_image_path_$userId');
    print('🗑️ Аватар очищен для пользователя $userId');
  }

  // 👇 ДОБАВЛЕНО: очистка всех данных аватара
  static Future<void> clearAllAvatarData() async {
    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();

    // Удаляем файл изображения
    final imagePath = prefs.getString('avatar_image_path_$userId');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await prefs.remove('avatar_id_$userId');
    await prefs.remove('avatar_icon_$userId');
    await prefs.remove('avatar_color_$userId');
    await prefs.remove('avatar_image_path_$userId');
    print('🗑️ Все данные аватара очищены для пользователя $userId');
  }
}
