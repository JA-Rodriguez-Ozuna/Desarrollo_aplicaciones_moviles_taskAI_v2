import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/task.dart';
import '../providers/plan_provider.dart';
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
  final ImagePicker _picker = ImagePicker();
  final GeminiService _gemini = GeminiService();

  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final bool granted =
          await PermissionService.requestCameraPermission(context);
      if (!granted || !mounted) return;
    }

    try {
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _result = null;
      });
    } catch (e) {
      _showError('No se pudo obtener la imagen: $e');
    }
  }

  Future<void> _analyze() async {
    final Uint8List? bytes = _imageBytes;
    if (bytes == null || _isAnalyzing) return;

    final bool allowed = await ref.read(planProvider.notifier).canUsePhoto();
    if (!allowed) {
      _showError(
        'Alcanzaste el límite diario de fotos del plan gratuito. '
        'Actualiza a Pro o intenta de nuevo mañana.',
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });
    try {
      final String? raw = await _gemini.analyzeImage(bytes);
      await ref.read(planProvider.notifier).recordPhotoUsage();
      final Map<String, dynamic>? data = _parseJson(raw);

      if (data == null) {
        _showError(
          'La IA no devolvió JSON válido: ${raw ?? "(respuesta vacía)"}',
        );
        return;
      }

      if (mounted) setState(() => _result = data);
    } catch (e) {
      _showError('Error al analizar la imagen: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _result = null;
    });
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

  List<String> _suggestions() {
    final dynamic raw = _result?['suggestions'];
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _openTaskPreview({
    required String title,
    required String description,
    required TaskCategory category,
    required TaskPriority priority,
  }) {
    final String safeTitle =
        title.length > 60 ? title.substring(0, 60) : title;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => _TaskPreviewSheet(
        title: safeTitle,
        description: description,
        category: category,
        priority: priority,
        onConfirm: () async {
          final Task task = Task.create(
            title: safeTitle,
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
              SnackBar(content: Text('Tarea "$safeTitle" creada')),
            );
            context.go('/');
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto IA'),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: _imageBytes == null
            ? _buildPicker(context)
            : _buildImageFlow(context),
      ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Convierte una foto en tarea',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Un pizarrón, unas notas o una página de libro — la IA se encarga del resto.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tomar foto'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Cargar desde galería'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFlow(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analizando imagen...'),
                ],
              ),
            )
          else if (_result == null) ...[
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analizar con IA'),
              onPressed: _analyze,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Elegir otra imagen'),
              onPressed: _reset,
            ),
          ] else
            _buildResult(theme),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final Map<String, dynamic> data = _result!;
    final String imageDescription =
        (data['imageDescription'] as String?)?.trim() ?? '';
    final bool hasTask = data['hasTask'] == true;
    final String title = (data['title'] as String?)?.trim() ?? '';
    final String description = (data['description'] as String?) ?? '';
    final TaskCategory category = _parseCategory(data['category'] as String?);
    final TaskPriority priority = _parsePriority(data['priority'] as String?);
    final List<String> suggestions = _suggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageDescription.isNotEmpty)
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.image_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(imageDescription, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        if (hasTask && title.isNotEmpty) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add_task),
            label: const Text('Crear tarea'),
            onPressed: () => _openTaskPreview(
              title: title,
              description: description,
              category: category,
              priority: priority,
            ),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Sugerencias', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (String s) => ActionChip(
                    avatar: const Icon(Icons.bolt, size: 16),
                    label: Text(s),
                    onPressed: () => _openTaskPreview(
                      title: s,
                      description: imageDescription,
                      category: category,
                      priority: priority,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 20),
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Elegir otra imagen'),
          onPressed: _reset,
        ),
      ],
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
