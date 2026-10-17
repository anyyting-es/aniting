import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/debrid_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

final debridSettingsProvider =
    NotifierProvider<DebridSettingsNotifier, AsyncValue<DebridSettings>>(
        DebridSettingsNotifier.new);

class DebridSettingsNotifier extends Notifier<AsyncValue<DebridSettings>> {
  @override
  AsyncValue<DebridSettings> build() {
    loadSettings();
    return const AsyncValue.loading();
  }

  Future<void> loadSettings() async {
    try {
      final repo = ref.read(repositoryProvider);
      final settings = await repo.getDebridSettings();
      if (settings != null) {
        state = AsyncValue.data(settings);
      } else {
        state = const AsyncValue.data(DebridSettings());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateSettings(DebridSettings newSettings) async {
    final repo = ref.read(repositoryProvider);
    final previousState = state;
    state = AsyncValue.data(newSettings);
    final success = await repo.updateDebridSettings(newSettings);
    if (!success) {
      state = previousState;
      return false;
    }
    await loadSettings();
    return true;
  }
}

final debridTorrentsProvider =
    FutureProvider.autoDispose<List<DebridTorrentItem>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getDebridTorrents();
});
