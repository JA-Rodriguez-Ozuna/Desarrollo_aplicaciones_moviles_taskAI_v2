import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/task_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: 'Apariencia'),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Tema oscuro'),
            subtitle: Text(
              isDark ? 'Modo oscuro activado' : 'Modo claro activado',
            ),
            value: isDark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          const Divider(),
          const _SectionHeader(title: 'Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('TaskAI'),
            subtitle: Text('v1.0.0 — Gestión de tareas universitaria'),
          ),
          const ListTile(
            leading: Icon(Icons.layers_outlined),
            title: Text('Tecnologías'),
            subtitle: Text('Flutter • Riverpod • Material Design 3'),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Almacenamiento'),
            subtitle: Text('Datos en memoria (sin base de datos)'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Desarrollador'),
            subtitle: Text('Jose R'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
