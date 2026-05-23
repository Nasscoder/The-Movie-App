import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../domain/providers.dart';
import '../core/theme.dart';
import 'home_screen.dart'; // For GlassContainer

class StatsScreen extends ConsumerWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistAsync = ref.watch(watchlistNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Watchlist Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: watchlistAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Add movies to your watchlist to see stats.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            );
          }

          // Calculate genre distribution
          final Map<String, int> genreCounts = {};
          for (var media in list) {
            for (var genre in media.genreList) {
              genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
            }
          }

          if (genreCounts.isEmpty) {
             return const Center(child: Text('No genre data available.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          // Sort by count
          final sortedGenres = genreCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          final topGenres = sortedGenres.take(5).toList();
          
          // Generate pie chart data with Neon Colors
          final List<Color> colors = [
            AppTheme.primaryColor,
            AppTheme.accentColor,
            AppTheme.accentPink,
            AppTheme.accentYellow,
            const Color(0xFF00E676), // Neon Green
          ];
          
          List<PieChartSectionData> pieSections = [];
          for (int i = 0; i < topGenres.length; i++) {
            pieSections.add(
              PieChartSectionData(
                color: colors[i % colors.length],
                value: topGenres[i].value.toDouble(),
                title: '${topGenres[i].value}',
                radius: 70,
                titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
              )
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Genres in your Watchlist',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: 1.2),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 280,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 50,
                      sections: pieSections,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ListView.separated(
                    itemCount: topGenres.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        borderRadius: 16,
                        glowColor: colors[index % colors.length],
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: colors[index % colors.length].withOpacity(0.6), blurRadius: 8)
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                topGenres[index].key,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '${topGenres[index].value} items',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentPink)),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
