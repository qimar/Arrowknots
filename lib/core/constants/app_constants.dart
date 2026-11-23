import 'dart:io';

class AppConstants {
    // ADMOB IDs
  // When you are ready to publish the app to the Google Play Store,
  // replace these test IDs with your real AdMob Ad Unit IDs.
  
  // Official Google Test Rewarded Ad Unit ID
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
