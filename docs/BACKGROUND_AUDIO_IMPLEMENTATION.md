# Background Audio Playback Implementation

## Overview

This document describes the production-grade background audio playback implementation that enables seamless transitions between foreground video and background audio playback, matching YouTube/Spotify UX patterns.

## Architecture

### Components

1. **HiffiAudioHandler** (`lib/core/services/media/hiffi_audio_handler.dart`)
   - Extends `BaseAudioHandler` with `SeekHandler` and `QueueHandler`
   - Manages `just_audio` player for background playback
   - Implements proper MediaSession with MediaItem and PlaybackState
   - Handles position updates, seek, play/pause

2. **MediaSyncService** (`lib/core/services/media/media_sync_service.dart`)
   - Singleton service managing video ↔ audio transitions
   - Tracks current video controller and video model
   - Handles lifecycle state changes
   - Syncs playback position between video and audio

3. **HlsPlayerController** (Enhanced)
   - Added `duration`, `position`, `isPlaying` getters
   - Tracks playback state for MediaItem

4. **VideoPlayerPage** (Lifecycle Handling)
   - Calls `MediaSyncService.switchToBackground()` on app pause/inactive
   - Calls `MediaSyncService.switchToForeground()` on app resume

## Flow

### Foreground Playback (App Open)

1. User plays video via `HlsVideoPlayer`
2. `HlsPlayerController` manages `video_player` + `chewie`
3. `MediaSyncService.setCurrentPlayer()` registers the active player
4. Video plays normally with full UI controls

### Background Transition (App Minimized)

1. App lifecycle changes to `paused` or `inactive`
2. `VideoPlayerPage.didChangeAppLifecycleState()` detects change
3. Calls `MediaSyncService.switchToBackground()`
4. Service:
   - Gets current position and duration from video player
   - Pauses video player (stops rendering)
   - Starts `audio_service` with HLS URL
   - Sets MediaItem (title, artist, artwork, duration)
   - Updates PlaybackState with controls
   - Resumes playback from same position

### Background Playback

- Audio continues via `just_audio` player
- Media controls appear in:
  - Android: Notification bar, lock screen
  - iOS: Control Center, lock screen
- User can play/pause/seek from system UI
- Position updates continuously

### Foreground Restore (App Resumed)

1. App lifecycle changes to `resumed`
2. `VideoPlayerPage.didChangeAppLifecycleState()` detects change
3. Calls `MediaSyncService.switchToForeground()`
4. Service:
   - Gets current position from audio handler
   - Stops audio service
   - Seeks video player to audio position
   - Resumes video playback
   - Video UI appears seamlessly

## MediaSession Implementation

### MediaItem (Required for Controls)

```dart
MediaItem(
  id: videoId,
  album: 'Hiffi',
  title: videoTitle,
  artist: userUsername,
  artUri: thumbnailUrl,
  duration: duration,
  playable: true,
)
```

**Critical**: MediaItem MUST be set before playback starts for controls to appear.

### PlaybackState (Required for Controls)

```dart
PlaybackState(
  controls: [MediaControl.play, MediaControl.pause, ...],
  systemActions: {MediaAction.seek, ...},
  processingState: AudioProcessingState.ready,
  playing: true,
  updatePosition: position,
  bufferedPosition: buffered,
  speed: 1.0,
  updateTime: DateTime.now(),
)
```

**Critical**: PlaybackState MUST be updated continuously with position for seek to work.

## Platform Configuration

### Android

**AndroidManifest.xml** (Already configured):
- `FOREGROUND_SERVICE` permission
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission
- `AudioService` service declaration
- `MediaButtonReceiver` for hardware buttons

**AudioServiceConfig**:
- `androidNotificationOngoing: true` - Persistent notification
- `androidStopForegroundOnPause: false` - Keep notification when paused
- Notification channel configured

### iOS

**Info.plist** (Already configured):
- `UIBackgroundModes` with `audio` entry
- Enables background audio playback

**AudioSession**:
- Configured as `AudioSessionConfiguration.music()`
- Allows background playback

## Key Features

✅ **Seamless Transitions**
- Video → Audio: Position preserved, no interruption
- Audio → Video: Position synced, video resumes smoothly

✅ **Media Controls**
- Play/Pause from notification/lock screen
- Seek forward/backward (10s intervals)
- Title, artist, artwork displayed
- Position updates in real-time

✅ **Battery Efficient**
- Video rendering stops in background
- Audio-only playback uses less resources
- Proper resource cleanup

✅ **OS Compliant**
- Uses platform-standard MediaSession
- Follows Android/iOS guidelines
- Store-policy safe

## Validation Checklist

- [x] MediaItem is set before playback starts
- [x] PlaybackState includes all required controls
- [x] Foreground service is persistent (ongoing: true)
- [x] Notification shows artwork & title
- [x] App restores video state correctly
- [x] Position syncs between video and audio
- [x] Seek works from system UI
- [x] Play/pause works from system UI

## Testing

### Test Scenarios

1. **Play video → Minimize app**
   - ✅ Video pauses
   - ✅ Audio continues
   - ✅ Notification appears with controls
   - ✅ Position preserved

2. **Control from notification**
   - ✅ Play/pause works
   - ✅ Seek works
   - ✅ Title/artwork visible

3. **Restore app**
   - ✅ Audio stops
   - ✅ Video resumes from same position
   - ✅ No interruption

4. **Lock screen controls**
   - ✅ Controls visible
   - ✅ Play/pause works
   - ✅ Seek works

## Troubleshooting

### Controls Don't Appear

**Cause**: MediaItem not set before playback
**Fix**: Ensure `mediaItem.add()` is called before `_player.play()`

### Seek Doesn't Work

**Cause**: PlaybackState not updating position
**Fix**: Ensure `updatePosition` is set in PlaybackState and updated continuously

### Audio Stops Unexpectedly

**Cause**: Background mode not configured
**Fix**: Verify `UIBackgroundModes` includes `audio` in Info.plist

### Position Not Syncing

**Cause**: Position not captured before transition
**Fix**: Ensure position is read from video player before starting audio

## Future Enhancements

- [ ] Queue support for autoplay next video
- [ ] Chromecast/AirPlay support
- [ ] Download for offline playback
- [ ] Playback speed control from notification
- [ ] Chapter markers support
