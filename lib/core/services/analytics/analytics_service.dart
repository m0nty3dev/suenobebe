import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;

  static void logLogin(String method) =>
      _analytics.logLogin(loginMethod: method).ignore();

  static void logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method).ignore();

  static void logBabyCreated() =>
      _analytics.logEvent(name: 'baby_created').ignore();

  static void logCaregiverInvited() =>
      _analytics.logEvent(name: 'caregiver_invited').ignore();

  static void logCaregiverJoined() =>
      _analytics.logEvent(name: 'caregiver_joined').ignore();

  static void logEventLogged(String eventType, String mode) =>
      _analytics.logEvent(
        name: 'event_logged',
        parameters: {'event_type': eventType, 'mode': mode},
      ).ignore();

  static void logEventEdited(String eventType) =>
      _analytics.logEvent(
        name: 'event_edited',
        parameters: {'event_type': eventType},
      ).ignore();

  static void logEventDeleted(String eventType) =>
      _analytics.logEvent(
        name: 'event_deleted',
        parameters: {'event_type': eventType},
      ).ignore();

  static void logTrialStarted() =>
      _analytics.logEvent(name: 'trial_started').ignore();

  static void logPaywallViewed(String source) =>
      _analytics.logEvent(
        name: 'paywall_viewed',
        parameters: {'source': source},
      ).ignore();

  static void logSubscriptionStarted(String plan) =>
      _analytics.logEvent(
        name: 'subscription_started',
        parameters: {'plan': plan},
      ).ignore();

  static void logExportData() =>
      _analytics.logEvent(name: 'export_data').ignore();

  static void logDeleteAccountRequested() =>
      _analytics.logEvent(name: 'delete_account_requested').ignore();

  static void logDeleteAccountCancelled() =>
      _analytics.logEvent(name: 'delete_account_cancelled').ignore();
}
