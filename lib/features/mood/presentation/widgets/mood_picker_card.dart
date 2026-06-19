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
      duration: const Duration(milliseconds: 900),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.08),
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
    final orbSize = isSm ? 80.0 : 72.0;
    final itemWidth = isSm ? 96.0 : 88.0;
    final gap = isSm ? 14.0 : 12.0;
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    final fadeColor = cardColor;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, isSm ? 12 : 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: theme.colorScheme.primary,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(isSm ? 20 : 16, 12, isSm ? 16 : 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'HIFFI MIX',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MoodOrb.heightFor(orbSize),
                      child: Stack(
                        children: [
                          ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 4),
                            itemCount: kMoods.length + 1,
                            separatorBuilder: (_, __) => SizedBox(width: gap),
                            itemBuilder: (context, index) {
                              if (index == kMoods.length) {
                                return SizedBox(width: isSm ? 24 : 20);
                              }
                              final mood = kMoods[index];
                              return SizedBox(
                                width: itemWidth,
                                child: MoodOrb(
                                  mood: mood,
                                  selected: _selectedQuery == mood.query,
                                  size: orbSize,
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
                                width: 32,
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
            ],
          ),
        ),
      ),
    );
  }
}
