import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_server_item.dart';
import '../models/media_server_library.dart';
import '../models/media_server_type.dart';
import '../services/jellyfin_service.dart';
import '../services/plex_service.dart';
import 'media_servers_provider.dart';

/// Proveedor de las bibliotecas del servidor multimedia actualmente activo.
final mediaServerLibrariesProvider =
    FutureProvider.autoDispose<List<MediaServerLibrary>>((ref) async {
  final server = ref.watch(activeMediaServerProvider);
  if (server == null) return [];

  if (server.type == MediaServerType.plex) {
    return PlexService(server).getLibraries();
  } else {
    return JellyfinService(server).getLibraries();
  }
});

/// Proveedor de los elementos "Continuar viendo" (On Deck / Resume) del servidor activo.
final mediaServerContinueWatchingProvider =
    FutureProvider.autoDispose<List<MediaServerItem>>((ref) async {
  final server = ref.watch(activeMediaServerProvider);
  if (server == null) return [];

  if (server.type == MediaServerType.plex) {
    return PlexService(server).getContinueWatching();
  } else {
    return JellyfinService(server).getContinueWatching();
  }
});

/// Proveedor de elementos contenidos en una biblioteca específica.
final mediaServerLibraryItemsProvider = FutureProvider.autoDispose
    .family<List<MediaServerItem>, String>((ref, libraryId) async {
  final server = ref.watch(activeMediaServerProvider);
  if (server == null) return [];

  if (server.type == MediaServerType.plex) {
    return PlexService(server).getLibraryItems(libraryId);
  } else {
    return JellyfinService(server).getLibraryItems(libraryId);
  }
});

/// Proveedor de episodios de una serie.
final mediaServerShowEpisodesProvider = FutureProvider.autoDispose
    .family<List<MediaServerItem>, String>((ref, showId) async {
  final server = ref.watch(activeMediaServerProvider);
  if (server == null) return [];

  if (server.type == MediaServerType.plex) {
    return PlexService(server).getShowEpisodes(showId);
  } else {
    return JellyfinService(server).getShowEpisodes(showId);
  }
});
