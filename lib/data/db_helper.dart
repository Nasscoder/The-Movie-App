import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

// Top-level function for compute
List<dynamic> _parseJson(String text) {
  return jsonDecode(text) as List<dynamic>;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('media_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS media');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE media (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        year TEXT,
        synopsis TEXT,
        rating REAL,
        genres TEXT,
        posterPath TEXT,
        ageRating TEXT,
        isWatchlisted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _seedDatabase(db);
  }

  String _generateMockAgeRating(String genresStr, String type) {
    final genres = genresStr.toLowerCase();
    if (type == 'tv') {
      if (genres.contains('family') || genres.contains('kids') || genres.contains('animation')) return 'TV-Y7';
      if (genres.contains('horror') || genres.contains('crime')) return 'TV-MA';
      return 'TV-14';
    } else {
      if (genres.contains('family') || genres.contains('animation')) return 'PG';
      if (genres.contains('horror') || genres.contains('crime') || genres.contains('thriller')) return 'R';
      return 'PG-13';
    }
  }

  Future<void> _seedDatabase(Database db) async {
    try {
      final jsonString = await rootBundle.loadString('assets/library_seed.json');
      final List<dynamic> jsonList = _parseJson(jsonString);

      Batch batch = db.batch();
      for (var item in jsonList) {
        final genres = (item['genres'] as List).join(',');
        final type = item['type'];
        batch.insert('media', {
          'id': item['id'].toString(),
          'title': item['title'],
          'type': type,
          'year': item['year'],
          'synopsis': item['synopsis'],
          'rating': item['rating'],
          'genres': genres,
          'posterPath': item['poster_path'] ?? '',
          'ageRating': item['age_rating'] ?? _generateMockAgeRating(genres, type),
          'isWatchlisted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Database seeding failed: $e');
    }
  }

  Future<void> syncWithSeed() async {
    try {
      final db = await instance.database;
      final jsonString = await rootBundle.loadString('assets/library_seed.json');
      // Use compute to decode JSON in a background isolate to avoid freezing the UI
      final List<dynamic> jsonList = await compute(_parseJson, jsonString);

      // Preserve watchlist state
      final existing = await db.query('media', columns: ['id', 'isWatchlisted']);
      final watchlistMap = { for (var e in existing) e['id'] as String: e['isWatchlisted'] as int };

      Batch batch = db.batch();
      for (var item in jsonList) {
        final id = item['id'].toString();
        final genres = (item['genres'] as List).join(',');
        final type = item['type'];
        batch.insert('media', {
          'id': id,
          'title': item['title'],
          'type': type,
          'year': item['year'],
          'synopsis': item['synopsis'],
          'rating': item['rating'],
          'genres': genres,
          'posterPath': item['poster_path'] ?? '',
          'ageRating': item['age_rating'] ?? _generateMockAgeRating(genres, type),
          'isWatchlisted': watchlistMap[id] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Database sync failed: $e');
    }
  }

  Future<List<Media>> getAllMedia() async {
    final db = await instance.database;
    final result = await db.query('media', orderBy: 'title ASC');
    return result.map((json) => Media.fromMap(json)).toList();
  }

  Future<List<Media>> getWatchlist() async {
    final db = await instance.database;
    final result = await db.query('media', where: 'isWatchlisted = ?', whereArgs: [1]);
    return result.map((json) => Media.fromMap(json)).toList();
  }

  Future<void> toggleWatchlist(String id, bool status) async {
    final db = await instance.database;
    await db.update(
      'media',
      {'isWatchlisted': status ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Media>> searchMedia(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'media',
      where: 'title LIKE ? OR genres LIKE ?',
      whereArgs: ['%${query}%', '%${query}%'],
    );
    return result.map((json) => Media.fromMap(json)).toList();
  }
}
