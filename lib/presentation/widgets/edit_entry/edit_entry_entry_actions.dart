import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aniting/data/services/offline_library_service.dart';
import 'package:aniting/data/services/offline_sync_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';

/// Ejecuta la escritura de una edición de entrada: AniList remoto (si hay
/// sesión), librería offline y cola de sincronización de respaldo.
/// Devuelve `true` si el guardado remoto fue exitoso (o no aplicaba).
Future<bool> persistEditEntry(
  WidgetRef ref, {
  required int mediaId,
  required String title,
  required String type, // 'anime' | 'manga'
  required String status,
  required double score,
  required int progress,
  required int repeat,
  int? totalCount,
  DateTime? startedAt,
  DateTime? completedAt,
}) async {
  final isAnime = type == 'anime';
  final repo = ref.read(repositoryProvider);

  Map<String, int>? startedAtMap;
  if (startedAt != null) {
    startedAtMap = {'year': startedAt.year, 'month': startedAt.month, 'day': startedAt.day};
  }
  Map<String, int>? completedAtMap;
  if (completedAt != null) {
    completedAtMap = {
      'year': completedAt.year,
      'month': completedAt.month,
      'day': completedAt.day,
    };
  }

  final scoreRaw = score > 0 ? (score <= 10.0 ? score * 10.0 : score) : null;

  final serverState = ref.read(serverNotifierProvider);
  final isLoggedIn = serverState.status?.isLoggedIn ?? false;

  bool remoteSuccess = false;
  if (isLoggedIn) {
    remoteSuccess = await repo.editAnilistListEntry(
      mediaId: mediaId,
      type: type,
      status: status,
      score: scoreRaw?.round(),
      progress: progress,
      startedAt: startedAtMap,
      completedAt: completedAtMap,
    );

    if (isAnime) {
      await repo.updateAnimeRepeat(mediaId: mediaId, repeat: repeat);
    }
  }

  if (isAnime) {
    await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
      mediaId: mediaId,
      title: title,
      status: status,
      score: score,
      progress: progress,
      totalCount: totalCount,
      repeat: repeat,
    );
    ref.invalidate(animeCollectionProvider);
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recommendationsProvider);
  } else {
    await OfflineLibraryService.instance.saveMangaEntryFromEdit(
      mediaId: mediaId,
      title: title,
      status: status,
      score: score,
      progress: progress,
      totalCount: totalCount,
    );
    ref.invalidate(mangaCollectionProvider);
    ref.invalidate(continueReadingMangaProvider);
    ref.invalidate(mangaRecommendationsProvider);
  }

  if (isLoggedIn && !remoteSuccess) {
    await OfflineSyncService.instance.enqueueListEdit(
      mediaId: mediaId,
      type: type,
      status: status,
      score: score,
      progress: progress,
      totalCount: totalCount,
      title: title,
    );
  }

  return remoteSuccess;
}

/// Elimina la entrada tanto en AniList (si hay sesión) como localmente.
Future<void> deleteEditEntry(
  WidgetRef ref, {
  required int mediaId,
  required String type, // 'anime' | 'manga'
}) async {
  final isAnime = type == 'anime';
  final serverState = ref.read(serverNotifierProvider);
  final isLoggedIn = serverState.status?.isLoggedIn ?? false;
  final repo = ref.read(repositoryProvider);

  if (isLoggedIn) {
    await repo.deleteAnilistListEntry(mediaId: mediaId, type: type);
  }

  if (isAnime) {
    await OfflineLibraryService.instance.deleteAnimeEntry(mediaId);
    ref.invalidate(animeCollectionProvider);
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(recommendationsProvider);
  } else {
    await OfflineLibraryService.instance.deleteMangaEntry(mediaId);
    ref.invalidate(mangaCollectionProvider);
    ref.invalidate(continueReadingMangaProvider);
  }
}
