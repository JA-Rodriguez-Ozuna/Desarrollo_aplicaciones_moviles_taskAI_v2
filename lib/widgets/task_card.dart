import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onDismissed;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onDismissed,
    required this.onTap,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isOverdue =
        !task.isCompleted && task.dueDate.isBefore(DateTime.now());

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (BuildContext ctx) => AlertDialog(
                title: const Text('Eliminar tarea'),
                content: Text('¿Eliminar "${task.title}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDismissed(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) => onToggleComplete(),
                  shape: const CircleBorder(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? theme.colorScheme.outline
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PriorityBadge(priority: task.priority),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _CategoryBadge(category: task.category),
                          const Spacer(),
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM HH:mm').format(task.dueDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                              fontWeight:
                                  isOverdue ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final TaskPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (priority) {
      case TaskPriority.alta:
        color = Colors.red;
        label = 'Alta';
      case TaskPriority.media:
        color = Colors.orange;
        label = 'Media';
      case TaskPriority.baja:
        color = Colors.green;
        label = 'Baja';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final TaskCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    switch (category) {
      case TaskCategory.trabajo:
        color = Colors.blue;
        label = 'Trabajo';
        icon = Icons.work;
      case TaskCategory.personal:
        color = Colors.green;
        label = 'Personal';
        icon = Icons.person;
      case TaskCategory.estudio:
        color = Colors.purple;
        label = 'Estudio';
        icon = Icons.school;
      case TaskCategory.urgente:
        color = Colors.red;
        label = 'Urgente';
        icon = Icons.warning;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
