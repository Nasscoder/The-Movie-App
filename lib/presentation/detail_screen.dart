import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../domain/providers.dart';
import '../core/theme.dart';

class DetailScreen extends ConsumerWidget {
  final Media media;
  const DetailScreen({Key? key, required this.media}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the watchlist state so the FAB updates if the user adds/removes it
    final watchlistState = ref.watch(watchlistNotifierProvider);
    final isSaved = watchlistState.maybeWhen(
      data: (list) => list.any((item) => item.id == media.id),
      orElse: () => media.isWatchlisted,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400.0,
            pinned: true,
            backgroundColor: AppTheme.backgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'poster_${media.id}',
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                    ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image(
                    image: _getPosterImage(media.posterPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          media.title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accentColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              media.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(media.year),
                      _buildChip(media.type.toUpperCase()),
                      ...media.genreList.map((g) => _buildChip(g)).toList(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    media.synopsis.isEmpty ? 'No synopsis available.' : media.synopsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(watchlistNotifierProvider.notifier).toggleStatus(media);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isSaved ? 'Removed from Watchlist' : 'Added to Watchlist',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.surfaceColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: isSaved ? AppTheme.surfaceColor : AppTheme.primaryColor,
        icon: Icon(isSaved ? Icons.bookmark_added : Icons.bookmark_add, color: Colors.white),
        label: Text(
          isSaved ? 'Saved' : 'Watchlist',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
    );
  }

  ImageProvider _getPosterImage(String path) {
    if (path.isEmpty) return const AssetImage('assets/placeholder.png');
    if (path.startsWith('assets/')) return AssetImage(path);
    return FileImage(File(path));
  }
}
