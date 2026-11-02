import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/presentation/providers/episodes_provider.dart';

void main() {
  group('TMDB integration wiring', () {
    test('EpisodesArgs separates movie and tv ids', () {
      const tv = EpisodesArgs(mediaId: 123, isTmdb: true, mediaType: 'tv');
      const movie = EpisodesArgs(
        mediaId: 123,
        isTmdb: true,
        mediaType: 'movie',
      );

      expect(tv, isNot(movie));
      expect(tv.hashCode, isNot(movie.hashCode));
      expect(
        tv,
        const EpisodesArgs(mediaId: 123, isTmdb: true, mediaType: 'tv'),
      );
    });

    test('TMDB movie details map to a movie AnimeDetails with isTmdb', () {
      const details = TmdbShowDetails(
        id: 550,
        name: 'Fight Club',
        originalName: 'Fight Club',
        firstAirDate: '1999-10-15',
        runtime: 139,
        isMovie: true,
      );

      final animeDetails = details.toAnimeDetails();

      expect(animeDetails.isTmdb, isTrue);
      expect(animeDetails.format, 'MOVIE');
      expect(animeDetails.totalEpisodes, 1);
      expect(animeDetails.seasonYear, 1999);
    });

    test('TMDB tv details map to a tv AnimeDetails with isTmdb', () {
      const details = TmdbShowDetails(
        id: 1399,
        name: 'Game of Thrones',
        originalName: 'Game of Thrones',
        firstAirDate: '2011-04-17',
        numberOfSeasons: 8,
        numberOfEpisodes: 73,
      );

      final animeDetails = details.toAnimeDetails();

      expect(animeDetails.isTmdb, isTrue);
      expect(animeDetails.format, 'TV');
      expect(animeDetails.totalEpisodes, 73);
    });

    test('onlinestream providers expose providerType and legacy support', () {
      const provider = OnlinestreamProvider(
        id: 'tmdb-provider',
        name: 'TMDB Provider',
        lang: 'en',
        type: OnlinestreamProviderType.both,
      );

      expect(provider.supportsTmdb, isTrue);
      expect(provider.supportsAnime, isTrue);
      expect(
        OnlinestreamProvider.fromJson(const {
          'id': 'tmdb-provider',
          'name': 'TMDB Provider',
          'providerType': 'tmdb',
        }).isTmdbOnly,
        isTrue,
      );
      // Legacy extensions without providerType are treated as "both" when
      // they declare supportsTmdb.
      final legacy = OnlinestreamProvider.fromJson(const {
        'id': 'legacy',
        'name': 'Legacy',
        'supportsTmdb': true,
      });
      expect(legacy.type, OnlinestreamProviderType.both);
    });
    test('TMDB details expose cast and trailer for the shared detail layout',
        () {
      final details = TmdbShowDetails.fromJson({
        'id': 209867,
        'name': 'Frieren',
        'credits': {
          'cast': [
            {
              'id': 1,
              'name': 'Actor',
              'character': 'Hero',
              'profile_path': '/p.jpg',
            },
          ],
        },
        'videos': {
          'results': [
            {'site': 'YouTube', 'type': 'Trailer', 'key': 'abc123'},
          ],
        },
      });

      final anime = details.toAnimeDetails();
      final credits = anime.rawMedia!['credits'] as Map<String, dynamic>;
      final cast = credits['cast'] as List<dynamic>;
      final trailer = anime.rawMedia!['trailer'] as Map<String, dynamic>;

      expect(cast, hasLength(1));
      expect(trailer['id'], 'abc123');
      expect(trailer['site'], 'YouTube');
    });
  });
}
