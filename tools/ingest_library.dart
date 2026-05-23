import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const String tmdbApiKey = 'b03a69657e3c54faa142f4d68b378b34';
const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';

final videoExtensions = ['.mp4', '.mkv', '.avi', '.wmv', '.mov', '.flv', '.webm'];

class MediaItem {
  final String title;
  final bool isTvShow;
  final String localPath;

  MediaItem(this.title, this.isTvShow, this.localPath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && runtimeType == other.runtimeType && title == other.title;

  @override
  int get hashCode => title.hashCode;
}

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart ingest_library.dart <path_to_hard_drive>');
    exit(1);
  }

  final rootDir = Directory(args[0]);
  if (!rootDir.existsSync()) {
    print('Error: Directory does not exist.');
    exit(1);
  }

  print('Scanning directory: ${rootDir.path}...');
  
  final mediaItems = <MediaItem>{};

  // Safe manual traversal to avoid Access Denied errors on Windows hidden folders
  Future<void> walkDirectory(Directory dir) async {
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } catch (e) {
      // Skip inaccessible directories (like $RECYCLE.BIN)
      return;
    }

    for (var entity in entities) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        // Skip known problematic Windows system folders
        if (name.startsWith('\$') || name.toLowerCase() == 'system volume information') continue;
        await walkDirectory(entity);
      } else if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (videoExtensions.contains(ext)) {
          final parentDir = entity.parent;
          final parentName = p.basename(parentDir.path);
          
          bool isSeasonFolder = RegExp(r'season\s*\d+', caseSensitive: false).hasMatch(parentName) ||
                                RegExp(r's\d+', caseSensitive: false).hasMatch(parentName) ||
                                parentName.toLowerCase().startsWith('specials');

          String titleToSearch;
          bool isTvShow = false;

          if (isSeasonFolder) {
            titleToSearch = p.basename(parentDir.parent.path);
            isTvShow = true;
          } else {
            titleToSearch = parentName;
            // Determine if parent's parent implies it's a TV show
            final grandParentName = p.basename(parentDir.parent.path).toLowerCase();
            if (grandParentName.contains('tv') || grandParentName.contains('series')) {
              isTvShow = true;
            }
          }

          // Clean up the title
          titleToSearch = _cleanTitle(titleToSearch);
          
          mediaItems.add(MediaItem(titleToSearch, isTvShow, parentDir.path));
        }
      }
    }
  }

  await walkDirectory(rootDir);

  print('Found ${mediaItems.length} unique media titles. Fetching metadata from TMDB...');

  final assetsDir = Directory(p.join(Directory.current.path, 'assets', 'images', 'posters'));
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  List<Map<String, dynamic>> librarySeed = [];

  for (var item in mediaItems) {
    print('Processing: ${item.title}');
    final metadata = await _fetchMetadata(item.title, item.isTvShow);
    
    if (metadata != null) {
      String? localPosterPath;
      
      // Look for a local poster first in the directory
      final localFolder = Directory(item.localPath);
      File? existingPoster;
      try {
        final files = localFolder.listSync();
        for (var f in files) {
          if (f is File && (f.path.toLowerCase().endsWith('poster.jpg') || f.path.toLowerCase().endsWith('folder.jpg') || f.path.toLowerCase().endsWith('.png'))) {
            existingPoster = f;
            break;
          }
        }
      } catch (e) {
        // Ignored
      }

      final safeTitle = item.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();

      if (existingPoster != null) {
        final targetPath = p.join(assetsDir.path, '${safeTitle}_poster${p.extension(existingPoster.path)}');
        existingPoster.copySync(targetPath);
        localPosterPath = 'assets/images/posters/${p.basename(targetPath)}';
        print('  -> Copied local poster.');
      } else if (metadata['poster_path'] != null) {
        // Download from TMDB
        final imageUrl = '$tmdbImageBaseUrl${metadata['poster_path']}';
        final targetPath = p.join(assetsDir.path, '${safeTitle}_poster.jpg');
        await _downloadImage(imageUrl, targetPath);
        localPosterPath = 'assets/images/posters/${p.basename(targetPath)}';
        print('  -> Downloaded TMDB poster.');
      }

      // Map TMDB genres
      List<String> genres = [];
      if (metadata['genre_ids'] != null) {
         genres = (metadata['genre_ids'] as List).map((id) => _mapGenreId(id)).toList();
      }

      String? ageRating;
      try {
        if (!item.isTvShow) {
          final rdRes = await http.get(Uri.parse('$tmdbBaseUrl/movie/${metadata['id']}/release_dates?api_key=$tmdbApiKey'));
          if (rdRes.statusCode == 200) {
            final rdData = jsonDecode(rdRes.body);
            for (var r in rdData['results'] ?? []) {
              if (r['iso_3166_1'] == 'US') {
                for (var rd in r['release_dates'] ?? []) {
                  if (rd['certification'] != null && rd['certification'].toString().isNotEmpty) {
                    ageRating = rd['certification'];
                    break;
                  }
                }
              }
              if (ageRating != null) break;
            }
          }
        } else {
          final crRes = await http.get(Uri.parse('$tmdbBaseUrl/tv/${metadata['id']}/content_ratings?api_key=$tmdbApiKey'));
          if (crRes.statusCode == 200) {
            final crData = jsonDecode(crRes.body);
            for (var r in crData['results'] ?? []) {
              if (r['iso_3166_1'] == 'US') {
                ageRating = r['rating'];
                break;
              }
            }
          }
        }
      } catch (e) {
        print('Error fetching age rating: $e');
      }
      
      if (ageRating == null || ageRating.isEmpty) {
        ageRating = item.isTvShow ? 'TV-14' : 'PG-13';
      }

      librarySeed.add({
        'id': metadata['id'].toString(),
        'title': metadata['title'] ?? metadata['name'] ?? item.title,
        'type': item.isTvShow ? 'tv' : 'movie',
        'year': _extractYear(metadata['release_date'] ?? metadata['first_air_date']),
        'synopsis': metadata['overview'] ?? '',
        'rating': (metadata['vote_average'] ?? 0.0).toDouble(),
        'genres': genres,
        'poster_path': localPosterPath,
        'age_rating': ageRating,
      });
    } else {
      print('  -> No TMDB data found for ${item.title}');
    }
    
    // Rate Limiting (~25 requests per second)
    await Future.delayed(Duration(milliseconds: 100)); // Increased delay for extra calls
  }

  // Save the seed JSON
  final seedFile = File(p.join(Directory.current.path, 'assets', 'library_seed.json'));
  seedFile.createSync(recursive: true);
  seedFile.writeAsStringSync(jsonEncode(librarySeed));

  print('Ingestion complete! Wrote ${librarySeed.length} items to assets/library_seed.json');
}

String _cleanTitle(String rawTitle) {
  var t = rawTitle;
  // Remove resolution tags
  t = t.replaceAll(RegExp(r'(1080p|720p|4k|2160p|bluray|web-dl|hdtv|x264|x265|hevc)', caseSensitive: false), '');
  // Remove years in parentheses or brackets e.g. (2020) or [2020]
  t = t.replaceAll(RegExp(r'[\(\[\{]\d{4}[\)\]\}]'), '');
  // Remove anything after a standalone year
  t = t.replaceAll(RegExp(r'\s(19|20)\d{2}.*$'), '');
  // Remove dots and underscores
  t = t.replaceAll('.', ' ').replaceAll('_', ' ');
  // Trim spaces
  return t.trim();
}

Future<Map<String, dynamic>?> _fetchMetadata(String title, bool isTvShow) async {
  final endpoint = isTvShow ? '/search/tv' : '/search/movie';
  final url = Uri.parse('$tmdbBaseUrl$endpoint?api_key=$tmdbApiKey&query=${Uri.encodeComponent(title)}');
  
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        return data['results'][0];
      }
    }
  } catch (e) {
    print('Error fetching metadata for $title: $e');
  }
  
  // Fallback to multi-search if explicit type didn't work
  final multiUrl = Uri.parse('$tmdbBaseUrl/search/multi?api_key=$tmdbApiKey&query=${Uri.encodeComponent(title)}');
  try {
    final response = await http.get(multiUrl);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        for (var result in data['results']) {
          if (result['media_type'] == 'movie' || result['media_type'] == 'tv') {
            return result;
          }
        }
      }
    }
  } catch (e) {
    // Ignore
  }

  return null;
}

Future<void> _downloadImage(String url, String savePath) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(savePath);
      file.writeAsBytesSync(response.bodyBytes);
    }
  } catch (e) {
    print('Error downloading image: $e');
  }
}

String _extractYear(String? dateStr) {
  if (dateStr == null || dateStr.length < 4) return 'Unknown';
  return dateStr.substring(0, 4);
}

// Basic TMDB Genre ID mapping
String _mapGenreId(int id) {
  const map = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };
  return map[id] ?? 'Other';
}
