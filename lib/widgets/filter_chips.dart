import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class FilterChipsWidget extends ConsumerWidget {
  const FilterChipsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TaskFilter filter = ref.watch(taskProvider).filter;
    final TaskNotifier notifier = ref.read(taskProvider.notifier);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: StatusFilter.values.map((StatusFilter status) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_statusLabel(status)),
                  selected: filter.status == status,
                  onSelected: (_) {
                    notifier.setFilter(filter.copyWith(status: status));
                  },
                ),
              );
            }).toList(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Todas'),
                  selected: filter.category == CategoryFilter.all,
                  onSelected: (_) {
                    notifier
                        .setFilter(filter.copyWith(category: CategoryFilter.all));
                  },
                ),
              ),
              ...TaskCategory.values.map((TaskCategory cat) {
                final CategoryFilter catFilter = _toCategoryFilter(cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(_categoryIcon(cat), size: 16),
                    label: Text(_categoryLabel(cat)),
                    selected: filter.category == catFilter,
                    onSelected: (_) {
                      notifier.setFilter(filter.copyWith(category: catFilter));
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(StatusFilter status) {
    switch (status) {
      case StatusFilter.all:
        return 'Todas';
      case StatusFilter.pending:
        return 'Pendientes';
      case StatusFilter.completed:
        return 'Completadas';
    }
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

  CategoryFilter _toCategoryFilter(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.trabajo:
        return CategoryFilter.trabajo;
      case TaskCategory.personal:
        return CategoryFilter.personal;
      case TaskCategory.estudio:
        return CategoryFilter.estudio;
      case TaskCategory.urgente:
        return CategoryFilter.urgente;
    }
  }

  IconData _categoryIcon(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.trabajo:
        return Icons.work;
      case TaskCategory.personal:
        return Icons.person;
      case TaskCategory.estudio:
        return Icons.school;
      case TaskCategory.urgente:
        return Icons.warning;
    }
  }
}
