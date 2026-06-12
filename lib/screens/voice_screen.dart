import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/permission_service.dart';
import '../services/secure_storage_service.dart';

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _transcribedText = '';
  String? _localeId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final bool available = await _speech.initialize(
      onError: (dynamic e) => debugPrint('Speech error: $e'),
      onStatus: (String status) {
        if ((status == 'done' || status == 'notListening') && _isListening) {
          _stopListening();
        }
      },
    );

    if (available) {
      // Buscar locale español; si no está disponible, usar locale del sistema
      final List<LocaleName> locales = await _speech.locales();
      final Iterable<LocaleName> spanish =
          locales.where((LocaleName l) => l.localeId.startsWith('es'));
      if (spanish.isNotEmpty) {
        _localeId = spanish.first.localeId;
      } else {
        final LocaleName? system = await _speech.systemLocale();
        _localeId = system?.localeId;
      }
    }

    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _startListening() async {
    final bool granted =
        await PermissionService.requestMicrophonePermission(context);
    if (!granted || !mounted) return;

    setState(() {
      _isListening = true;
      _transcribedText = '';
    });
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (mounted) {
          setState(() => _transcribedText = result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: _localeId,
      ),
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _createTask() async {
    final String text = _transcribedText.trim();
    if (text.isEmpty) return;

    final List<String> words = text.split(' ');
    final String title = words.take(6).join(' ');

    final Task task = Task.create(
      title: title,
      description: text,
      category: TaskCategory.personal,
      priority: TaskPriority.media,
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    ref.read(taskProvider.notifier).addTask(task);
    await SecureStorageService.saveValue(
      'last_voice_capture',
      DateTime.now().toIso8601String(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tarea "${task.title}" creada'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    context.go('/');
  }

  @override
  void dispose() {
    _speech.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura por Voz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              _isListening ? 'Escuchando...' : 'Presiona para hablar',
              style: theme.textTheme.titleLarge?.copyWith(
                color: _isListening ? colors.primary : colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isListening
                  ? 'Toca el botón para detener'
                  : 'Tu voz se convierte en tarea',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const _HelpCard(),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (BuildContext context, Widget? child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _speechAvailable
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? colors.error : colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? colors.error : colors.primary)
                            .withAlpha(100),
                        blurRadius: 28,
                        spreadRadius: _isListening ? 10 : 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 60,
                    color: _isListening
                        ? colors.onError
                        : colors.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (_transcribedText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Texto reconocido',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _transcribedText,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _transcribedText = ''),
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _createTask,
                      icon: const Icon(Icons.add_task),
                      label: const Text('Crear tarea'),
                    ),
                  ),
                ],
              ),
            ],
            if (!_speechAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'El reconocimiento de voz no está disponible en este dispositivo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Help card ──────────────────────────────────────────────────────────────

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.info_outline_rounded,
          color: colors.primary,
          size: 20,
        ),
        title: Text(
          '¿Cómo usar la captura por voz?',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: const [
          _HelpItem('Presiona el botón del micrófono'),
          _HelpItem('Habla claramente describiendo tu tarea'),
          _HelpItem('Ejemplo: "Entregar asignación de Flutter el viernes"'),
          _HelpItem('La app crea la tarea automáticamente al terminar'),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String text;
  const _HelpItem(this.text);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
