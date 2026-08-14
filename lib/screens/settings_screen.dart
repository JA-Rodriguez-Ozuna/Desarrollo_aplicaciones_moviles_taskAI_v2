import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/task_provider.dart';
import '../services/ad_service.dart';
import '../services/plan_service.dart';

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
          const _SectionHeader(title: 'Plan actual'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _PlanCard(),
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

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard();

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  final AdService _adService = AdService();

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  Future<void> _upgradeToPro() async {
    await ref.read(planProvider.notifier).upgradeToPro();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido a Pro! Uso ilimitado activado.'),
        ),
      );
    }
  }

  Future<void> _downgradeToFree() async {
    await ref.read(planProvider.notifier).downgradeToFree();
  }

  Future<void> _watchRewardedAdForExtraPhoto() async {
    bool rewarded = false;
    await _adService.showRewardedAd(() => rewarded = true);
    if (!mounted || !rewarded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Obtuviste 1 foto extra por hoy!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlanState plan = ref.watch(planProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (plan.isPro) {
      return Card(
        color: colors.primary,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Plan Pro ✓',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Uso ilimitado · Sin anuncios',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onPrimary),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _downgradeToFree,
                  style:
                      TextButton.styleFrom(foregroundColor: colors.onPrimary),
                  child: const Text('Volver al plan gratuito'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int photosUsed =
        plan.photosUsedToday.clamp(0, PlanService.freePhotoLimit);
    final int voicesUsed =
        plan.voicesUsedToday.clamp(0, PlanService.freeVoiceLimit);

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan Gratuito', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$photosUsed/${PlanService.freePhotoLimit} fotos · '
              '$voicesUsed/${PlanService.freeVoiceLimit} voces usadas hoy',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text('Fotos', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: photosUsed / PlanService.freePhotoLimit,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Text('Voces', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: voicesUsed / PlanService.freeVoiceLimit,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _upgradeToPro,
                child: const Text('Probar Pro — 7 días por \$1'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _watchRewardedAdForExtraPhoto,
                child: const Text('Ver anuncio para foto extra'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
