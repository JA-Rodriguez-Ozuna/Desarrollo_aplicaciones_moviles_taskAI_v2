import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/gemini_service.dart';
import '../services/permission_service.dart';
import '../services/secure_storage_service.dart';

class CameraAiScreen extends ConsumerStatefulWidget {
  const CameraAiScreen({super.key});

  @override
  ConsumerState<CameraAiScreen> createState() => _CameraAiScreenState();
}

class _CameraAiScreenState extends ConsumerState<CameraAiScreen> {
  CameraController? _cameraController;
  final GeminiService _gemini = GeminiService();
  bool _cameraReady = false;
  bool _permissionDenied = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final bool granted =
        await PermissionService.requestCameraPermission(context);
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No se encontró cámara disponible.');
        }
        return;
      }

      final CameraDescription camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error al inicializar la cámara.');
      }
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _takePhoto() async {
    final CameraController? controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isAnalyzing) {
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final XFile file = await controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      final String? raw = await _gemini.analyzeImage(bytes);
      final Map<String, dynamic>? data = _parseJson(raw);

      if (data == null) {
        _showError('No se pudo interpretar la respuesta de la IA.');
        return;
      }

      final bool hasTask = data['hasTask'] == true;
      final String title = (data['title'] as String?)?.trim() ?? '';
      if (!hasTask || title.isEmpty) {
        _showError('No se encontró información de tarea en la imagen.');
        return;
      }

      final String description = (data['description'] as String?) ?? '';
      final TaskCategory category =
          _parseCategory(data['category'] as String?);
      final TaskPriority priority =
          _parsePriority(data['priority'] as String?);

      if (mounted) _showPreview(title, description, category, priority);
    } catch (e) {
      _showError('No se pudo analizar la imagen. Intenta de nuevo.');
      debugPrint('Gemini image analysis error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPreview(
    String title,
    String description,
    TaskCategory category,
    TaskPriority priority,
  ) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => _TaskPreviewSheet(
        title: title,
        description: description,
        category: category,
        priority: priority,
        onConfirm: () async {
          final Task task = Task.create(
            title: title,
            description: description,
            category: category,
            priority: priority,
            dueDate: DateTime.now().add(const Duration(days: 1)),
          );
          ref.read(taskProvider.notifier).addTask(task);
          await SecureStorageService.saveValue(
            'last_camera_ai_scan',
            DateTime.now().toIso8601String(),
          );
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tarea "$title" creada')),
            );
            context.go('/');
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _PermissionDeniedView(onBack: () => context.go('/'));
    }
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onBack: () => context.go('/'));
    }
    if (!_cameraReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Foto IA'),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          const _InstructionOverlay(),
          if (_isAnalyzing) const _AnalyzingOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 110,
            child: Center(
              child: _CaptureButton(
                enabled: !_isAnalyzing,
                onPressed: _takePhoto,
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _HelpPanel(),
          ),
        ],
      ),
    );
  }
}

// ── Overlays ─────────────────────────────────────────────────────────────

class _InstructionOverlay extends StatelessWidget {
  const _InstructionOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Apunta al pizarrón o papel con tu tarea',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Analizando con IA...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _CaptureButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tomar foto',
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Icon(
            Icons.camera_alt,
            color: enabled ? Colors.black87 : Colors.black26,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet preview ────────────────────────────────────────────────────

class _TaskPreviewSheet extends StatelessWidget {
  final String title;
  final String description;
  final TaskCategory category;
  final TaskPriority priority;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _TaskPreviewSheet({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Tarea detectada — revisar',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Row(label: 'Título', value: title),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Row(label: 'Descripción', value: description),
            ],
            const SizedBox(height: 10),
            _Row(label: 'Categoría', value: category.name),
            const SizedBox(height: 10),
            _Row(label: 'Prioridad', value: priority.name),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Crear tarea'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// ── Error / Permission views ────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onBack;
  const _PermissionDeniedView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Foto IA')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 72, color: theme.colorScheme.outline),
              const SizedBox(height: 20),
              Text(
                'Permiso de cámara requerido',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Habilita el permiso de cámara en Configuración del sistema para usar Foto IA.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: onBack, child: const Text('Volver al inicio')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Foto IA')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 72, color: theme.colorScheme.error),
              const SizedBox(height: 20),
              Text(message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                  onPressed: onBack, child: const Text('Volver al inicio')),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Help panel (colapsable, máx 30% pantalla) ──────────────────────────────

class _HelpPanel extends StatefulWidget {
  const _HelpPanel();

  @override
  State<_HelpPanel> createState() => _HelpPanelState();
}

class _HelpPanelState extends State<_HelpPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final double expandedH = MediaQuery.of(context).size.height * 0.29;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: _expanded ? expandedH : 52,
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '¿Cómo usar Foto IA?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Divider(color: Colors.white24, height: 1),
                    SizedBox(height: 10),
                    _HelpRow(
                        'Apunta la cámara a un pizarrón, papel o libro con tu tarea'),
                    _HelpRow('Toca el botón blanco para tomar la foto'),
                    _HelpRow(
                        'La IA analiza la imagen y extrae título, descripción, categoría y prioridad'),
                    _HelpRow('Revisa la tarea sugerida antes de crearla'),
                    _HelpRow(
                        'Si la imagen no tiene una tarea clara, no se crea nada'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String text;
  const _HelpRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
