import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/providers.dart';
import '../data/models.dart';
import '../core/theme.dart';
import 'dart:io';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistAsync = ref.watch(watchlistNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.backgroundColor.withOpacity(0.9),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              title: Text(
                'My Watchlist',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: AppTheme.accentPink.withOpacity(0.8), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
          watchlistAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('Your watchlist is empty.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 24,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildPosterCard(list[index], context, ref);
                    },
                    childCount: list.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.accentPink))),
            error: (e, st) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB/BottomNav padding
        ],
      ),
    );
  }

  Widget _buildPosterCard(Media media, BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/details', extra: media),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPink.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Hero(
                      tag: 'watchlist_poster_${media.id}',
                      child: Image(
                        image: _getPosterImage(media.posterPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => ref.read(watchlistNotifierProvider.notifier).toggleStatus(media),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentPink, width: 1.5),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          Text(media.year, style: const TextStyle(color: AppTheme.accentPink, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  ImageProvider _getPosterImage(String path) {
    if (path.isEmpty) return const AssetImage('assets/placeholder.png');
    if (path.startsWith('assets/')) return AssetImage(path);
    return FileImage(File(path));
  }
}
