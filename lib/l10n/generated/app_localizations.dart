import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Sueño Bebé'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get home;

  /// No description provided for @stats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get stats;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get skip;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a Sueño Bebé'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Registra el sueño y la alimentación de tu bebé'**
  String get loginSubtitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithEmail.
  ///
  /// In es, this message translates to:
  /// **'Continuar con email'**
  String get signInWithEmail;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @nameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nameLabel;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @noAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta?'**
  String get noAccount;

  /// No description provided for @alreadyAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta?'**
  String get alreadyAccount;

  /// No description provided for @onboardingBabyTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos del bebé'**
  String get onboardingBabyTitle;

  /// No description provided for @onboardingBabySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos sobre tu pequeño/a'**
  String get onboardingBabySubtitle;

  /// No description provided for @babyName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del bebé'**
  String get babyName;

  /// No description provided for @birthDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDate;

  /// No description provided for @sex.
  ///
  /// In es, this message translates to:
  /// **'Sexo'**
  String get sex;

  /// No description provided for @male.
  ///
  /// In es, this message translates to:
  /// **'Niño'**
  String get male;

  /// No description provided for @female.
  ///
  /// In es, this message translates to:
  /// **'Niña'**
  String get female;

  /// No description provided for @other.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get other;

  /// No description provided for @addPhoto.
  ///
  /// In es, this message translates to:
  /// **'Añadir foto'**
  String get addPhoto;

  /// No description provided for @onboardingShareTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Compartes el cuidado?'**
  String get onboardingShareTitle;

  /// No description provided for @createInviteCode.
  ///
  /// In es, this message translates to:
  /// **'Crear código de invitación'**
  String get createInviteCode;

  /// No description provided for @haveCode.
  ///
  /// In es, this message translates to:
  /// **'Tengo un código'**
  String get haveCode;

  /// No description provided for @later.
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get later;

  /// No description provided for @onboardingLegalTitle.
  ///
  /// In es, this message translates to:
  /// **'Términos y privacidad'**
  String get onboardingLegalTitle;

  /// No description provided for @acceptTerms.
  ///
  /// In es, this message translates to:
  /// **'Acepto los términos de uso y la política de privacidad'**
  String get acceptTerms;

  /// No description provided for @iAm18.
  ///
  /// In es, this message translates to:
  /// **'Soy mayor de 18 años'**
  String get iAm18;

  /// No description provided for @continueButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingNotificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te avisaremos si llevas más de 3 horas sin registrar nada durante el día'**
  String get onboardingNotificationsSubtitle;

  /// No description provided for @enableNotifications.
  ///
  /// In es, this message translates to:
  /// **'Activar notificaciones'**
  String get enableNotifications;

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @morningWake.
  ///
  /// In es, this message translates to:
  /// **'Despertar mañana'**
  String get morningWake;

  /// No description provided for @nap.
  ///
  /// In es, this message translates to:
  /// **'Siesta'**
  String get nap;

  /// No description provided for @bedtime.
  ///
  /// In es, this message translates to:
  /// **'Ir a la cama'**
  String get bedtime;

  /// No description provided for @nightWake.
  ///
  /// In es, this message translates to:
  /// **'Despertar nocturno'**
  String get nightWake;

  /// No description provided for @nursing.
  ///
  /// In es, this message translates to:
  /// **'Lactancia'**
  String get nursing;

  /// No description provided for @bottle.
  ///
  /// In es, this message translates to:
  /// **'Biberón'**
  String get bottle;

  /// No description provided for @addEvent.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento'**
  String get addEvent;

  /// No description provided for @startNow.
  ///
  /// In es, this message translates to:
  /// **'Iniciar ahora'**
  String get startNow;

  /// No description provided for @enterManually.
  ///
  /// In es, this message translates to:
  /// **'Introducir manualmente'**
  String get enterManually;

  /// No description provided for @startTime.
  ///
  /// In es, this message translates to:
  /// **'Hora de inicio'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In es, this message translates to:
  /// **'Hora de fin'**
  String get endTime;

  /// No description provided for @duration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get duration;

  /// No description provided for @note.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get note;

  /// No description provided for @optional.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get optional;

  /// No description provided for @bottleMl.
  ///
  /// In es, this message translates to:
  /// **'Cantidad (ml)'**
  String get bottleMl;

  /// No description provided for @leftBreast.
  ///
  /// In es, this message translates to:
  /// **'Pecho izquierdo'**
  String get leftBreast;

  /// No description provided for @rightBreast.
  ///
  /// In es, this message translates to:
  /// **'Pecho derecho'**
  String get rightBreast;

  /// No description provided for @switchSide.
  ///
  /// In es, this message translates to:
  /// **'Cambiar lado'**
  String get switchSide;

  /// No description provided for @finish.
  ///
  /// In es, this message translates to:
  /// **'Finalizar'**
  String get finish;

  /// No description provided for @sleeping.
  ///
  /// In es, this message translates to:
  /// **'Durmiendo hace'**
  String get sleeping;

  /// No description provided for @awake.
  ///
  /// In es, this message translates to:
  /// **'Despierto hace'**
  String get awake;

  /// No description provided for @eating.
  ///
  /// In es, this message translates to:
  /// **'Comiendo desde hace'**
  String get eating;

  /// No description provided for @lastMeal.
  ///
  /// In es, this message translates to:
  /// **'Última toma hace'**
  String get lastMeal;

  /// No description provided for @noRecordsYet.
  ///
  /// In es, this message translates to:
  /// **'Sin registros aún'**
  String get noRecordsYet;

  /// No description provided for @dayMode.
  ///
  /// In es, this message translates to:
  /// **'Modo día'**
  String get dayMode;

  /// No description provided for @nightMode.
  ///
  /// In es, this message translates to:
  /// **'Modo noche'**
  String get nightMode;

  /// No description provided for @trialBanner.
  ///
  /// In es, this message translates to:
  /// **'Prueba gratuita: {days} días restantes'**
  String trialBanner(int days);

  /// No description provided for @paywallTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso completo a Sueño Bebé'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Continúa registrando sin límites'**
  String get paywallSubtitle;

  /// No description provided for @paywallFeature1.
  ///
  /// In es, this message translates to:
  /// **'Registro ilimitado de eventos'**
  String get paywallFeature1;

  /// No description provided for @paywallFeature2.
  ///
  /// In es, this message translates to:
  /// **'Sin anuncios'**
  String get paywallFeature2;

  /// No description provided for @paywallFeature3.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas avanzadas (próximamente)'**
  String get paywallFeature3;

  /// No description provided for @paywallFeature4.
  ///
  /// In es, this message translates to:
  /// **'Predicciones de sueño (próximamente)'**
  String get paywallFeature4;

  /// No description provided for @monthlyPlan.
  ///
  /// In es, this message translates to:
  /// **'Mensual · 3,99 €'**
  String get monthlyPlan;

  /// No description provided for @annualPlan.
  ///
  /// In es, this message translates to:
  /// **'Anual · 11,99 €'**
  String get annualPlan;

  /// No description provided for @annualSaving.
  ///
  /// In es, this message translates to:
  /// **'Ahorra 75%'**
  String get annualSaving;

  /// No description provided for @subscribe.
  ///
  /// In es, this message translates to:
  /// **'Suscribirme'**
  String get subscribe;

  /// No description provided for @restorePurchase.
  ///
  /// In es, this message translates to:
  /// **'Restaurar compra'**
  String get restorePurchase;

  /// No description provided for @autoRenewNotice.
  ///
  /// In es, this message translates to:
  /// **'Se renueva automáticamente. Cancela cuando quieras en Google Play.'**
  String get autoRenewNotice;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @babyData.
  ///
  /// In es, this message translates to:
  /// **'Datos del bebé'**
  String get babyData;

  /// No description provided for @caregivers.
  ///
  /// In es, this message translates to:
  /// **'Cuidadores'**
  String get caregivers;

  /// No description provided for @subscription.
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get subscription;

  /// No description provided for @notifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @exportData.
  ///
  /// In es, this message translates to:
  /// **'Exportar mis datos'**
  String get exportData;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Borrar cuenta'**
  String get deleteAccount;

  /// No description provided for @termsAndPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Términos y Privacidad'**
  String get termsAndPrivacy;

  /// No description provided for @appVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get appVersion;

  /// No description provided for @themeAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático (según modo día/noche)'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Borrar cuenta'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta y todos los datos asociados se eliminarán en 7 días. Puedes cancelar este proceso iniciando sesión durante ese periodo.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In es, this message translates to:
  /// **'Borrar mi cuenta'**
  String get deleteAccountConfirm;

  /// No description provided for @cancelDeletion.
  ///
  /// In es, this message translates to:
  /// **'Cancelar borrado'**
  String get cancelDeletion;

  /// No description provided for @overlapError.
  ///
  /// In es, this message translates to:
  /// **'Este horario se solapa con {event}. Edítalo primero.'**
  String overlapError(String event);

  /// No description provided for @deleteEventTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar evento?'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get deleteEventMessage;

  /// No description provided for @statsTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get statsTitle;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @last7Days.
  ///
  /// In es, this message translates to:
  /// **'7 días'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In es, this message translates to:
  /// **'30 días'**
  String get last30Days;

  /// No description provided for @totalSleep.
  ///
  /// In es, this message translates to:
  /// **'Sueño total'**
  String get totalSleep;

  /// No description provided for @daySleep.
  ///
  /// In es, this message translates to:
  /// **'Sueño diurno'**
  String get daySleep;

  /// No description provided for @nightSleep.
  ///
  /// In es, this message translates to:
  /// **'Sueño nocturno'**
  String get nightSleep;

  /// No description provided for @feedings.
  ///
  /// In es, this message translates to:
  /// **'Tomas'**
  String get feedings;

  /// No description provided for @nightWakes.
  ///
  /// In es, this message translates to:
  /// **'Despertares nocturnos'**
  String get nightWakes;

  /// No description provided for @avgSleep.
  ///
  /// In es, this message translates to:
  /// **'Media de sueño'**
  String get avgSleep;

  /// No description provided for @noDataYet.
  ///
  /// In es, this message translates to:
  /// **'Sin datos todavía'**
  String get noDataYet;

  /// No description provided for @inviteCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación'**
  String get inviteCodeTitle;

  /// No description provided for @inviteCodeMessage.
  ///
  /// In es, this message translates to:
  /// **'Comparte este código con el otro cuidador. Caduca en 24h.'**
  String get inviteCodeMessage;

  /// No description provided for @redeemCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Unirme a un bebé'**
  String get redeemCodeTitle;

  /// No description provided for @redeemCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código de 6 dígitos'**
  String get redeemCodeHint;

  /// No description provided for @redeemButton.
  ///
  /// In es, this message translates to:
  /// **'Unirme'**
  String get redeemButton;

  /// No description provided for @invalidCode.
  ///
  /// In es, this message translates to:
  /// **'Código inválido o caducado'**
  String get invalidCode;

  /// No description provided for @subscriptionActive.
  ///
  /// In es, this message translates to:
  /// **'Suscripción activa'**
  String get subscriptionActive;

  /// No description provided for @subscriptionTrial.
  ///
  /// In es, this message translates to:
  /// **'Periodo de prueba'**
  String get subscriptionTrial;

  /// No description provided for @subscriptionExpired.
  ///
  /// In es, this message translates to:
  /// **'Suscripción expirada'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionNone.
  ///
  /// In es, this message translates to:
  /// **'Sin suscripción'**
  String get subscriptionNone;

  /// No description provided for @manageOnGooglePlay.
  ///
  /// In es, this message translates to:
  /// **'Gestionar en Google Play'**
  String get manageOnGooglePlay;

  /// No description provided for @nextRenewal.
  ///
  /// In es, this message translates to:
  /// **'Próxima renovación: {date}'**
  String nextRenewal(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
