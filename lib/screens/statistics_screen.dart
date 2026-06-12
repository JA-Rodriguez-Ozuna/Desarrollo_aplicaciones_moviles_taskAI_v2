import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/stats_card.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks = ref.watch(taskProvider).tasks;
    final int totalTasks = tasks.length;
    final int completedTasks = tasks.where((Task t) => t.isCompleted).length;
    final int pendingTasks = totalTasks - completedTasks;
    final double successRate =
        totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    final Map<TaskCategory, (int, int)> byCategory = {
      for (final TaskCategory cat in TaskCategory.values)
        cat: (
          tasks.where((Task t) => t.category == cat).length,
          tasks
              .where((Task t) => t.category == cat && t.isCompleted)
              .length,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total',
                  value: totalTasks.toString(),
                  icon: Icons.list_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Completadas',
                  value: completedTasks.toString(),
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Pendientes',
                  value: pendingTasks.toString(),
                  icon: Icons.pending_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasa de éxito',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: successRate,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(successRate * 100).toStringAsFixed(0)}%',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedTasks de $totalTasks tareas completadas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Por categoría',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...TaskCategory.values.map((TaskCategory cat) {
            final (int catTotal, int catDone) =
                byCategory[cat] ?? (0, 0);
            return _CategoryProgressRow(
              category: cat,
              total: catTotal,
              completed: catDone,
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  final TaskCategory category;
  final int total;
  final int completed;

  const _CategoryProgressRow({
    required this.category,
    required this.total,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(), size: 16, color: _categoryColor()),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _categoryLabel(),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '$completed/$total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: _categoryColor(),
          ),
        ],
      ),
    );
  }

  String _categoryLabel() {
    switch (category) {
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

  Color _categoryColor() {
    switch (category) {
      case TaskCategory.trabajo:
        return Colors.blue;
      case TaskCategory.personal:
        return Colors.green;
      case TaskCategory.estudio:
        return Colors.purple;
      case TaskCategory.urgente:
        return Colors.red;
    }
  }

  IconData _categoryIcon() {
    switch (category) {
      case TaskCategory.trabajo:
        return Icons.work_rounded;
      case TaskCategory.personal:
        return Icons.person_rounded;
      case TaskCategory.estudio:
        return Icons.school_rounded;
      case TaskCategory.urgente:
        return Icons.warning_rounded;
    }
  }
}
