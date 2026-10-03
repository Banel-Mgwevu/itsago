import 'dart:io';

/// Store details that differ between Google Play and the App Store.
class StoreConfig {
  StoreConfig._();

  /// Numeric Apple ID of ITSAGO, shown in App Store Connect under
  /// App Information > Apple ID (e.g. '6741234567'). Fill in once the app
  /// record exists - until then the iOS "rate us" fallback is skipped.
  static const String appStoreId = '';

  static bool get isIOS => Platform.isIOS;

  /// "Google Play" or "the App Store" - used in paywall messages.
  static String get storeName => Platform.isIOS ? 'the App Store' : 'Google Play';
  static String get storeNameCaps => Platform.isIOS ? 'APP STORE' : 'GOOGLE PLAY';

  /// Link used when people share a CV from the app.
  static String get shareLink => Platform.isIOS
      ? (appStoreId.isEmpty
          ? 'https://itsago.app'
          : 'https://apps.apple.com/app/id$appStoreId')
      : 'https://play.google.com/store/apps/details?id=com.itsago.interviewai';
}
