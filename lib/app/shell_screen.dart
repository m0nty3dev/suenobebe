import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../features/home/presentation/controllers/home_controller.dart';
import '../features/home/presentation/widgets/live_event_indicator.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  int _locationToIndex(String location) {
    if (location.startsWith('/stats')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);

    // Only the boolean (has live event?) is observed here — the heavy widget
    // with the 1-second timer is isolated in a child Consumer so the Scaffold
    // and BottomNavigationBar don't rebuild every second.
    final hasLive = ref.watch(
      liveEventProvider.select((v) => v.valueOrNull != null),
    );

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          // Isolated Consumer: only rebuilds when the live event itself changes.
          if (hasLive)
            Consumer(
              builder: (context, ref, _) {
                final liveEvent =
                    ref.watch(liveEventProvider).valueOrNull;
                if (liveEvent == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LiveEventIndicator(event: liveEvent),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/stats');
            case 2:
              context.go('/settings');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: hasLive,
              smallSize: 8,
              child: const PhosphorIcon(PhosphorIconsRegular.house),
            ),
            activeIcon: Badge(
              isLabelVisible: hasLive,
              smallSize: 8,
              child: const PhosphorIcon(PhosphorIconsFill.house),
            ),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIconsRegular.chartBar),
            activeIcon: PhosphorIcon(PhosphorIconsFill.chartBar),
            label: 'Estadísticas',
          ),
          const BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIconsRegular.gear),
            activeIcon: PhosphorIcon(PhosphorIconsFill.gear),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
