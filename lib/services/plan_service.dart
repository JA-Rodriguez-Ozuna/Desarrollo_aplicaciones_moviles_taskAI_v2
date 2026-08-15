import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanService {
  static const int freePhotoLimit = 2;
  static const int freeVoiceLimit = 5;
  static const int proPhotoLimit = 999;
  static const int proVoiceLimit = 999;

  static const String _isProKey = 'is_pro';
  static const String _photoUsageKey = 'photo_usage_today';
  static const String _voiceUsageKey = 'voice_usage_today';
  static const String _lastResetDateKey = 'last_reset_date';

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<bool> isPro() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isProKey) ?? false;
  }

  Future<void> setPro(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProKey, value);
  }

  Future<int> getPhotoUsageToday() async {
    await resetDailyCounters();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_photoUsageKey) ?? 0;
  }

  Future<int> getVoiceUsageToday() async {
    await resetDailyCounters();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_voiceUsageKey) ?? 0;
  }

  Future<bool> canUsePhoto() async {
    await resetDailyCounters();
    if (await isPro()) return true;
    final int used = await getPhotoUsageToday();
    return used < freePhotoLimit;
  }

  Future<bool> canUseVoice() async {
    await resetDailyCounters();
    if (await isPro()) return true;
    final int used = await getVoiceUsageToday();
    return used < freeVoiceLimit;
  }

  Future<void> incrementPhotoUsage() async {
    await resetDailyCounters();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int current = prefs.getInt(_photoUsageKey) ?? 0;
    await prefs.setInt(_photoUsageKey, current + 1);
  }

  Future<void> incrementVoiceUsage() async {
    await resetDailyCounters();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int current = prefs.getInt(_voiceUsageKey) ?? 0;
    await prefs.setInt(_voiceUsageKey, current + 1);
  }

  /// Compares 'last_reset_date' against today; if different, zeroes both
  /// counters and stamps today's date, so usage limits are enforced per
  /// calendar day without a background job.
  Future<void> resetDailyCounters() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String today = _today();
    final String? lastReset = prefs.getString(_lastResetDateKey);
    if (lastReset != today) {
      await prefs.setInt(_photoUsageKey, 0);
      await prefs.setInt(_voiceUsageKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }
  }

  static Future<void> resetDailyCountersIfNeeded() async {
    await PlanService().resetDailyCounters();
  }
}
