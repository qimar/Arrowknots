import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_constants.dart';

class AdMobService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;

  /// Initializes the Google Mobile Ads SDK.
  /// Call this once in main.dart before runApp.
  static Future<void> init() async {
    await MobileAds.instance.initialize();
    
    // Using the official Google Test Ad Unit ID handles test ad delivery automatically.
    // No need to restrict by specific test device IDs.
    
    _loadRewardedAd();
  }

  /// Pre-loads a rewarded ad so it's ready instantly when the user clicks the button.
  static void _loadRewardedAd() {
    if (_rewardedAd != null || _isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: AppConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded ad loaded successfully.');
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isAdLoading = false;
          // Retry loading after a delay if it failed
          Future.delayed(const Duration(seconds: 10), _loadRewardedAd);
        },
      ),
    );
  }

  /// Shows the pre-loaded rewarded ad.
  /// Returns `true` if the user successfully watched the ad and earned the reward.
  /// Returns `false` if the ad failed to show, or if the user dismissed it early.
  static Future<bool> showRewardedAd({BuildContext? context}) async {
    if (_rewardedAd == null) {
      debugPrint('Ad not ready yet. Attempting to load...');
      _loadRewardedAd();
      
      if (context != null) {
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );
        for (int i = 0; i < 50; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_rewardedAd != null) break;
        }
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (_rewardedAd == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load ad. Please check your internet connection and try again.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      } else {
        return false; // Ad wasn't ready to show and no context to show spinner
      }
    }

    Completer<bool> completer = Completer<bool>();
    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Ad showed fullscreen.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Pre-load the next ad
        if (!completer.isCompleted) {
          completer.complete(earnedReward);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      debugPrint('User earned reward: ${reward.amount} ${reward.type}');
      earnedReward = true;
    });

    return completer.future;
  }
}
