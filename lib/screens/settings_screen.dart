import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se cerrará tu sesión en este dispositivo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      // El auth guard de GoRouter redirige a /login automáticamente
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: 'Apariencia'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (Set<ThemeMode> selection) {
                ref
                    .read(themeProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const _SectionHeader(title: 'Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('TaskAI'),
            subtitle: Text('v3.0.0 — Gestión de tareas con IA y Firebase'),
          ),
          const ListTile(
            leading: Icon(Icons.layers_outlined),
            title: Text('Tecnologías'),
            subtitle: Text('Flutter • Riverpod • Firebase • Material Design 3'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Almacenamiento'),
            subtitle: Text('Firebase Firestore + caché offline con Hive'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Desarrollador'),
            subtitle: Text('JA-Rodriguez-Ozuna'),
          ),
          const Divider(),
          const _SectionHeader(title: 'Cuenta'),
          ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _confirmLogout(context, ref),
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
