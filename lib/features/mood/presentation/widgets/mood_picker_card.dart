import 'package:flutter/material.dart';

import '../../domain/models/mood_def.dart';
import 'mood_orb.dart';

class MoodPickerCard extends StatefulWidget {
  const MoodPickerCard({
    super.key,
    required this.onMoodSelected,
    this.initialSelectedQuery,
  });

  final ValueChanged<String> onMoodSelected;
  final String? initialSelectedQuery;

  @override
  State<MoodPickerCard> createState() => _MoodPickerCardState();
}

class _MoodPickerCardState extends State<MoodPickerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  String? _selectedQuery;

  @override
  void initState() {
    super.initState();
    _selectedQuery = widget.initialSelectedQuery;
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleMoodTap(MoodDef mood) {
    setState(() => _selectedQuery = mood.query);
    widget.onMoodSelected(mood.query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isSm = width >= 640;
    final orbSize = isSm ? 62.0 : 56.0;
    final itemWidth = isSm ? 78.0 : 72.0;
    final gap = isSm ? 10.0 : 8.0;
    final fadeColor = theme.colorScheme.surface;

    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 2, 16, isSm ? 8 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Row(
                children: [
                  Text(
                    'Hiffi Mix',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap a vibe',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: MoodOrb.heightFor(orbSize, compact: true),
              child: Stack(
                children: [
                  ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: kMoods.length + 1,
                    separatorBuilder: (_, __) => SizedBox(width: gap),
                    itemBuilder: (context, index) {
                      if (index == kMoods.length) {
                        return SizedBox(width: isSm ? 20 : 16);
                      }
                      final mood = kMoods[index];
                      return SizedBox(
                        width: itemWidth,
                        child: MoodOrb(
                          mood: mood,
                          selected: _selectedQuery == mood.query,
                          size: orbSize,
                          compact: true,
                          onTap: () => _handleMoodTap(mood),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              fadeColor.withValues(alpha: 0),
                              fadeColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
