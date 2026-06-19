import 'package:flutter/material.dart';

class MoodDef {
  const MoodDef({
    required this.label,
    required this.query,
    required this.cluster,
    required this.vibe,
    required this.tagline,
    required this.accent,
    required this.imageAsset,
    required this.gradientColors,
  });

  final String label;
  final String query;
  final String cluster;
  final String vibe;
  final String tagline;
  final Color accent;
  final String imageAsset;
  final List<Color> gradientColors;
}

const kMoods = <MoodDef>[
  MoodDef(
    label: 'On Sight',
    query: 'drill, trap bangers, rage',
    cluster: 'Aggressive',
    vibe: 'drill, trap bangers, rage',
    tagline: 'No warning shots.',
    accent: Color(0xFFE8192C),
    imageAsset: 'assets/mooddb/onsight.webp',
    gradientColors: [Color(0xFF8B0000), Color(0xFF1A1A1A)],
  ),
  MoodDef(
    label: 'Soul Search',
    query: 'J. Cole mode, conscious rap',
    cluster: 'Introspective',
    vibe: 'J. Cole mode, conscious rap',
    tagline: 'In your bag, in your head.',
    accent: Color(0xFF6B5B95),
    imageAsset: 'assets/mooddb/soulsearch.webp',
    gradientColors: [Color(0xFF4A3F6B), Color(0xFF1E1A2E)],
  ),
  MoodDef(
    label: 'Money Talk',
    query: 'Celebration, flexing, wins',
    cluster: 'Triumphant',
    vibe: 'Celebration, flexing, wins',
    tagline: 'Receipts on receipts.',
    accent: Color(0xFFC9A030),
    imageAsset: 'assets/mooddb/moneytalk.webp',
    gradientColors: [Color(0xFF8B6914), Color(0xFF2A2410)],
  ),
  MoodDef(
    label: 'Blue Hours',
    query: 'Heartbreak, late night',
    cluster: 'Melancholic',
    vibe: 'Heartbreak, late night',
    tagline: 'After hours only.',
    accent: Color(0xFF3D5A80),
    imageAsset: 'assets/mooddb/Bluehours.webp',
    gradientColors: [Color(0xFF2C3E50), Color(0xFF0D1B2A)],
  ),
  MoodDef(
    label: 'Low Rider',
    query: 'Lo-fi hip-hop, boom bap',
    cluster: 'Chill',
    vibe: 'Lo-fi hip-hop, boom bap',
    tagline: 'Cruise control.',
    accent: Color(0xFFB86A48),
    imageAsset: 'assets/mooddb/Lowrider.webp',
    gradientColors: [Color(0xFF8B4513), Color(0xFF2A1810)],
  ),
  MoodDef(
    label: 'Turn Up',
    query: 'Workout, turn up',
    cluster: 'Hype',
    vibe: 'Workout, turn up',
    tagline: 'Stage dive energy.',
    accent: Color(0xFF9AB820),
    imageAsset: 'assets/mooddb/Moshpit.webp',
    gradientColors: [Color(0xFF6B8E23), Color(0xFF1A2010)],
  ),
  MoodDef(
    label: "God's Plan",
    query: "god's plan",
    cluster: 'Spiritual',
    vibe: 'Faith, legacy, purpose',
    tagline: 'Bigger than the moment.',
    accent: Color(0xFF8A8078),
    imageAsset: 'assets/mooddb/Godsplan.webp',
    gradientColors: [Color(0xFF5C534A), Color(0xFF1E1C1A)],
  ),
];

MoodDef? moodByQuery(String? query) {
  if (query == null || query.isEmpty) return null;
  final normalized = query.toLowerCase().trim();
  for (final mood in kMoods) {
    if (mood.query.toLowerCase().trim() == normalized) return mood;
  }
  return null;
}

String moodSearchQuery(String query) {
  final mood = moodByQuery(query);
  if (mood == null) throw ArgumentError('Unknown mood query: $query');
  return mood.vibe;
}

String moodPlaylistId(String query) {
  return 'mood:${moodSearchQuery(query).toLowerCase().trim()}';
}

String? moodVibeFromPlaylistId(String playlistId) {
  if (!playlistId.startsWith('mood:')) return null;
  return playlistId.substring(5).trim();
}

MoodDef? moodByVibe(String vibe) {
  final normalized = vibe.toLowerCase().trim();
  for (final mood in kMoods) {
    if (mood.vibe.toLowerCase().trim() == normalized) return mood;
  }
  return null;
}
