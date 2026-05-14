import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/theme_controller.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: Column(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('Automático (según modo día/noche)'),
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (v) => ref
                .read(themeModeNotifierProvider.notifier)
                .setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Claro'),
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (v) => ref
                .read(themeModeNotifierProvider.notifier)
                .setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Oscuro'),
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (v) => ref
                .read(themeModeNotifierProvider.notifier)
                .setTheme(v!),
          ),
        ],
      ),
    );
  }
}
