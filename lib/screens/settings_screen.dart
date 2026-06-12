import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Карточка с темой
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dark_mode, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Тема оформления',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    RadioListTile<ThemeMode>(
                      title: const Text('Светлая'),
                      value: ThemeMode.light,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) => themeProvider.setThemeMode(value!),
                      activeColor: colorScheme.primary,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Темная'),
                      value: ThemeMode.dark,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) => themeProvider.setThemeMode(value!),
                      activeColor: colorScheme.primary,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Как в системе'),
                      value: ThemeMode.system,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) => themeProvider.setThemeMode(value!),
                      activeColor: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Карточка с цветовой схемой
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Цветовая схема',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Текущий выбранный цвет
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: settingsProvider.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: settingsProvider.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Текущий цвет: ${settingsProvider.colorName}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Сетка цветов
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: List.generate(8, (index) {
                        final colors = [
                          Colors.blue, Colors.green, Colors.red, Colors.purple,
                          Colors.orange, Colors.pink, Colors.teal, Colors.amber
                        ];
                        final names = [
                          'Синий', 'Зеленый', 'Красный', 'Фиолетовый',
                          'Оранжевый', 'Розовый', 'Бирюзовый', 'Янтарный'
                        ];
                        
                        final isSelected = settingsProvider.colorIndex == index;
                        final color = colors[index];
                        
                        return GestureDetector(
                          onTap: () => settingsProvider.setColorIndex(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? color.withOpacity(0.2)
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                  ? color 
                                  : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    names[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected 
                                        ? color 
                                        : colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const SizedBox(height: 20),
            
            // Маленький котик внизу
            Center(
              child: Column(
                children: [
                  Icon(Icons.pets, color: colorScheme.primary.withOpacity(0.3), size: 30),
                  const SizedBox(height: 4),
                  Text(
                    '🐱 Манеки Неко',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}