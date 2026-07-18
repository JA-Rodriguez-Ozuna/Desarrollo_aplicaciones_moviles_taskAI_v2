import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
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

    final String contentKey;
    final Widget content;
    if (taskState.errorMessage != null) {
      contentKey = 'error';
      content = _ErrorState(
        onRetry: () => ref.read(taskProvider.notifier).retry(),
      );
    } else if (taskState.isLoading && taskState.tasks.isEmpty) {
      contentKey = 'loading';
      content = const _LoadingShimmer();
    } else if (filteredTasks.isEmpty) {
      contentKey = 'empty';
      content = _EmptyState(onCreateTask: () => context.go('/task/new'));
    } else {
      contentKey = 'list';
      content = RefreshIndicator(
        onRefresh: () async => ref.read(taskProvider.notifier).retry(),
        child: _AnimatedTaskList(
          tasks: filteredTasks,
          onDismissed: (Task task) {
            HapticFeedback.mediumImpact();
            ref.read(taskProvider.notifier).deleteTask(task.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarea "${task.title}" eliminada'),
                action: SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () {
                    ref.read(taskProvider.notifier).undoDelete();
                  },
                ),
              ),
            );
          },
          onTap: (Task task) => context.go('/task/edit/${task.id}'),
          onToggleComplete: (Task task) {
            HapticFeedback.lightImpact();
            ref.read(taskProvider.notifier).toggleComplete(task.id);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskAI'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner,
              semanticLabel: 'Escanear QR',
            ),
            onPressed: () => context.go('/qr-scan'),
            tooltip: 'Escanear QR',
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey<String>(contentKey), child: content),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/task/new'),
        tooltip: 'Crear nueva tarea',
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTask;

  const _EmptyState({required this.onCreateTask});

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
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes tareas aún',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onCreateTask,
            child: const Text('Crear mi primera tarea'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar tareas',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTaskList extends StatefulWidget {
  final List<Task> tasks;
  final void Function(Task task) onDismissed;
  final void Function(Task task) onTap;
  final void Function(Task task) onToggleComplete;

  const _AnimatedTaskList({
    required this.tasks,
    required this.onDismissed,
    required this.onTap,
    required this.onToggleComplete,
  });

  @override
  State<_AnimatedTaskList> createState() => _AnimatedTaskListState();
}

class _AnimatedTaskListState extends State<_AnimatedTaskList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<Task> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Task>.from(widget.tasks);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncList(widget.tasks);
  }

  void _syncList(List<Task> newTasks) {
    final Set<String> newIds = newTasks.map((Task t) => t.id).toSet();
    final Set<String> oldIds = _items.map((Task t) => t.id).toSet();

    for (int i = _items.length - 1; i >= 0; i--) {
      if (!newIds.contains(_items[i].id)) {
        final Task removed = _items.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (BuildContext context, Animation<double> animation) =>
              FadeTransition(opacity: animation, child: _buildRow(removed)),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    for (int i = 0; i < newTasks.length; i++) {
      if (!oldIds.contains(newTasks[i].id)) {
        _items.insert(i, newTasks[i]);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    _items = List<Task>.from(newTasks);
  }

  Widget _buildRow(Task task) {
    return TaskCard(
      task: task,
      onDismissed: () => widget.onDismissed(task),
      onTap: () => widget.onTap(task),
      onToggleComplete: () => widget.onToggleComplete(task),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      padding: const EdgeInsets.only(bottom: 100),
      initialItemCount: _items.length,
      itemBuilder: (BuildContext context, int index, Animation<double> animation) {
        final Task task = _items[index];
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOut)),
          ),
          child: FadeTransition(opacity: animation, child: _buildRow(task)),
        );
      },
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerLow,
      highlightColor: colors.surfaceContainerHighest,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemCount: 3,
        itemBuilder: (BuildContext context, int index) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(height: 64),
          ),
        ),
      ),
    );
  }
}
