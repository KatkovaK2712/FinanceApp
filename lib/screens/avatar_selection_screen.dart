import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/avatar.dart';
import '../services/avatar_service.dart';
import '../providers/avatar_provider.dart';
import '../utils/snackbar_utils.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final Function(Avatar) onAvatarSelected;

  const AvatarSelectionScreen({
    super.key,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  Avatar? _selectedAvatar;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбрать аватар'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // Превью выбранного аватара
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Предпросмотр',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: (_selectedAvatar?.color ?? Colors.grey)
                          .withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: _selectedImage != null
                        ? ClipOval(
                            child: Image.file(
                              _selectedImage!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            _selectedAvatar?.icon ?? Icons.person,
                            size: 50,
                            color: _selectedAvatar?.color ?? Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAvatar?.name ?? 'Не выбран',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Секция "Загрузить из галереи"
                  const Text(
                    'Загрузить свое',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.photo_library, color: Colors.blue),
                      ),
                      title: const Text('Выбрать из галереи'),
                      subtitle: const Text('Загрузите свое изображение'),
                      onTap: _pickImageFromGallery,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Секция системных аватаров
                  const Text(
                    'Системные',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: systemAvatars.length,
                    itemBuilder: (context, index) {
                      final avatar = systemAvatars[index];
                      final isSelected = _selectedAvatar?.id == avatar.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAvatar = avatar;
                            _selectedImage = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? avatar.color.withOpacity(0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? avatar.color
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            avatar.icon,
                            size: 40,
                            color: isSelected ? avatar.color : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () async {
              if (_selectedImage != null) {
                // Сохраняем изображение
                await AvatarService.saveCustomImage(_selectedImage!);
                // Создаем объект аватара для отображения
                final customAvatar = Avatar(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'Мое фото',
                  icon: Icons.person,
                  color: Colors.blue,
                  isSystem: false,
                  imagePath: _selectedImage!.path,
                );
                // Обновляем провайдер
                final avatarProvider =
                    Provider.of<AvatarProvider>(context, listen: false);
                await avatarProvider.updateAvatar();
                widget.onAvatarSelected(customAvatar);
                Navigator.pop(context);
                SnackbarUtils.showSuccess(context, 'Аватар сохранен');
              } else if (_selectedAvatar != null) {
                await AvatarService.saveAvatar(
                  _selectedAvatar!.id,
                  _selectedAvatar!.icon,
                  _selectedAvatar!.color,
                );
                // Обновляем провайдер
                final avatarProvider =
                    Provider.of<AvatarProvider>(context, listen: false);
                await avatarProvider.updateAvatar();
                widget.onAvatarSelected(_selectedAvatar!);
                Navigator.pop(context);
                SnackbarUtils.showSuccess(context, 'Аватар сохранен');
              } else {
                SnackbarUtils.showInfo(context, 'Выберите аватар');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Сохранить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedAvatar = null;
      });
    }
  }
}
