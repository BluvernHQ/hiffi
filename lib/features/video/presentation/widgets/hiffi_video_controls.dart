import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:hiffi/core/services/media/media_sync_service.dart';

// Chewie provides PlayerNotifier in the widget tree; we need it for hide/show sync.
// ignore: implementation_imports
import 'package:chewie/src/notifiers/player_notifier.dart';
// ignore: implementation_imports
import 'package:chewie/src/material/widgets/options_dialog.dart';
// ignore: implementation_imports
import 'package:chewie/src/material/widgets/playback_speed_dialog.dart';

/// Video controls with center Play/Pause only and Previous/Next video buttons.
/// Seeking is handled by double-tap gestures (left = backward, right = forward).
class HiffiVideoControls extends StatefulWidget {
  const HiffiVideoControls({this.showPlayButton = true, super.key});

  final bool showPlayButton;

  @override
  State<HiffiVideoControls> createState() => _HiffiVideoControlsState();
}

class _HiffiVideoControlsState extends State<HiffiVideoControls> {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _dragging = false;

  final double _barHeight = 48.0 * 1.5;
  final double _marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  ChewieController get chewieController => _chewieController!;

  @override
  void initState() {
    super.initState();
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  void _initialize() {
    controller.addListener(_updateState);
    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() => notifier.hideStuff = false);
      });
    }
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
    setState(() => notifier.hideStuff = false);
  }

  void _startHideTimer() {
    final hideControlsTimer = chewieController.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieController.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      setState(() => notifier.hideStuff = true);
    });
  }

  void _updateState() {
    if (!mounted) return;
    setState(() => _latestValue = controller.value);
  }

  void _playPause() {
    final bool isFinished =
        (_latestValue.position >= _latestValue.duration) &&
            _latestValue.duration.inSeconds > 0;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();
        if (!controller.value.isInitialized) {
          controller.initialize().then((_) => controller.play());
        } else {
          if (isFinished) controller.seekTo(Duration.zero);
          controller.play();
        }
      }
    });
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;
      chewieController.toggleFullScreen();
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) _cancelAndRestartTimer();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(Icons.error, color: Colors.white, size: 42),
          );
    }

    return MouseRegion(
      onHover: (_) => _cancelAndRestartTimer(),
      child: GestureDetector(
        onTap: () => _cancelAndRestartTimer(),
        child: AbsorbPointer(
          absorbing: notifier.hideStuff,
          child: Stack(
            children: [
              _buildHitArea(),
              _buildActionBar(),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildBottomBar(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: notifier.hideStuff ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chewieController.showOptions) _buildOptionsButton(),
            ],
          ),
        ),
      ),
    );
  }

  List<OptionItem> _buildOptions(BuildContext context) {
    final options = <OptionItem>[
      OptionItem(
        onTap: (context) async {
          Navigator.pop(context);
          _onSpeedButtonTap();
        },
        iconData: Icons.speed,
        title: chewieController.optionsTranslation?.playbackSpeedButtonText ??
            'Playback speed',
      ),
    ];
    if (chewieController.additionalOptions != null &&
        chewieController.additionalOptions!(context).isNotEmpty) {
      options.addAll(chewieController.additionalOptions!(context));
    }
    return options;
  }

  Widget _buildOptionsButton() {
    return IconButton(
      onPressed: () async {
        _hideTimer?.cancel();
        if (chewieController.optionsBuilder != null) {
          await chewieController.optionsBuilder!(
            context,
            _buildOptions(context),
          );
        } else {
          await showModalBottomSheet<OptionItem>(
            context: context,
            isScrollControlled: true,
            useRootNavigator: chewieController.useRootNavigator,
            builder: (context) => OptionsDialog(
              options: _buildOptions(context),
              cancelButtonText:
                  chewieController.optionsTranslation?.cancelButtonText,
            ),
          );
        }
        if (_latestValue.isPlaying) _startHideTimer();
      },
      icon: const Icon(Icons.more_vert, color: Colors.white),
    );
  }

  Future<void> _onSpeedButtonTap() async {
    _hideTimer?.cancel();
    final chosenSpeed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: chewieController.useRootNavigator,
      builder: (context) => PlaybackSpeedDialog(
        speeds: chewieController.playbackSpeeds,
        selected: _latestValue.playbackSpeed,
      ),
    );
    if (chosenSpeed != null) controller.setPlaybackSpeed(chosenSpeed);
    if (_latestValue.isPlaying) _startHideTimer();
  }

  Widget _buildHitArea() {
    final bool isFinished =
        (_latestValue.position >= _latestValue.duration) &&
            _latestValue.duration.inSeconds > 0;
    final bool showPlayButton =
        widget.showPlayButton && !_dragging && !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          if (_chewieController?.pauseOnBackgroundTap ?? false) {
            _playPause();
            _cancelAndRestartTimer();
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();
          setState(() => notifier.hideStuff = true);
        }
      },
      child: Container(
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton(
              show: showPlayButton,
              icon: Icons.skip_previous,
              enabled: MediaSyncService().hasPreviousVideo,
              onPressed: () {
                _cancelAndRestartTimer();
                MediaSyncService().requestPreviousVideo();
              },
            ),
            _buildCenterPlayPause(isFinished: isFinished, show: showPlayButton),
            _buildNavButton(
              show: showPlayButton,
              icon: Icons.skip_next,
              onPressed: () {
                _cancelAndRestartTimer();
                MediaSyncService().requestNextVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required bool show,
    required IconData icon,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _marginSize),
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            iconSize: 28,
            padding: const EdgeInsets.all(10),
            icon: Icon(
              icon,
              color: enabled
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
            ),
            onPressed: enabled ? onPressed : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPlayPause({required bool isFinished, required bool show}) {
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _marginSize),
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            iconSize: 36,
            padding: const EdgeInsets.all(12),
            icon: isFinished
                ? const Icon(Icons.replay, color: Colors.white)
                : Icon(
                    controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
            onPressed: _playPause,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: _barHeight + (chewieController.isFullScreen ? 10.0 : 0),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: !chewieController.isFullScreen ? 10.0 : 0,
        ),
        child: SafeArea(
          top: false,
          bottom: chewieController.isFullScreen,
          minimum: chewieController.controlsSafeAreaMinimum,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!chewieController.isLive)
                      _buildPosition(Theme.of(context).textTheme.labelLarge?.color),
                    if (chewieController.allowMuting)
                      _buildMuteButton(controller),
                    const Spacer(),
                    if (chewieController.allowFullScreen) _buildExpandButton(),
                  ],
                ),
              ),
              SizedBox(height: chewieController.isFullScreen ? 15.0 : 0),
              if (!chewieController.isLive)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [_buildProgressBar()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;
    final posStr = _formatDuration(position);
    final durStr = _formatDuration(duration);
    return RichText(
      text: TextSpan(
        text: '$posStr ',
        children: [
          TextSpan(
            text: '/ $durStr',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final seconds = d.inSeconds;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m >= 10 ? m : '0$m'}:${s >= 10 ? s : '0$s'}';
  }

  Widget _buildMuteButton(VideoPlayerController c) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();
        if (_latestValue.volume == 0) {
          c.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = c.value.volume;
          c.setVolume(0.0);
        }
        setState(() {});
      },
      child: ClipRect(
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.only(left: 6),
          child: Icon(
            _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: Container(
        height: _barHeight + (chewieController.isFullScreen ? 15.0 : 0),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Center(
          child: Icon(
            chewieController.isFullScreen
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        controller,
        onDragStart: () {
          setState(() => _dragging = true);
          _hideTimer?.cancel();
        },
        onDragUpdate: () => _hideTimer?.cancel(),
        onDragEnd: () {
          setState(() => _dragging = false);
          _startHideTimer();
        },
        colors: chewieController.materialProgressColors ??
            ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.secondary,
              handleColor: Theme.of(context).colorScheme.secondary,
              bufferedColor: Theme.of(context)
                  .colorScheme
                  .surface
                  .withOpacity(0.5),
              backgroundColor: Theme.of(context)
                  .disabledColor
                  .withOpacity(0.5),
            ),
        draggableProgressBar: chewieController.draggableProgressBar,
      ),
    );
  }
}
