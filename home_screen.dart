import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../domain/providers.dart';
import '../data/models.dart';
import '../core/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Filters State
  double _minRating = 0.0;
  String _selectedType = 'All';
  String _selectedGenre = 'All';
  String _selectedAgeRating = 'All';
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();
  final PageController _heroController = PageController(viewportFraction: 0.9);
  Timer? _carouselTimer;

  final List<String> _genres = ['All', 'Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi', 'Romance', 'Family', 'Thriller'];
  final List<String> _ageRatings = ['All', 'G', 'PG', 'PG-13', 'R', 'TV-14', 'TV-MA'];

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_heroController.hasClients) {
        int nextPage = (_heroController.page?.toInt() ?? 0) + 1;
        // Basic infinite loop by just continuing forward if we assume there are many items.
        // If we hit the end, it will just bounce back or we can reset, but for now we just push forward.
        // Actually, safer to check max items, but since we don't know it here easily, we'll just animate.
        try {
          _heroController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.fastOutSlowIn,
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _searchController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: mediaAsync.when(
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return const Center(child: Text('No media found. Run the ingestion script!'));
          }

          // Apply filtering
          var filteredList = mediaList.where((m) => m.rating >= _minRating).toList();
          
          if (_selectedType != 'All') {
            filteredList = filteredList.where((m) => m.type.toLowerCase() == _selectedType.toLowerCase()).toList();
          }

          if (_selectedGenre != 'All') {
            filteredList = filteredList.where((m) => m.genres.toLowerCase().contains(_selectedGenre.toLowerCase())).toList();
          }

          if (_selectedAgeRating != 'All') {
            filteredList = filteredList.where((m) => m.ageRating.toLowerCase() == _selectedAgeRating.toLowerCase()).toList();
          }

          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            filteredList = filteredList.where((m) {
              return m.title.toLowerCase().contains(query) || m.genres.toLowerCase().contains(query);
            }).toList();
          }

          final movies = filteredList.where((m) => m.type == 'movie').toList();

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context),
              
              if (_searchQuery.isEmpty && movies.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                    child: SizedBox(
                      height: 400,
                      child: _buildHeroCarousel(movies.take(15).toList()),
                    ),
                  ).animate().fade(duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                ),
                
              if (filteredList.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 24,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildPosterCard(filteredList[index], context)
                            .animate(delay: (index < 20 ? index * 50 : 0).ms)
                            .fade(duration: 500.ms)
                            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack);
                      },
                      childCount: filteredList.length,
                    ),
                  ),
                ),

              if (filteredList.isEmpty)
                SliverFillRemaining(
                  child: const Center(
                    child: Text('No matches found.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                  ).animate().fadeIn(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB padding
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentColor)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentPink,
        tooltip: 'Surprise Me!',
        child: const Icon(Icons.shuffle, color: Colors.white, size: 28)
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2000.ms, color: Colors.white30),
        onPressed: () => _randomize(ref, context),
      ).animate().scale(delay: 500.ms, curve: Curves.elasticOut),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor.withOpacity(0.9),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20.0, bottom: 84.0), // Fixed overflow 
        title: const Text(
          'Vault',
          style: TextStyle(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(color: AppTheme.accentColor, blurRadius: 10),
            ],
          ),
        ).animate().fadeIn(duration: 800.ms).shimmer(delay: 1000.ms, color: Colors.white),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.4),
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.mood, color: AppTheme.accentYellow),
          tooltip: 'Mood Matcher',
          onPressed: () => context.push('/mood'),
        ).animate().shake(delay: 3000.ms, rotation: 0.1, hz: 4),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: () => _showFilterBottomSheet(context),
        )
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68.0), // Increased height to fix 2.0px overflow
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: 30,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies, tv, genres...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: AppTheme.accentColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
        ),
      ),
    );
  }

  Widget _buildHeroCarousel(List<Media> featured) {
    return PageView.builder(
      controller: _heroController,
      itemBuilder: (context, index) {
        if (featured.isEmpty) return const SizedBox();
        final media = featured[index % featured.length];
        return AnimatedBuilder(
          animation: _heroController,
          builder: (context, child) {
            double value = 1.0;
            if (_heroController.position.haveDimensions) {
              value = _heroController.page! - index;
              value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
            }
            return Center(
              child: SizedBox(
                height: Curves.easeOut.transform(value) * 400,
                width: Curves.easeOut.transform(value) * 350,
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              context.push('/details', extra: media);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                image: DecorationImage(
                  image: _getPosterImage(media.posterPath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.title,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accentColor),
                            ),
                            child: Text(media.type.toUpperCase(), style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPink.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accentPink),
                            ),
                            child: Text(media.ageRating, style: const TextStyle(color: AppTheme.accentPink, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${media.year} • ${media.genreList.take(1).join(', ')}', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPosterCard(Media media, BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'poster_${media.id}',
                  child: Image(
                    image: _getPosterImage(media.posterPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          Text('${media.year} • ${media.ageRating}', style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  ImageProvider _getPosterImage(String path) {
    if (path.isEmpty) return const AssetImage('assets/placeholder.png');
    if (path.startsWith('assets/')) return AssetImage(path);
    return FileImage(File(path));
  }

  void _randomize(WidgetRef ref, BuildContext context) async {
    final mediaList = await ref.read(mediaListProvider.future);
    if (mediaList.isEmpty) return;

    final highRated = mediaList.where((m) => m.rating >= 7.0).toList();
    final listToPick = highRated.isNotEmpty ? highRated : mediaList;
    final randomItem = listToPick[Random().nextInt(listToPick.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop(); 
          FocusManager.instance.primaryFocus?.unfocus();
          context.push('/details', extra: randomItem);
        });
        return Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            glowColor: AppTheme.accentPink,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.accentPink),
                const SizedBox(height: 24),
                const Text('Curating magic...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
              ],
            ),
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              margin: const EdgeInsets.all(16),
              child: GlassContainer(
                glowColor: AppTheme.primaryColor,
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: AppTheme.accentColor),
                          const SizedBox(width: 12),
                          const Text('Advanced Filters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ).animate().fadeIn().slideX(begin: -0.2),
                      const SizedBox(height: 32),
                      
                      const Text('Media Type', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ['All', 'Movie', 'TV'].map((type) {
                          final isSelected = _selectedType == type;
                          return InkWell(
                            onTap: () {
                              setModalState(() => _selectedType = type);
                              setState(() => _selectedType = type);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? AppTheme.accentColor : Colors.white30),
                                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 10)] : [],
                              ),
                              child: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      const Text('Genre', style: TextStyle(color: AppTheme.accentPink, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _genres.map((genre) {
                          final isSelected = _selectedGenre == genre;
                          return InkWell(
                            onTap: () {
                              setModalState(() => _selectedGenre = genre);
                              setState(() => _selectedGenre = genre);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accentPink : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? Colors.white : Colors.white30),
                                boxShadow: isSelected ? [BoxShadow(color: AppTheme.accentPink.withOpacity(0.5), blurRadius: 8)] : [],
                              ),
                              child: Text(genre, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      const Text('Age Restriction', style: TextStyle(color: AppTheme.accentYellow, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _ageRatings.map((rating) {
                          final isSelected = _selectedAgeRating == rating;
                          return InkWell(
                            onTap: () {
                              setModalState(() => _selectedAgeRating = rating);
                              setState(() => _selectedAgeRating = rating);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accentYellow : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? Colors.white : Colors.white30),
                                boxShadow: isSelected ? [BoxShadow(color: AppTheme.accentYellow.withOpacity(0.5), blurRadius: 8)] : [],
                              ),
                              child: Text(rating, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text('Minimum Rating: ${_minRating.toStringAsFixed(1)}+', style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.accentColor,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppTheme.accentColor,
                          overlayColor: AppTheme.accentColor.withOpacity(0.2),
                          valueIndicatorColor: AppTheme.primaryColor,
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: _minRating,
                          min: 0,
                          max: 10,
                          divisions: 20,
                          label: _minRating.toStringAsFixed(1),
                          onChanged: (val) {
                            setModalState(() => _minRating = val);
                            setState(() => _minRating = val);
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(color: AppTheme.primaryColor.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4))
                            ],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor, 
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack)
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }
}
