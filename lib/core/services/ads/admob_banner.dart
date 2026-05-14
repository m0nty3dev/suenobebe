import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../features/subscription/presentation/controllers/subscription_controller.dart';
import '../../config/constants.dart';
import '../../config/env.dart';

class AdmobBanner extends ConsumerStatefulWidget {
  const AdmobBanner({super.key});

  @override
  ConsumerState<AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends ConsumerState<AdmobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final id = useTestAds
        ? AppConstants.admobBannerIdTest
        : AppConstants.admobBannerId;
    _ad = BannerAd(
      adUnitId: id,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (_, __) => setState(() => _loaded = false),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAdsValue = ref.watch(showAdsProvider);
    if (!showAdsValue || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
