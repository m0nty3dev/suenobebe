import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentService {
  /// Requests UMP consent info, shows the form if required, then initializes
  /// MobileAds. Must be called after WidgetsFlutterBinding.ensureInitialized().
  ///
  /// google_mobile_ads ≥5.x uses callbacks instead of Futures for the UMP API.
  /// We wrap them in Completers so the call site can still await this method.
  static Future<void> initialize() async {
    try {
      await _requestConsentAndShowForm();
    } catch (_) {
      // Consent request failed (e.g. no network). Proceed without consent —
      // MobileAds will not show personalized ads.
    }

    // Initialize MobileAds regardless of consent outcome so non-personalized
    // ads can still be served and the SDK doesn't remain uninitialized.
    await MobileAds.instance.initialize();
  }

  static Future<void> _requestConsentAndShowForm() {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        // Success: check if form is available and show it if required.
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _showFormIfRequired(completer);
        } else {
          completer.complete();
        }
      },
      (FormError error) {
        // Failure: resolve so MobileAds still initializes.
        completer.completeError(error.message);
      },
    );

    return completer.future;
  }

  static void _showFormIfRequired(Completer<void> completer) {
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
      // Called after the form is dismissed (or if it wasn't needed).
      if (formError != null) {
        completer.completeError(formError.message);
      } else {
        completer.complete();
      }
    });
  }
}
