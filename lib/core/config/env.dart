import 'package:flutter/foundation.dart';

// In debug builds always use test ads; release can override via --dart-define=USE_TEST_ADS=true.
const bool useTestAds = kDebugMode || bool.fromEnvironment('USE_TEST_ADS', defaultValue: false);
