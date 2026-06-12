import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

class OnboardingProvider extends ChangeNotifier {
  bool _showOnboarding = false;
  String _currentModule = 'transactions';

  bool get showOnboarding => _showOnboarding;
  String get currentModule => _currentModule;

  Future<void> checkOnboarding() async {
    _showOnboarding = await OnboardingService.needsOnboarding();
    notifyListeners();
  }

  void startModule(String module) {
    _currentModule = module;
    _showOnboarding = true;
    // Не вызываем resetOnboarding здесь, так как уже вызвали в profile_screen
    notifyListeners();
  }

  void completeOnboarding() {
    _showOnboarding = false;
    OnboardingService.setOnboardingCompleted();
    notifyListeners();
  }
}
