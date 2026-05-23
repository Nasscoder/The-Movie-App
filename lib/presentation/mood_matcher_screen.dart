import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../domain/providers.dart';
import '../data/models.dart';
import '../core/theme.dart';

class MoodMatcherScreen extends ConsumerStatefulWidget {
  const MoodMatcherScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MoodMatcherScreen> createState() => _MoodMatcherScreenState();
}

class _MoodMatcherScreenState extends ConsumerState<MoodMatcherScreen> {
  // Mapping custom abstract moods to TMDB genres or keywords
  final List<Map<String, dynamic>> moods = [
    {'title': 'Adrenaline Rush', 'icon': Icons.flash_on, 'color': Colors.redAccent, 'genres': ['Action', 'Thriller']},
    {'title': 'Need a Laugh', 'icon': Icons.sentiment_very_satisfied, 'color': Colors.orangeAccent, 'genres': ['Comedy']},
    {'title': 'Halloween Chills', 'icon': Icons.nights_stay, 'color': Colors.deepPurple, 'genres': ['Horror', 'Mystery']},
    {'title': 'Cozy & Wholesome', 'icon': Icons.coffee, 'color': Colors.brown, 'genres': ['Family', 'Romance', 'Animation']},
    {'title': 'Mind Bending', 'icon': Icons.psychology, 'color': Colors.blueAccent, 'genres': ['Science Fiction', 'Mystery']},
    {'title': 'Epic Journey', 'icon': Icons.map, 'color': Colors.green, 'genres': ['Adventure', 'Fantasy']},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Mood Matcher')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How are you feeling today?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ).animate().fadeIn().slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            const Text(
              'Select a mood and we will curate the perfect watchlist from your library.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: moods.length,
                itemBuilder: (context, index) {
                  final mood = moods[index];
                  return InkWell(
                    onTap: () => _matchMood(mood['genres'] as List<String>),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (mood['color'] as Color).withOpacity(0.7),
                            (mood['color'] as Color).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (mood['color'] as Color).withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: (mood['color'] as Color).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(mood['icon'] as IconData, size: 48, color: Colors.white)
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                          const SizedBox(height: 12),
                          Text(
                            mood['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: (index * 100).ms).scale(curve: Curves.easeOutBack);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _matchMood(List<String> targetGenres) async {
    final allMedia = await ref.read(mediaListProvider.future);
    
    // Simple matching algorithm: Find media that contain ANY of the target genres
    final matches = allMedia.where((media) {
      final mediaGenres = media.genreList.map((e) => e.toLowerCase()).toSet();
      final targets = targetGenres.map((e) => e.toLowerCase()).toSet();
      return mediaGenres.intersection(targets).isNotEmpty;
    }).toList();
    
    matches.shuffle(); // Randomize results

    if (!mounted) return;

    _showResultsBottomSheet(context, matches);
  }

  void _showResultsBottomSheet(BuildContext context, List<Media> results) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GlassContainer(
          padding: const EdgeInsets.all(0),
          borderRadius: 32,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor, // Matches theme style
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text('We found ${results.length} matches!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary))
                      .animate().fadeIn().slideX(begin: 0.2),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('No matches found in your library for this mood.', style: TextStyle(color: AppTheme.textSecondary)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final media = results[index];
                            return GestureDetector(
                              onTap: () {
                                context.pop(); // Close sheet
                                context.push('/details', extra: media);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(color: AppTheme.accentPink.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image(image: _getPosterImage(media.posterPath), fit: BoxFit.cover, width: double.infinity),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                  Text(media.year, style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ).animate(delay: (index < 20 ? index * 50 : 0).ms).fadeIn(duration: 400.ms).scale(curve: Curves.easeOutBack);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ImageProvider _getPosterImage(String path) {
    if (path.isEmpty) return const AssetImage('assets/placeholder.png');
    if (path.startsWith('assets/')) return AssetImage(path);
    return FileImage(File(path));
  }
}
