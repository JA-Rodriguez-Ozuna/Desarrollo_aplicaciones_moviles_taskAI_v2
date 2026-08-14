import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/gemini_service.dart';
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
  final GeminiService _gemini = GeminiService();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAnalyzing = false;
  bool _showForm = false;
  String _transcribedText = '';
  String _dueDateHint = '';
  DateTime? _resolvedDueDate;
  String? _localeId;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();
  TaskCategory _category = TaskCategory.personal;
  TaskPriority _priority = TaskPriority.media;

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
      _showForm = false;
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

    final String text = _transcribedText.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se detectó audio. Intenta hablar más cerca del micrófono.',
            ),
          ),
        );
      }
      return;
    }
    _analyzeWithAi(text);
  }

  Future<void> _analyzeWithAi(String text) async {
    setState(() => _isAnalyzing = true);
    try {
      final String? raw = await _gemini.analyzeVoiceText(text);
      final Map<String, dynamic>? data = _parseJson(raw);

      if (data == null) {
        _fallbackInvalidJson(text);
        return;
      }

      final String title = (data['title'] as String?)?.trim() ?? '';
      _titleController.text =
          title.isNotEmpty ? title : text.split(' ').take(6).join(' ');
      _descriptionController.text = (data['description'] as String?) ?? text;
      _category = _parseCategory(data['category'] as String?);
      _priority = _parsePriority(data['priority'] as String?);
      _dueDateHint = (data['dueDateHint'] as String?)?.trim() ?? '';
      _resolvedDueDate = _parseDueDate(data);

      if (mounted) setState(() => _showForm = true);
    } catch (e) {
      debugPrint('Gemini voice analysis error: $e');
      await _createTaskFromRawTextOnly(text, error: e);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /// Gemini respondió pero el texto no es JSON parseable: deja solo el
  /// título prellenado y que el usuario complete el resto a mano.
  void _fallbackInvalidJson(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo analizar. Revisa los campos y guarda manualmente.',
          ),
        ),
      );
    }
    _titleController.text = text.split(' ').take(6).join(' ');
    _descriptionController.clear();
    _category = TaskCategory.personal;
    _priority = TaskPriority.media;
    _dueDateHint = '';
    _resolvedDueDate = null;
    if (mounted) setState(() => _showForm = true);
  }

  /// La llamada a Gemini falló: no bloquea al usuario, crea la tarea
  /// directamente con el texto dictado como título, igual que el
  /// comportamiento previo a la integración con IA.
  ///
  /// TEMPORAL: muestra el error exacto (en vez de un mensaje genérico de
  /// "sin conexión") para diagnosticar qué está fallando realmente contra
  /// Firebase AI Logic. Revertir a un mensaje amigable una vez resuelto.
  Future<void> _createTaskFromRawTextOnly(String text, {Object? error}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exacto: ${error?.toString() ?? "desconocido"}'),
          duration: const Duration(seconds: 8),
        ),
      );
    }

    final Task task = Task.create(
      title: text.split(' ').take(6).join(' '),
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
    context.go('/');
  }

  /// Convierte el dueDate (yyyy-MM-dd) que devuelve Gemini a DateTime real.
  /// Si hasDueDate es false, o el string no parsea, no hay fecha detectada
  /// — Task.dueDate no es nullable, así que _createTask cae al fallback de
  /// mañana en ese caso, igual que antes de este fix.
  DateTime? _parseDueDate(Map<String, dynamic> data) {
    if (data['hasDueDate'] != true) return null;
    final String? dueDateStr = data['dueDate'] as String?;
    if (dueDateStr == null || dueDateStr.isEmpty) return null;
    try {
      return DateTime.parse(dueDateStr);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseJson(String? raw) {
    if (raw == null) return null;
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    try {
      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  TaskCategory _parseCategory(String? value) => TaskCategory.values.firstWhere(
        (TaskCategory c) => c.name == value,
        orElse: () => TaskCategory.personal,
      );

  TaskPriority _parsePriority(String? value) => TaskPriority.values.firstWhere(
        (TaskPriority p) => p.name == value,
        orElse: () => TaskPriority.media,
      );

  String _categoryLabel(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.trabajo:
        return 'Trabajo';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.estudio:
        return 'Estudio';
      case TaskCategory.urgente:
        return 'Urgente';
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    final Task task = Task.create(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      priority: _priority,
      dueDate: _resolvedDueDate ?? DateTime.now().add(const Duration(days: 1)),
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

  void _recordAgain() {
    setState(() {
      _showForm = false;
      _transcribedText = '';
      _dueDateHint = '';
      _resolvedDueDate = null;
      _titleController.clear();
      _descriptionController.clear();
      _category = TaskCategory.personal;
      _priority = TaskPriority.media;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _pulseController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Captura por Voz')),
      body: SafeArea(
        child: _isAnalyzing
            ? const _AnalyzingView()
            : _showForm
                ? _buildForm(theme)
                : _buildRecorder(theme, colors),
      ),
    );
  }

  Widget _buildRecorder(ThemeData theme, ColorScheme colors) {
    return SingleChildScrollView(
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
                : 'Tu voz se convierte en tarea con IA',
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
            child: Semantics(
              button: true,
              label: _isListening
                  ? 'Detener captura por voz'
                  : 'Iniciar captura por voz',
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
                    color: _isListening ? colors.onError : colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_transcribedText.isNotEmpty)
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
                  Text(_transcribedText, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
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
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Tarea extraída por IA', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Nombre de la tarea',
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Detalles de la tarea',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.label_outline),
              ),
              items: TaskCategory.values
                  .map(
                    (TaskCategory cat) => DropdownMenuItem<TaskCategory>(
                      value: cat,
                      child: Text(_categoryLabel(cat)),
                    ),
                  )
                  .toList(),
              onChanged: (TaskCategory? value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 24),
            Text('Prioridad', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const <ButtonSegment<TaskPriority>>[
                ButtonSegment<TaskPriority>(
                  value: TaskPriority.alta,
                  label: Text('Alta'),
                  icon: Icon(Icons.keyboard_double_arrow_up),
                ),
                ButtonSegment<TaskPriority>(
                  value: TaskPriority.media,
                  label: Text('Media'),
                  icon: Icon(Icons.drag_handle),
                ),
                ButtonSegment<TaskPriority>(
                  value: TaskPriority.baja,
                  label: Text('Baja'),
                  icon: Icon(Icons.keyboard_double_arrow_down),
                ),
              ],
              selected: <TaskPriority>{_priority},
              onSelectionChanged: (Set<TaskPriority> selected) {
                setState(() => _priority = selected.first);
              },
            ),
            if (_resolvedDueDate != null || _dueDateHint.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resolvedDueDate != null
                            ? 'Fecha detectada: '
                                '${DateFormat('dd/MM/yyyy').format(_resolvedDueDate!)}'
                                '${_dueDateHint.isNotEmpty ? ' ($_dueDateHint)' : ''}'
                            : 'Fecha mencionada: $_dueDateHint',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add_task),
              label: const Text('Crear tarea'),
              onPressed: _createTask,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Grabar de nuevo'),
              onPressed: _recordAgain,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analyzing state ─────────────────────────────────────────────────────────

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analizando con IA...'),
        ],
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
          _HelpItem('La IA extrae título, descripción, categoría y prioridad'),
          _HelpItem('Puedes editar cualquier campo antes de guardar'),
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
