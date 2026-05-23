import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db_helper.dart';
import '../data/models.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final mediaListProvider = FutureProvider<List<Media>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Yield to the event loop so the UI can draw the first frame (Loading spinner)
  await Future.delayed(const Duration(milliseconds: 100));
  await db.syncWithSeed(); 
  return db.getAllMedia();
});

final watchlistProvider = FutureProvider<List<Media>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getWatchlist();
});

class WatchlistNotifier extends StateNotifier<AsyncValue<List<Media>>> {
  final DatabaseHelper db;
  WatchlistNotifier(this.db) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await db.getWatchlist();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleStatus(Media media) async {
    await db.toggleWatchlist(media.id, !media.isWatchlisted);
    refresh();
  }
}

final watchlistNotifierProvider = StateNotifierProvider<WatchlistNotifier, AsyncValue<List<Media>>>((ref) {
  final db = ref.watch(databaseProvider);
  return WatchlistNotifier(db);
});

// Provides search functionality
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Media>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final db = ref.watch(databaseProvider);
  if (query.isEmpty) return db.getAllMedia();
  return db.searchMedia(query);
});
