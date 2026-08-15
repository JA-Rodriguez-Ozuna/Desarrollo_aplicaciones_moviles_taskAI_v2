import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/plan_service.dart';

class PlanState {
  final bool isPro;
  final int photosUsedToday;
  final int voicesUsedToday;

  const PlanState({
    this.isPro = false,
    this.photosUsedToday = 0,
    this.voicesUsedToday = 0,
  });

  int get photosRemaining => isPro
      ? PlanService.proPhotoLimit
      : (PlanService.freePhotoLimit - photosUsedToday)
          .clamp(0, PlanService.freePhotoLimit);

  int get voicesRemaining => isPro
      ? PlanService.proVoiceLimit
      : (PlanService.freeVoiceLimit - voicesUsedToday)
          .clamp(0, PlanService.freeVoiceLimit);

  PlanState copyWith({
    bool? isPro,
    int? photosUsedToday,
    int? voicesUsedToday,
  }) {
    return PlanState(
      isPro: isPro ?? this.isPro,
      photosUsedToday: photosUsedToday ?? this.photosUsedToday,
      voicesUsedToday: voicesUsedToday ?? this.voicesUsedToday,
    );
  }
}

class PlanNotifier extends StateNotifier<PlanState> {
  final PlanService _service;

  PlanNotifier(this._service) : super(const PlanState()) {
    _load();
  }

  Future<void> _load() async {
    await _service.resetDailyCounters();
    final bool pro = await _service.isPro();
    final int photos = await _service.getPhotoUsageToday();
    final int voices = await _service.getVoiceUsageToday();
    state = PlanState(
      isPro: pro,
      photosUsedToday: photos,
      voicesUsedToday: voices,
    );
  }

  Future<void> upgradeToPro() async {
    await _service.setPro(true);
    state = state.copyWith(isPro: true);
  }

  Future<void> downgradeToFree() async {
    await _service.setPro(false);
    state = state.copyWith(isPro: false);
  }

  Future<bool> canUsePhoto() => _service.canUsePhoto();

  Future<bool> canUseVoice() => _service.canUseVoice();

  Future<void> recordPhotoUsage() async {
    await _service.incrementPhotoUsage();
    final int used = await _service.getPhotoUsageToday();
    state = state.copyWith(photosUsedToday: used);
  }

  Future<void> recordVoiceUsage() async {
    await _service.incrementVoiceUsage();
    final int used = await _service.getVoiceUsageToday();
    state = state.copyWith(voicesUsedToday: used);
  }
}

final Provider<PlanService> planServiceProvider =
    Provider<PlanService>((ref) => PlanService());

final StateNotifierProvider<PlanNotifier, PlanState> planProvider =
    StateNotifierProvider<PlanNotifier, PlanState>(
  (ref) => PlanNotifier(ref.read(planServiceProvider)),
);
