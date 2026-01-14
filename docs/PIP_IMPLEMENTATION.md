# Picture-in-Picture (PiP) Implementation

## Overview

This implementation provides a seamless YouTube-like Picture-in-Picture experience for video playback. When the user minimizes the app or switches to another app, the video continues playing in a floating mini-player.

## Architecture

### Components

1. **HlsPlayerController** (`lib/features/video/presentation/controllers/hls_player_controller.dart`)
   - Configures `ChewieController` with `allowPictureInPicture: true`.
   - Provides `enterPiP()` method to trigger PiP mode.

2. **HlsVideoPlayer** (`lib/features/video/presentation/widgets/hls_video_player.dart`)
   - Provides a static registry of controllers.
   - Exposes `HlsVideoPlayer.enterPiP()` for global access.

3. **VideoPlayerPage** (`lib/features/video/presentation/views/video_player_page.dart`)
   - Monitors app lifecycle via `WidgetsBindingObserver`.
   - Automatically triggers `_enterPiP()` when `AppLifecycleState` becomes `paused` or `inactive`.

## Platform Configuration

### Android

**AndroidManifest.xml**:
- Added `android:supportsPictureInPicture="true"` to the main activity.
- The activity is configured to handle configuration changes including orientation and screen size.

### iOS

**Info.plist**:
- Enabled `UIBackgroundModes` with `audio`.
- Added `AVPictureInPictureController.isPictureInPictureSupported: true`.

## Flow

1. **Foreground**: User plays video in `VideoPlayerPage`.
2. **Minimize**: User presses Home or switches apps.
3. **Trigger**: `didChangeAppLifecycleState` detects the change.
4. **Action**: `HlsVideoPlayer.enterPiP()` is called.
5. **Result**: The video moves into a floating window (PiP).
6. **Restore**: User taps the PiP window to return to the app in fullscreen.

## SUCCESS CRITERIA Checklist

- [x] Video continues playing in PiP when app is backgrounded.
- [x] Floating mini-player is resizable and movable (handled by OS).
- [x] Tapping PiP restores fullscreen video.
- [x] Playback position is preserved.
- [x] No crashes on lifecycle transitions.
- [x] Behavior matches YouTube PiP UX.

## Important Notes

- **App Persistence**: PiP only works as long as the app process is alive. If the app is explicitly terminated, playback stops.
- **Audio Mode**: Background audio mode must be enabled for PiP to continue playing audio when the app is backgrounded.
- **No Mixing**: This implementation specifically avoids mixing background audio-only mode with PiP to ensure UX clarity.
