import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import '../utils/snackbar_utils.dart';

class OnboardingOverlay extends StatefulWidget {
  final Widget child;
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;

  const OnboardingOverlay({
    super.key,
    required this.child,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentStep = 0;
  bool _isVisible = true;
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadStep();
  }

  Future<void> _loadStep() async {
    final step = await OnboardingService.getCurrentStep();
    if (mounted && step < widget.steps.length) {
      setState(() {
        _currentStep = step;
      });
      // Даем время для отрисовки виджета
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTooltip();
        }
      });
    }
  }

  void _nextStep() {
    if (_currentStep + 1 < widget.steps.length) {
      setState(() {
        _currentStep++;
      });
      OnboardingService.saveCurrentStep(_currentStep);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTooltip();
        }
      });
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    setState(() {
      _isVisible = false;
    });
    OnboardingService.setOnboardingCompleted();
    widget.onComplete();
  }

  void _skipOnboarding() {
    setState(() {
      _isVisible = false;
    });
    OnboardingService.setOnboardingCompleted();
    widget.onComplete();
  }

  void _showTooltip() {
    final step = widget.steps[_currentStep];
    
    final RenderBox? renderBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // Показываем диалог-подсказку
    showDialog(
      context: _targetKey.currentContext!,
      barrierDismissible: false,
      builder: (dialogContext) => Stack(
        children: [
          // Затемненный фон
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
          
          // Подсветка целевого элемента
          Positioned(
            left: position.dx,
            top: position.dy,
            width: size.width,
            height: size.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Подсказка
          Positioned(
            left: 20,
            right: 20,
            bottom: step.position == OverlayPosition.bottom ? 100 : null,
            top: step.position == OverlayPosition.top ? 100 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _skipOnboarding();
                          },
                          child: const Text(
                            'Пропустить',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _nextStep();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(dialogContext).colorScheme.primary,
                          ),
                          child: Text(
                            _currentStep + 1 == widget.steps.length ? 'Завершить' : 'Далее',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _currentStep >= widget.steps.length) {
      return widget.child;
    }
    
    return Container(
      key: _targetKey,
      child: widget.child,
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final OverlayPosition position;
  
  OnboardingStep({
    required this.title,
    required this.description,
    this.position = OverlayPosition.bottom,
  });
}

enum OverlayPosition { top, bottom }