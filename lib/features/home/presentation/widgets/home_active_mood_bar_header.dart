import 'package:flutter/material.dart';

import '../../../mood/domain/models/mood_def.dart';
import '../../../mood/presentation/widgets/active_mood_bar.dart';

class HomeActiveMoodBarHeader extends SliverPersistentHeaderDelegate {
  HomeActiveMoodBarHeader({
    required this.mood,
    required this.onBack,
    required this.onPlay,
  });

  final MoodDef mood;
  final VoidCallback onBack;
  final VoidCallback onPlay;

  @override
  double get minExtent => ActiveMoodBar.kHeight;

  @override
  double get maxExtent => ActiveMoodBar.kHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: ActiveMoodBar.kHeight,
      child: ActiveMoodBar(
        mood: mood,
        onBack: onBack,
        onPlay: onPlay,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeActiveMoodBarHeader oldDelegate) {
    return oldDelegate.mood != mood;
  }
}
