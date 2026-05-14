import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/onboarding/presentation/screens/baby_form_screen.dart';
import '../features/onboarding/presentation/screens/share_caregiver_screen.dart';
import '../features/onboarding/presentation/screens/legal_screen.dart';
import '../features/onboarding/presentation/screens/notifications_permission_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/stats/presentation/screens/stats_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/baby_settings_screen.dart';
import '../features/settings/presentation/screens/caregivers_screen.dart';
import '../features/settings/presentation/screens/notifications_settings_screen.dart';
import '../features/settings/presentation/screens/theme_settings_screen.dart';
import '../features/settings/presentation/screens/delete_account_screen.dart';
import '../features/events/presentation/screens/event_detail_screen.dart';
import '../features/events/presentation/screens/manual_entry_screen.dart';
import '../features/calendar/presentation/screens/calendar_modal.dart';
import '../features/subscription/presentation/screens/paywall_screen.dart';
import '../features/subscription/presentation/screens/subscription_status_screen.dart';
import '../features/invitations/presentation/screens/redeem_code_screen.dart';
import 'shell_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // ValueNotifier triggers redirect re-evaluation without recreating the router.
  final notifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => notifier.value++);
  // Only trigger redirect when fields that affect routing logic change.
  ref.listen(
    appUserProvider.select((v) => (
      v.valueOrNull?.currentBabyId,
      v.valueOrNull?.legalAccepted != null,
      v.isLoading,
    )),
    (_, __) => notifier.value++,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final appUser = ref.read(appUserProvider);

      final isLoggedIn = authState.valueOrNull != null;
      final user = appUser.valueOrNull;
      final isLoading = authState.isLoading || appUser.isLoading;

      if (isLoading) return null;

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/auth/login';
      }

      if (isLoggedIn && user != null) {
        if (user.legalAccepted == null && !isOnboardingRoute) {
          return '/onboarding/baby';
        }
        if (user.currentBabyId == null &&
            !isOnboardingRoute &&
            user.legalAccepted != null) {
          return '/onboarding/baby';
        }
        if (isAuthRoute) return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding/baby',
        builder: (context, state) => const BabyFormScreen(),
      ),
      GoRoute(
        path: '/onboarding/share',
        builder: (context, state) => const ShareCaregiverScreen(),
      ),
      GoRoute(
        path: '/onboarding/legal',
        builder: (context, state) => const LegalScreen(),
      ),
      GoRoute(
        path: '/onboarding/notifications',
        builder: (context, state) => const NotificationsPermissionScreen(),
      ),
      GoRoute(
        path: '/invite/redeem',
        builder: (context, state) => const RedeemCodeScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final source = state.uri.queryParameters['source'] ?? 'event_block';
          return PaywallScreen(source: source);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/event/new',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ManualEntryScreen(initialType: extra?['type'] as String?);
        },
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          final babyId = state.uri.queryParameters['babyId'] ?? '';
          return EventDetailScreen(eventId: eventId, babyId: babyId);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarModal(),
      ),
      GoRoute(
        path: '/settings/baby',
        builder: (context, state) => const BabySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const SubscriptionStatusScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/theme',
        builder: (context, state) => const ThemeSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/settings/caregivers',
        builder: (context, state) => const CaregiversScreen(),
      ),
    ],
  );
});
