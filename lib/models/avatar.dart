import 'package:flutter/material.dart';

class Avatar {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSystem;
  final String? imagePath;

  const Avatar({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isSystem = true,
    this.imagePath,
  });
}

// Список системных аватаров
const List<Avatar> systemAvatars = [
  Avatar(id: 'cat', name: 'Котик', icon: Icons.pets, color: Colors.orange),
  Avatar(id: 'user', name: 'Пользователь', icon: Icons.person, color: Colors.blue),
  Avatar(id: 'star', name: 'Звезда', icon: Icons.star, color: Colors.amber),
  Avatar(id: 'heart', name: 'Сердце', icon: Icons.favorite, color: Colors.red),
  Avatar(id: 'flower', name: 'Цветок', icon: Icons.local_florist, color: Colors.pink),
  Avatar(id: 'bird', name: 'Птичка', icon: Icons.flutter_dash, color: Colors.teal),
  Avatar(id: 'book', name: 'Книга', icon: Icons.book, color: Colors.purple),
  Avatar(id: 'camera', name: 'Камера', icon: Icons.camera_alt, color: Colors.brown),
  Avatar(id: 'game', name: 'Игры', icon: Icons.sports_esports, color: Colors.green),
  Avatar(id: 'music', name: 'Музыка', icon: Icons.music_note, color: Colors.indigo),
];