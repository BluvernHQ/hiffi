# HLS Video Player Implementation - Flutter

This document explains the HLS video player implementation in the Flutter app, mirroring the Next.js VideoJS implementation.

## Overview

The Flutter HLS player follows the same flow as the Next.js implementation:
1. **API Call** → Get video metadata and Workers base URL
2. **URL Resolution** → Convert base URL to HLS manifest URL
3. **Player Initialization** → Load HLS manifest with authentication
4. **Streaming** → Play video with adaptive bitrate support

## Implementation Status

✅ **Implemented correctly** - Matches Next.js architecture

### Flow Comparison

| Step | Next.js | Flutter | Status |
|------|---------|---------|--------|
| API Call | `apiClient.getVideo(videoId)` | `videoRepository.getVideoInfo(videoId)` | ✅ Same |
| Extract URL | `videoResponse.video_url` | `videoInfo.videoUrl` | ✅ Same |
| Resolve HLS | `resolveVideoSource()` → append `/hls/master.m3u8` | `HlsSourceResolver.resolveHlsUrl()` → append `/hls/master.m3u8` | ✅ Same |
| Auth Headers | XHR hooks inject `x-api-key` | `httpHeaders: {'x-api-key': ...}` | ⚠️ iOS limitation |
| Player Init | VideoJS with HLS source | `video_player` with `.m3u8` URL | ✅ Same |
| Quality Selection | `profiles.json` | `profiles.json` | ✅ Same |

## Architecture

### File Structure

```
lib/
├── core/
│   └── services/
│       └── hls_source_resolver.dart    # URL resolution (like video-resolver.ts)
├── features/
│   └── video/
│       ├── presentation/
│       │   ├── controllers/
│       │   │   └── hls_player_controller.dart  # Player lifecycle & state
│       │   ├── widgets/
│       │   │   └── hls_video_player.dart       # UI component
│       │   └── views/
│       │       └── video_player_page.dart      # Main video page
│       └── domain/
│           └── models/
│               └── video_profile.dart          # Quality profile model
```

### Key Components

#### 1. HlsSourceResolver
**File**: `lib/core/services/hls_source_resolver.dart`

Mirrors Next.js `lib/video-resolver.ts`:

```dart
String resolveHlsUrl(String baseVideoUrl) {
  // Input: "https://...workers.dev/videos/{videoId}"
  // Output: "https://...workers.dev/videos/{videoId}/hls/master.m3u8"
  return '$cleanUrl/hls/master.m3u8';
}
```

#### 2. HlsPlayerController
**File**: `lib/features/video/presentation/controllers/hls_player_controller.dart`

Handles:
- Video player initialization
- Authentication header injection
- Profile fetching (`profiles.json`)
- Quality selection
- State management (volume, mute, position)
- Error handling

#### 3. HlsVideoPlayer Widget
**File**: `lib/features/video/presentation/widgets/hls_video_player.dart`

UI component that:
- Uses `Chewie` for player controls (like VideoJS UI)
- Displays loading/error states
- Handles player lifecycle

## Step-by-Step Flow

### Step 1: Get Video Metadata

**Next.js**: `app/watch/[videoId]/page.tsx`
```typescript
videoResponse = await apiClient.getVideo(videoId)
const videoUrl = videoResponse.video_url  // Workers base URL
```

**Flutter**: `lib/features/video/presentation/views/video_player_page.dart`
```dart
final videoInfo = await videoRepository.getVideoInfo(videoId);
_videoUrlFromApi = videoInfo.videoUrl;  // Workers base URL
```

Both return: `https://black-paper-83cf.hiffi.workers.dev/videos/{videoId}`

### Step 2: Resolve HLS URL

**Next.js**: `lib/video-resolver.ts`
```typescript
const hlsUrl = `${processedUrl}/hls/master.m3u8`
```

**Flutter**: `lib/core/services/hls_source_resolver.dart`
```dart
String resolveHlsUrl(String baseVideoUrl) {
  return '$cleanUrl/hls/master.m3u8';
}
```

Both append `/hls/master.m3u8` to the base URL.

### Step 3: Initialize Player

**Next.js**: Uses VideoJS with XHR hooks
```typescript
player.src({
  src: signedVideoUrl,  // HLS manifest URL
  type: "application/x-mpegURL"
})

// XHR hooks inject x-api-key header
options.headers["x-api-key"] = apiKey
```

**Flutter**: Uses video_player package
```dart
_videoPlayerController = VideoPlayerController.networkUrl(
  Uri.parse(hlsUrl),
  httpHeaders: {'x-api-key': ImageUtils.profileImageApiKey},
)
```

### Step 4: Fetch Quality Profiles

**Next.js**: `components/video/video-player.tsx`
```typescript
const profilesUrl = signedVideoUrl.replace(/master\.m3u8$/, "profiles.json")
const response = await fetch(profilesUrl, { headers: { "x-api-key": apiKey } })
```

**Flutter**: `lib/features/video/presentation/controllers/hls_player_controller.dart`
```dart
final profilesUrl = _resolver.resolveProfilesUrl(baseVideoUrl);
final response = await http.get(
  Uri.parse(profilesUrl),
  headers: {'x-api-key': ImageUtils.profileImageApiKey},
);
```

## Platform Differences

### Android
✅ **Fully Working**
- `video_player` uses ExoPlayer
- Headers are forwarded to all requests (master, variants, segments)
- Matches Next.js behavior

### iOS
⚠️ **Known Limitation**
- `video_player` uses AVPlayer
- Headers are ONLY sent to the master playlist request
- Headers are NOT forwarded to variant playlists or segments
- This causes 401/404 errors if backend requires auth for all requests

**Why**: AVPlayer is a native iOS framework that doesn't allow intercepting/modifying segment requests at the Flutter level.

**Next.js Comparison**: VideoJS runs in browser and uses JavaScript XHR hooks, which can intercept ALL requests. Flutter can't do this on iOS.

## Solutions

### Option 1: Backend Change (Recommended)
Modify the backend to:
- Require authentication ONLY for the master playlist
- Allow unauthenticated access to variant playlists and segments
- This matches how many CDNs handle HLS authentication

### Option 2: Query Parameters
Modify backend to accept authentication via query parameter:
```
/hls/master.m3u8?api_key=SECRET_KEY
```
Then embed the key in all URLs (master, variants, segments).

### Option 3: Alternative Player Package
Use `hls_proplayer` or similar package that supports header forwarding on iOS. However, these packages are less mature and may have other issues.

## Current Implementation Status

✅ **Correctly Implemented**:
- URL resolution logic matches Next.js
- Authentication headers injected (works on Android, iOS master only)
- Profile fetching and quality selection
- Error handling and retry logic
- Clean architecture with separation of concerns

⚠️ **Platform Limitation**:
- iOS header forwarding limitation (backend change needed)

## Testing

To verify the implementation:
1. Test on Android - should work fully
2. Test on iOS - will fail if backend requires auth for variants/segments
3. Check logs for: `HLS Player: Loading HLS URL: ...`

## Next Steps

1. **Backend team**: Update Workers to allow unauthenticated access to variant playlists and segments
2. **OR**: Implement query parameter authentication
3. **OR**: Accept iOS limitation and use authenticated master + unauthenticated variants/segments

