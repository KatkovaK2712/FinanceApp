import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../providers/settings_provider.dart'; // 👈 Добавить эту строку
import '../utils/snackbar_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _pawController;
  late final Animation<double> _pawAnimation;

  @override
  void initState() {
    super.initState();

    _pawController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pawAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _pawController, curve: Curves.easeInOut),
    );
  }

  void _fillTestData() {
    _emailController.text = 'test@user.com';
    _passwordController.text = '12345678a';
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (success && mounted) {
          SnackbarUtils.showSuccess(context, 'Добро пожаловать!');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          if (mounted) {
            SnackbarUtils.showError(context, 'Неверный email или пароль');
          }
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Ошибка: $e');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.15),
              colorScheme.secondary.withOpacity(0.1),
              colorScheme.tertiary.withOpacity(0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Манеки Неко с градиентом на самой иконке
                  Container(
                    width: 85, // Уменьшил размер
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _pawController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _pawAnimation.value * 0.02,
                          child: child,
                        );
                      },
                      child: ClipOval(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                Color(0xFF4158D0), // Синий
                                Color(0xFFC850C0), // Розово-фиолетовый
                                Color(0xFFFFCC70), // Желтый для акцента
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds);
                          },
                          child: Image.asset(
                            'assets/images/maneki-neko.png',
                            fit: BoxFit.contain,
                            color: Colors.white, // Базовый цвет для градиента
                            colorBlendMode: BlendMode.srcATop,
                            errorBuilder: (context, error, stackTrace) {
                              print('😿 Ошибка загрузки картинки: $error');
                              return Container(
                                color: Colors.purple.withOpacity(0.2),
                                child: Icon(
                                  Icons.pets,
                                  size: 70,
                                  color: Colors.purple,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        duration: 800.ms,
                        curve: Curves.easeOut,
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        curve: Curves.elasticOut,
                        duration: 1000.ms,
                      ),
                  const SizedBox(height: 20),

                  Text(
                    'Личные финансы',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      shadows: [
                        Shadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),

                  const SizedBox(height: 8),

                  Text(
                    '🐾 Лапка удачи в твоих финансах',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 40),

                  Card(
                    elevation: 12,
                    shadowColor: colorScheme.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.white
                                : Colors.grey.shade900,
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.white.withOpacity(0.9)
                                : Colors.grey.shade800.withOpacity(0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(28.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email,
                                    color: colorScheme.primary),
                                hintText: 'neko@example.com',
                              ),
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Введите email' : null,
                            )
                                .animate()
                                .fadeIn(delay: 500.ms)
                                .slideX(begin: 0.2),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                prefixIcon: Icon(Icons.lock,
                                    color: colorScheme.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: colorScheme.primary.withOpacity(0.7),
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Введите пароль' : null,
                            )
                                .animate()
                                .fadeIn(delay: 600.ms)
                                .slideX(begin: 0.2),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Войти',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.arrow_forward,
                                              color: Colors.white, size: 20),
                                        ],
                                      ),
                              ),
                            ).animate().fadeIn(delay: 700.ms).scale(),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _fillTestData,
                              icon: Icon(Icons.bug_report,
                                  size: 18, color: colorScheme.primary),
                              label: Text(
                                '🐾 Заполнить тестовые данные',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Нет аккаунта? ',
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Завести котика',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite,
                          size: 16,
                          color: colorScheme.primary.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      Icon(Icons.pets,
                          size: 20,
                          color: colorScheme.primary.withOpacity(0.5)),
                      const SizedBox(width: 8),
                      Icon(Icons.favorite,
                          size: 16,
                          color: colorScheme.primary.withOpacity(0.3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pawController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
