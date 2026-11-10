import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/presentation/providers/app_providers.dart';

/// Test double for [continueWatchingProvider] (an [AsyncNotifierProvider]).
///
/// Usage:
/// ```dart
/// continueWatchingProvider.overrideWith(
///   () => FakeContinueWatchingNotifier([entry]),
/// )
/// ```
class FakeContinueWatchingNotifier extends ContinueWatchingNotifier {
  FakeContinueWatchingNotifier(this.entries);

  final List<AnimeEntry> entries;

  @override
  Future<List<AnimeEntry>> build() async => entries;
}
