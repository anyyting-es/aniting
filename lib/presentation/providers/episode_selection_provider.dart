import 'package:flutter_riverpod/flutter_riverpod.dart';

class EpisodeSelectionState {
  final Set<int> selectedNumbers;

  const EpisodeSelectionState([this.selectedNumbers = const {}]);

  bool get isSelectionMode => selectedNumbers.isNotEmpty;
  int get count => selectedNumbers.length;
  bool isSelected(int episodeNumber) => selectedNumbers.contains(episodeNumber);

  EpisodeSelectionState copyWith({Set<int>? selectedNumbers}) {
    return EpisodeSelectionState(selectedNumbers ?? this.selectedNumbers);
  }
}

class EpisodeSelectionNotifier extends Notifier<EpisodeSelectionState> {
  final int mediaId;

  EpisodeSelectionNotifier(this.mediaId);

  @override
  EpisodeSelectionState build() {
    return const EpisodeSelectionState();
  }

  void toggle(int episodeNumber) {
    final next = Set<int>.from(state.selectedNumbers);
    if (next.contains(episodeNumber)) {
      next.remove(episodeNumber);
    } else {
      next.add(episodeNumber);
    }
    state = EpisodeSelectionState(next);
  }

  void select(int episodeNumber) {
    if (state.selectedNumbers.contains(episodeNumber)) return;
    final next = Set<int>.from(state.selectedNumbers)..add(episodeNumber);
    state = EpisodeSelectionState(next);
  }

  void deselect(int episodeNumber) {
    if (!state.selectedNumbers.contains(episodeNumber)) return;
    final next = Set<int>.from(state.selectedNumbers)..remove(episodeNumber);
    state = EpisodeSelectionState(next);
  }

  void selectAll(Iterable<int> episodeNumbers) {
    state = EpisodeSelectionState(Set<int>.from(episodeNumbers));
  }

  void clear() {
    if (state.selectedNumbers.isEmpty) return;
    state = const EpisodeSelectionState();
  }
}

final episodeSelectionProvider =
    NotifierProvider.family<EpisodeSelectionNotifier, EpisodeSelectionState, int>(
  (mediaId) => EpisodeSelectionNotifier(mediaId),
);
