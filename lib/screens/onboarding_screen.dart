import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';

class _OnboardingSlide {
  final String emoji;
  final String title;
  final String subtitle;

  const _OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    emoji: '✨',
    title: 'Bienvenido a TaskAI',
    subtitle:
        'Tu asistente inteligente para gestionar tareas universitarias',
  ),
  _OnboardingSlide(
    emoji: '📋',
    title: 'Organiza tus tareas',
    subtitle:
        'Crea, edita y filtra tareas por categoría y prioridad. '
        'Sincronización automática en la nube.',
  ),
  _OnboardingSlide(
    emoji: '📸',
    title: 'Captura con la cámara',
    subtitle:
        'Apunta al pizarrón o tus apuntes y la IA extrae automáticamente '
        'todos los datos de la tarea.',
  ),
  _OnboardingSlide(
    emoji: '🎙️',
    title: 'Dicta por voz',
    subtitle:
        'Habla en español y Gemini convierte tu nota en una tarea completa '
        'con fecha y prioridad.',
  ),
  _OnboardingSlide(
    emoji: '🔔',
    title: 'Nunca olvides una entrega',
    subtitle:
        'Recibe recordatorios 24 horas y 1 hora antes de que venza cada '
        'tarea.',
  ),
];

const Color _backgroundColor = Color(0xFF1A1040);
const Color _primaryColor = Color(0xFF6B5AED);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (int index) =>
                  setState(() => _currentPage = index),
              itemBuilder: (BuildContext context, int index) {
                final _OnboardingSlide slide = _slides[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          slide.emoji,
                          key: ValueKey<int>(index),
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey<int>(index),
                          children: <Widget>[
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (!isLastPage)
              Positioned(
                top: 8,
                right: 8,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Saltar'),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _slides.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _primaryColor
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FilledButton(
                onPressed: isLastPage ? _finish : _next,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(isLastPage ? '¡Empezar!' : 'Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
