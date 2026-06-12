import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/register_screen.dart';
import 'screens/setup_method_screen.dart';
import 'screens/setup_goals_screen.dart';
import 'screens/setup_categories_screen.dart';
import 'screens/setup_accounts_screen.dart';
import 'screens/setup_budget_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/avatar_provider.dart';
import 'screens/home_settings_screen.dart';
import 'services/recurring_service.dart';
import 'providers/notification_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/api_service.dart'; // 👈 ДОБАВИТЬ
import 'services/test_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);

  ApiService.init(); // 👈 ДОБАВИТЬ (ОТКЛЮЧАЕТ ПРОВЕРКУ SSL)
  await ApiService.loadUserId();
  if (ApiService.currentUserId != null) {
    await TestDataGenerator.generateTestData();
  }
  runApp(const MyApp());
  Future.delayed(const Duration(seconds: 2), () async {
    await RecurringService.processRecurringPayments();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AvatarProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
      ],
      child: Consumer3<ThemeProvider, SettingsProvider, AuthProvider>(
        builder:
            (context, themeProvider, settingsProvider, authProvider, child) {
          return MaterialApp(
            title: 'Личные финансы',
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'), // 👈 ТОЛЬКО РУССКИЙ
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: settingsProvider.primaryColor,
              colorScheme: ColorScheme.light(
                primary: settingsProvider.primaryColor,
                secondary: settingsProvider.primaryColor.withOpacity(0.7),
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                surfaceTintColor: Colors.transparent,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsProvider.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: settingsProvider.primaryColor,
              colorScheme: ColorScheme.dark(
                primary: settingsProvider.primaryColor,
                secondary: settingsProvider.primaryColor.withOpacity(0.7),
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                surfaceTintColor: Colors.transparent,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsProvider.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: ApiService.currentUserId != null
                ? const HomeScreen()
                : const LoginScreen(),
            builder: (context, child) {
              final bottomPadding = MediaQuery.of(context).padding.bottom;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: settingsProvider
                      .getFontScale()
                      .clamp(0.8, 1.5), // ограничь минимальный масштаб
                  padding: MediaQuery.of(context).padding.copyWith(
                        bottom: bottomPadding + 5,
                      ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 5),
                    child: child,
                  ),
                ),
              );
            },
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/setup_method': (context) => const SetupMethodScreen(),
              '/setup_goals': (context) => const SetupGoalsScreen(),
              '/setup_categories': (context) => const SetupCategoriesScreen(),
              '/setup_accounts': (context) => const SetupAccountsScreen(),
              '/setup_budget': (context) => const SetupBudgetScreen(),
              '/home': (context) => HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/profile': (context) => ProfileScreen(),
              '/home_settings': (context) => const HomeSettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
