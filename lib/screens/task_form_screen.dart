import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;

  const TaskFormScreen({super.key, this.taskId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  TaskCategory _category = TaskCategory.personal;
  TaskPriority _priority = TaskPriority.media;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _isEditing = false;
  Task? _originalTask;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _isEditing = true;
      final List<Task> tasks = ref.read(taskProvider).tasks;
      final Iterable<Task> matches =
          tasks.where((Task t) => t.id == widget.taskId);
      _originalTask = matches.isNotEmpty ? matches.first : null;
      if (_originalTask != null) {
        _titleController.text = _originalTask!.title;
        _descriptionController.text = _originalTask!.description;
        _category = _originalTask!.category;
        _priority = _originalTask!.priority;
        _dueDate = _originalTask!.dueDate;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dueDate.isBefore(DateTime.now()) ? DateTime.now() : _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dueDate.hour,
          _dueDate.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_dueDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha límite no puede estar en el pasado'),
        ),
      );
      return;
    }

    final TaskNotifier notifier = ref.read(taskProvider.notifier);

    if (_isEditing && _originalTask != null) {
      notifier.updateTask(
        _originalTask!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          priority: _priority,
          dueDate: _dueDate,
        ),
      );
    } else {
      notifier.addTask(
        Task(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          priority: _priority,
          dueDate: _dueDate,
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      );
    }

    context.go('/');
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isEditing && _originalTask == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Tarea no encontrada',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar tarea' : 'Nueva tarea'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                if (value.trim().length > 100) {
                  return 'Máximo 100 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Detalles opcionales de la tarea',
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
            const SizedBox(height: 24),
            Text('Fecha límite', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('dd/MM/yyyy').format(_dueDate)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(DateFormat('HH:mm').format(_dueDate)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Límite: ${dateFormat.format(_dueDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: Text(_isEditing ? 'Guardar cambios' : 'Crear tarea'),
              onPressed: _submit,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar'),
                onPressed: () => context.go('/'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
