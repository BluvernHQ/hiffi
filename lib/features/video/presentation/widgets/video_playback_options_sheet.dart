import 'package:flutter/material.dart';

import '../controllers/hls_player_controller.dart';

Future<void> showVideoPlaybackOptionsSheet({
  required BuildContext context,
  required HlsPlayerController controller,
  required VoidCallback onReport,
}) async {
  final chewie = controller.chewieController;
  final playbackSpeeds = chewie?.playbackSpeeds ?? const [0.5, 1.0, 1.5, 2.0];
  final currentSpeed = controller.controller?.value.playbackSpeed ?? 1.0;
  final profiles = controller.availableProfiles.toSet().toList();
  final currentProfile = controller.currentProfile;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      double selectedSpeed = currentSpeed;
      String selectedProfile = currentProfile;

      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Playback & quality',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fine-tune how this video plays.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Playback speed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${selectedSpeed.toStringAsFixed(2).replaceFirst(RegExp(r"\.00$"), "")}x',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: playbackSpeeds.map((speed) {
                          final isSelected =
                              (speed - selectedSpeed).abs() < 0.001;
                          final label = speed
                              .toStringAsFixed(2)
                              .replaceFirst(RegExp(r"\.00$"), '');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${label}x'),
                              selected: isSelected,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedSpeed = speed;
                                });
                                controller.controller?.setPlaybackSpeed(speed);
                              },
                              selectedColor: const Color(
                                0xFFED1C2F,
                              ).withOpacity(0.1),
                              labelStyle: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : null,
                                color: isSelected
                                    ? const Color(0xFFED1C2F)
                                    : Colors.black87,
                              ),
                              backgroundColor: const Color(0xFFF5F5F5),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (profiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quality',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            selectedProfile == 'original'
                                ? 'Original'
                                : selectedProfile.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: profiles.map((profile) {
                            final isSelected = profile == selectedProfile;
                            final label = profile == 'original'
                                ? 'Original'
                                : profile.toUpperCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedProfile = profile;
                                  });
                                  controller.setProfile(profile);
                                },
                                selectedColor: const Color(
                                  0xFFED1C2F,
                                ).withOpacity(0.1),
                                labelStyle: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : null,
                                  color: isSelected
                                      ? const Color(0xFFED1C2F)
                                      : Colors.black87,
                                ),
                                backgroundColor: const Color(0xFFF5F5F5),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const Divider(height: 28),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.flag_outlined,
                        color: Colors.grey[800],
                      ),
                      title: const Text('Report video'),
                      subtitle: const Text(
                        'Report harmful or inappropriate content',
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Future.microtask(onReport);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
