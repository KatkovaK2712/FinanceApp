import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/avatar_provider.dart';
import '../services/avatar_service.dart';
import '../services/api_service.dart';
import '../models/avatar.dart';
import 'setup_categories_screen.dart';
import 'setup_accounts_screen.dart';
import 'setup_budget_screen.dart';
import 'setup_method_screen.dart';
import 'setup_goals_screen.dart';
import 'home_settings_screen.dart';
import 'regular_payments_screen.dart';
import 'about_screen.dart';
import '../services/onboarding_service.dart';
import '../providers/onboarding_provider.dart';
import '../utils/snackbar_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userEmail;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AvatarProvider>(context, listen: false).loadAvatar();
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final email = await ApiService.getCurrentUserEmail();
    final userId = ApiService.currentUserId;
    setState(() {
      _userEmail = email;
      _userId = userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final avatarProvider = Provider.of<AvatarProvider>(context);
    final currentAvatar = avatarProvider.currentAvatar;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
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
            // Аватар и имя пользователя
            Center(
              child: Column(
                children: [
                  FutureBuilder<String?>(
                    future: AvatarService.getCustomImagePath(),
                    builder: (context, snapshot) {
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.pushNamed(
                              context, '/avatar_selection');
                          await avatarProvider.loadAvatar();
                          setState(() {});
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: (currentAvatar?.color ?? colorScheme.primary)
                                .withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: snapshot.hasData && snapshot.data != null
                              ? ClipOval(
                                  child: Image.file(
                                    File(snapshot.data!),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : currentAvatar != null
                                  ? Icon(
                                      currentAvatar.icon,
                                      size: 40,
                                      color: currentAvatar.color,
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 40,
                                      color: colorScheme.primary,
                                    ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userEmail?.split('@').first ?? 'Пользователь',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    _userEmail ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // ==================== НАСТРОЙКИ ВНЕШНЕГО ВИДА ====================

            // Тема
            _buildThemeSection(context, themeProvider),

            const Divider(),

            // Цветовая схема
            _buildColorSchemeSection(context, settingsProvider),

            const Divider(),

            // Размер шрифта
            _buildFontSizeSection(context, settingsProvider),

            const Divider(),

            // Метод ведения финансов
            _buildMenuItem(
              context,
              icon: Icons.trending_up,
              title: 'Метод ведения финансов',
              subtitle: settingsProvider.budgetMethod,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupMethodScreen(isFromRegistration: false),
                  ),
                );
              },
            ),

            const Divider(),
            // ==================== УПРАВЛЕНИЕ ====================

            // Настройки категорий
            _buildMenuItem(
              context,
              icon: Icons.category,
              title: 'Настройки категорий',
              subtitle: 'Управление категориями доходов и расходов',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupCategoriesScreen(isFromRegistration: false),
                  ),
                );
              },
            ),

            const Divider(),

            // Настройки счетов
            _buildMenuItem(
              context,
              icon: Icons.account_balance,
              title: 'Настройки счетов',
              subtitle: 'Управление счетами',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupAccountsScreen(isFromRegistration: false),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),

            const Divider(),

            // Цели
            _buildMenuItem(
              context,
              icon: Icons.flag,
              title: 'Цели',
              subtitle: 'Управление целями накопления',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupGoalsScreen(isFromRegistration: false),
                  ),
                );
              },
            ),

            const Divider(),

            // Настройки бюджета
            _buildMenuItem(
              context,
              icon: Icons.pie_chart,
              title: 'Настройки бюджета',
              subtitle: 'Установка лимитов по категориям',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetupBudgetScreen(isFromRegistration: false),
                  ),
                );
              },
            ),

            const Divider(),

            // Регулярные платежи
            _buildMenuItem(
              context,
              icon: Icons.repeat,
              title: 'Регулярные платежи',
              subtitle: 'Настройка автоплатежей',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegularPaymentsScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            // Настройки главного экрана
            _buildMenuItem(
              context,
              icon: Icons.home,
              title: 'Настройки главного экрана',
              subtitle: 'Отображение счетов на главном',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeSettingsScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            // Тумблер показа метода в отчетах
            SwitchListTile(
              title: const Text('Показывать метод учета в отчетах'),
              subtitle: const Text(
                'Отображение карточки с методом 50/30/20 в разделе "Отчеты"',
              ),
              value: settingsProvider.showMethodCard,
              onChanged: (value) {
                settingsProvider.toggleShowMethodCard();
              },
              secondary: Icon(Icons.pie_chart, color: colorScheme.primary),
              activeColor: colorScheme.primary,
            ),

            const Divider(),

            // ==================== ИНФОРМАЦИЯ ====================

            // О приложении
            _buildMenuItem(
              context,
              icon: Icons.info,
              title: 'О приложении',
              subtitle: 'Версия 1.0.0',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),

            const Divider(),

            // Обучение
            _buildMenuItem(
              context,
              icon: Icons.school,
              title: 'Обучение',
              subtitle: 'Пройти обучение заново',
              onTap: () async {
                await OnboardingService.resetOnboarding();
                final onboardingProvider =
                    Provider.of<OnboardingProvider>(context, listen: false);
                onboardingProvider.startModule('transactions');
                Navigator.pop(context);
                SnackbarUtils.showInfo(context, 'Обучение начнется сейчас');
              },
            ),

            const Divider(),

            // ==================== ВЫХОД ====================

            // Кнопка выхода
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Выход'),
                      content: const Text('Вы уверены, что хотите выйти?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Выйти'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Маленький котик
            Center(
              child: Column(
                children: [
                  Icon(Icons.pets,
                      color: colorScheme.primary.withOpacity(0.3), size: 30),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildThemeSection(BuildContext context, ThemeProvider themeProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.dark_mode, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Тема',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  context,
                  title: 'Светлая',
                  isSelected: themeProvider.themeMode == ThemeMode.light,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionButton(
                  context,
                  title: 'Тёмная',
                  isSelected: themeProvider.themeMode == ThemeMode.dark,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildThemeButton(
            context,
            title: 'Системная',
            isSelected: themeProvider.themeMode == ThemeMode.system,
            onTap: () => themeProvider.setThemeMode(ThemeMode.system),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: fullWidth ? double.infinity : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.primary : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSchemeSection(
      BuildContext context, SettingsProvider settingsProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = SettingsProvider.availableColors;
    final colorNames = SettingsProvider.colorNames;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.palette, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Цветовая схема',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isSelected = settingsProvider.colorIndex == index;
                return GestureDetector(
                  onTap: () => settingsProvider.setColorIndex(index),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors[index].withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? colors[index] : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: colors[index],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          colorNames[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? colors[index]
                                : Colors.grey.shade700,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.primary : Colors.grey.shade700,
          ),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildFontSizeSection(
      BuildContext context, SettingsProvider settingsProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final fontSizeNames = ['Маленький', 'Средний', 'Большой', 'Очень большой'];
    final currentFontSize = settingsProvider.fontScale;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.text_fields, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Размер шрифта',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Slider(
                  value: currentFontSize,
                  min: 0,
                  max: 3.0,
                  divisions: 3,
                  label: fontSizeNames[currentFontSize.toInt()],
                  onChanged: (value) {
                    settingsProvider.setFontScale(value);
                  },
                  activeColor: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      fontSizeNames[currentFontSize.toInt()],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFontSizePreview(context, 'Aa', 10),
                _buildFontSizePreview(context, 'Aa', 12),
                _buildFontSizePreview(context, 'Aa', 14),
                _buildFontSizePreview(context, 'Aa', 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizePreview(BuildContext context, String text, double size) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minWidth: 35),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w500,
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}
