import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewRequestManager {
  ReviewRequestManager._();

  static final ReviewRequestManager instance = ReviewRequestManager._();

  static const String _totalSessionsKey = 'review.totalCompletedSessions';
  static const String _lastMilestoneKey = 'review.lastRequestedMilestone';
  static const List<int> _milestones = <int>[7, 30, 60, 100];

  Future<void> onTrainingCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int current = prefs.getInt(_totalSessionsKey) ?? 0;
    await prefs.setInt(_totalSessionsKey, current + 1);
  }

  Future<bool> shouldRequestReview() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? milestone = _nextEligibleMilestone(prefs);
    return milestone != null;
  }

  Future<void> requestReviewIfNeeded({required bool canShowReview}) async {
    if (!canShowReview) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? milestone = _nextEligibleMilestone(prefs);
    if (milestone == null) return;

    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setInt(_lastMilestoneKey, milestone);
      }
    } catch (_) {
      // Ignore failures silently.
    }
  }

  int? _nextEligibleMilestone(SharedPreferences prefs) {
    final int total = prefs.getInt(_totalSessionsKey) ?? 0;
    if (total < _milestones.first) {
      return null;
    }
    final int lastRequested = prefs.getInt(_lastMilestoneKey) ?? 0;
    for (final int milestone in _milestones) {
      if (total >= milestone && lastRequested < milestone) {
        return milestone;
      }
    }
    return null;
  }
}
