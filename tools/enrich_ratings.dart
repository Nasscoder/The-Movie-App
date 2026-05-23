import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const String tmdbApiKey = 'b03a69657e3c54faa142f4d68b378b34';
const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

void main() async {
  final seedFile = File(p.join(Directory.current.path, 'assets', 'library_seed.json'));
  if (!seedFile.existsSync()) {
    print('Error: assets/library_seed.json not found.');
    exit(1);
  }

  print('Reading library_seed.json...');
  final jsonString = seedFile.readAsStringSync();
  final List<dynamic> mediaList = jsonDecode(jsonString);

  print('Fetching age ratings for ${mediaList.length} items from TMDB...');

  int updatedCount = 0;

  for (var i = 0; i < mediaList.length; i++) {
    final item = mediaList[i];
    final id = item['id'];
    final type = item['type']; // 'movie' or 'tv'
    final title = item['title'];
    
    // Skip if we already have it
    if (item.containsKey('age_rating') && item['age_rating'] != null) {
      continue;
    }

    String? ageRating;

    try {
      if (type == 'movie') {
        final url = Uri.parse('$tmdbBaseUrl/movie/$id/release_dates?api_key=$tmdbApiKey');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>;
          // Try to find US certification
          for (var r in results) {
            if (r['iso_3166_1'] == 'US') {
              final releaseDates = r['release_dates'] as List<dynamic>;
              for (var rd in releaseDates) {
                if (rd['certification'] != null && rd['certification'].toString().isNotEmpty) {
                  ageRating = rd['certification'];
                  break;
                }
              }
            }
            if (ageRating != null) break;
          }
        }
      } else if (type == 'tv') {
        final url = Uri.parse('$tmdbBaseUrl/tv/$id/content_ratings?api_key=$tmdbApiKey');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>;
          for (var r in results) {
            if (r['iso_3166_1'] == 'US') {
              ageRating = r['rating'];
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching rating for $title: $e');
    }

    // Default if not found
    if (ageRating == null || ageRating.isEmpty) {
      // Check genres to fallback
      final genres = (item['genres'] as List).map((e) => e.toString().toLowerCase()).toList();
      if (type == 'tv') {
        if (genres.contains('family') || genres.contains('kids') || genres.contains('animation')) ageRating = 'TV-Y7';
        else if (genres.contains('horror') || genres.contains('crime')) ageRating = 'TV-MA';
        else ageRating = 'TV-14';
      } else {
        if (genres.contains('family') || genres.contains('animation')) ageRating = 'PG';
        else if (genres.contains('horror') || genres.contains('crime') || genres.contains('thriller')) ageRating = 'R';
        else ageRating = 'PG-13';
      }
      print('  -> [$i/${mediaList.length}] $title: Defaulted to $ageRating');
    } else {
      print('  -> [$i/${mediaList.length}] $title: Found $ageRating');
      updatedCount++;
    }

    item['age_rating'] = ageRating;

    // Rate limiting delay (TMDB limit is ~40 req/10sec)
    await Future.delayed(const Duration(milliseconds: 100));
  }

  print('Writing updated JSON back to file...');
  final encoder = JsonEncoder.withIndent('    ');
  seedFile.writeAsStringSync(encoder.convert(mediaList));

  print('Successfully enriched $updatedCount items with age ratings!');
}
