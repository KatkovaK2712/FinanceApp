import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'setup_accounts_screen.dart';
import 'setup_goals_screen.dart';

class SetupMethodScreen extends StatefulWidget {
  final bool isFromRegistration;

  const SetupMethodScreen({
    super.key,
    this.isFromRegistration = false,
  });

  @override
  State<SetupMethodScreen> createState() => _SetupMethodScreenState();
}

class _SetupMethodScreenState extends State<SetupMethodScreen> {
  late String _selectedMethod;
  
  final _needsController = TextEditingController();
  final _wantsController = TextEditingController();
  final _savingsController = TextEditingController();
  final _emergencyController = TextEditingController();
  
  bool _showCustomFields = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _selectedMethod = settings.budgetMethod;
    _showCustomFields = _selectedMethod == 'custom';
  }

  @override
  void dispose() {
    _needsController.dispose();
    _wantsController.dispose();
    _savingsController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  void _saveMethod() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.setBudgetMethod(_selectedMethod);
    
    if (widget.isFromRegistration) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SetupAccountsScreen(isFromRegistration: true),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.isFromRegistration)
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetupAccountsScreen(isFromRegistration: true),
                  ),
                );
              },
              child: const Text(
                'Пропустить',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Выбор метода учёта\nличных финансов',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildMethodCard(
                      title: '50/30/20',
                      description: '50% дохода направляется на обязательные нужды, 30% - на желания и личные расходы, 20% - на накопления или погашение долгов',
                      value: '50/30/20',
                      icon: Icons.pie_chart,
                      selectedMethod: _selectedMethod,
                      onTap: () => setState(() {
                        _selectedMethod = '50/30/20';
                        _showCustomFields = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildMethodCard(
                      title: '20/30/50',
                      description: '20% - на обязательные нужды, 30% - на желания и личные расходы, развлечения, 50% - на сбережения',
                      value: '20/30/50',
                      icon: Icons.trending_up,
                      selectedMethod: _selectedMethod,
                      onTap: () => setState(() {
                        _selectedMethod = '20/30/50';
                        _showCustomFields = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildMethodCard(
                      title: '30/30/30/10',
                      description: '30% - обязательные расходы, 30% - для долгосрочных сбережений и инвестиций, 30% - желания и личные расходы, развлечения, 10% - на непредвиденные расходы',
                      value: '30/30/30/10',
                      icon: Icons.account_balance,
                      selectedMethod: _selectedMethod,
                      onTap: () => setState(() {
                        _selectedMethod = '30/30/30/10';
                        _showCustomFields = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildMethodCard(
                      title: 'Свой вариант',
                      description: 'Настройте свои проценты',
                      value: 'custom',
                      icon: Icons.settings,
                      selectedMethod: _selectedMethod,
                      onTap: () => setState(() {
                        _selectedMethod = 'custom';
                        _showCustomFields = true;
                      }),
                    ),
                    
                    if (_showCustomFields) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Введите проценты:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _needsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Нужды',
                                        suffixText: '%',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _wantsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Желания',
                                        suffixText: '%',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _savingsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Сбережения',
                                        suffixText: '%',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _emergencyController,
                                      decoration: const InputDecoration(
                                        labelText: 'Резерв',
                                        suffixText: '%',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Выбранный метод будет использоваться для отчётов и планирования бюджета. Его можно будет изменить позже в настройках профиля.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveMethod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isFromRegistration ? 'Продолжить' : 'Сохранить',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String description,
    required String value,
    required IconData icon,
    required String selectedMethod,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedMethod == value;
    
    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? colorScheme.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}