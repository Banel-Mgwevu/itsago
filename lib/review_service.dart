import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _kLastReviewKey   = 'last_review_prompt';
  static const _kCvCountKey      = 'cv_build_count';
  static const _minDaysBetween   = 30;
  static const _minCvsBeforeAsk  = 1; // ask after first successful CV

  /// Call this after a CV is successfully generated.
  static Future<void> onCVGenerated() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kCvCountKey) ?? 0) + 1;
    await prefs.setInt(_kCvCountKey, count);

    if (count < _minCvsBeforeAsk) return;

    final lastRaw = prefs.getString(_kLastReviewKey);
    if (lastRaw != null) {
      final last = DateTime.parse(lastRaw);
      if (DateTime.now().difference(last).inDays < _minDaysBetween) return;
    }

    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
      await prefs.setString(_kLastReviewKey, DateTime.now().toIso8601String());
    } else {
      // Fallback: open Play Store listing
      await review.openStoreListing(
        appStoreId: 'com.itsago.interviewai',
      );
    }
  }
}
