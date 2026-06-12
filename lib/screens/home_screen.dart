import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/filter_chips.dart';
import '../widgets/task_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TaskState taskState = ref.watch(taskProvider);
    final List<Task> filteredTasks = taskState.filteredTasks;
    final int totalPending =
        taskState.tasks.where((Task t) => !t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: () => context.go('/voice'),
            tooltip: 'Captura por voz',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.go('/qr-scan'),
            tooltip: 'Escanear QR',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.go('/statistics'),
            tooltip: 'Estadísticas',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
            tooltip: 'Configuración',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: totalPending > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$totalPending tarea${totalPending == 1 ? '' : 's'} pendiente${totalPending == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(
        children: [
          const FilterChipsWidget(),
          Expanded(
            child: filteredTasks.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: filteredTasks.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Task task = filteredTasks[index];
                      return TaskCard(
                        task: task,
                        onDismissed: () {
                          ref.read(taskProvider.notifier).deleteTask(task.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Tarea "${task.title}" eliminada'),
                              action: SnackBarAction(
                                label: 'Deshacer',
                                onPressed: () {
                                  ref
                                      .read(taskProvider.notifier)
                                      .addTask(task);
                                },
                              ),
                            ),
                          );
                        },
                        onTap: () =>
                            context.go('/task/edit/${task.id}'),
                        onToggleComplete: () {
                          ref
                              .read(taskProvider.notifier)
                              .toggleComplete(task.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/task/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay tareas',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para crear una',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
