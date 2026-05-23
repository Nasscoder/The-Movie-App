class Media {
  final String id;
  final String title;
  final String type; // 'movie' or 'tv'
  final String year;
  final String synopsis;
  final double rating;
  final String genres; // Stored as comma-separated string in SQLite
  final String posterPath; // Local path in assets
  final bool isWatchlisted;
  final String ageRating; // New field

  Media({
    required this.id,
    required this.title,
    required this.type,
    required this.year,
    required this.synopsis,
    required this.rating,
    required this.genres,
    required this.posterPath,
    this.isWatchlisted = false,
    this.ageRating = 'PG-13', // Default
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'year': year,
      'synopsis': synopsis,
      'rating': rating,
      'genres': genres,
      'posterPath': posterPath,
      'isWatchlisted': isWatchlisted ? 1 : 0,
      'ageRating': ageRating,
    };
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      id: map['id'],
      title: map['title'],
      type: map['type'],
      year: map['year'],
      synopsis: map['synopsis'],
      rating: map['rating'],
      genres: map['genres'],
      posterPath: map['posterPath'],
      isWatchlisted: map['isWatchlisted'] == 1,
      ageRating: map['ageRating'] ?? 'PG-13',
    );
  }

  List<String> get genreList => genres.split(',').where((e) => e.isNotEmpty).toList();
}
