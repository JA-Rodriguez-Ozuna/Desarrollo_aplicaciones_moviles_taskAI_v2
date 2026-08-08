import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _onboardingPrefsKey = 'onboarding_completed';

/// null while restoring from disk, otherwise the persisted completion flag.
class OnboardingNotifier extends StateNotifier<bool?> {
  OnboardingNotifier() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_onboardingPrefsKey) ?? false;
  }

  Future<void> complete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingPrefsKey, true);
    state = true;
  }
}

final StateNotifierProvider<OnboardingNotifier, bool?> onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool?>(
  (_) => OnboardingNotifier(),
);
