# Video and Thumbnail Endpoints & Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Video Upload Endpoints](#video-upload-endpoints)
3. [Thumbnail Upload Endpoints](#thumbnail-upload-endpoints)
4. [Video Retrieval Endpoints](#video-retrieval-endpoints)
5. [Upload Flow Architecture](#upload-flow-architecture)
6. [Implementation Details](#implementation-details)
7. [DigitalOcean Spaces Integration](#digitalocean-spaces-integration)
8. [File Handling](#file-handling)
9. [Error Handling & Retry Logic](#error-handling--retry-logic)
10. [Progress Tracking](#progress-tracking)

---

## Overview

The video and thumbnail upload system uses a **three-stage upload process**:

1. **Bridge Creation**: Create an upload bridge with the backend to receive signed gateway URLs
2. **File Upload**: Upload video and thumbnail files directly to DigitalOcean Spaces using signed URLs
3. **Acknowledgment**: Notify the backend that uploads are complete

This architecture allows for:
- Direct client-to-storage uploads (reduces backend load)
- Secure signed URLs with expiration
- Progress tracking during upload
- Retry logic for failed uploads
- Background upload support

---

## Video Upload Endpoints

### 1. Create Upload Bridge

**Endpoint**: `POST /videos/upload`

**Purpose**: Creates an upload bridge and returns signed URLs for direct file uploads to DigitalOcean Spaces.

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Request Headers**:
```
Authorization: Bearer <firebase_id_token>
Content-Type: application/json
Accept: application/json
```

**Request Body**:
```json
{
  "video_title": "string",
  "video_description": "string",
  "video_tags": ["string", "string"]
}
```

**Request Body Fields**:
- `video_title` (string, required): Title of the video
- `video_description` (string, required): Description of the video
- `video_tags` (array of strings, required): Tags associated with the video

**Response** (200 OK):
```json
{
  "bridge_id": "unique_bridge_identifier",
  "gateway_url": "https://blr1.digitaloceanspaces.com/dev.hiffi/path/to/video.mp4?X-Amz-Algorithm=...",
  "gateway_url_thumbnail": "https://blr1.digitaloceanspaces.com/dev.hiffi/path/to/thumbnail.jpg?X-Amz-Algorithm=..."
}
```

**Response Fields**:
- `bridge_id` (string, required): Unique identifier for this upload session
- `gateway_url` (string, required): Pre-signed PUT URL for video file upload
- `gateway_url_thumbnail` (string, optional): Pre-signed PUT URL for thumbnail upload

**Error Responses**:
- `400 Bad Request`: Invalid request body
  ```json
  {
    "error": "Invalid video title"
  }
  ```
- `401 Unauthorized`: Missing or invalid authentication token
  ```json
  {
    "error": "Authentication required"
  }
  ```
- `500 Internal Server Error`: Server error during bridge creation
  ```json
  {
    "error": "Failed to create upload bridge"
  }
  ```

**Implementation Notes**:
- The backend generates pre-signed URLs with expiration (typically 1 hour)
- The `bridge_id` must be used in the acknowledgment endpoint
- Both `gateway_url` and `gateway_url_thumbnail` are S3-compatible signed URLs

---

### 2. Upload Video File to Gateway

**Endpoint**: Direct upload to DigitalOcean Spaces (not via API)

**Purpose**: Upload video file directly to DigitalOcean Spaces using the signed URL from the bridge.

**Method**: `PUT`

**URL**: The `gateway_url` from the bridge response

**Authentication**: Not required (URL is pre-signed)

**Request Headers**:
```
Content-Type: video/mp4 (or appropriate MIME type)
Content-Length: <file_size_in_bytes>
x-amz-acl: public-read
```

**Request Body**: Binary video file data

**Supported Video Formats**:
- MP4 (video/mp4) - Default
- MOV (video/quicktime)
- MKV (video/x-matroska)
- WebM (video/webm)
- AVI (video/x-msvideo)

**Response** (200 OK):
```
Empty response body
```

**Response Headers**:
```
ETag: "<etag_value>"
Content-Length: 0
```

**Error Responses**:
- `400 Bad Request`: Invalid file or headers
- `403 Forbidden`: Signed URL expired or invalid
- `413 Payload Too Large`: File size exceeds limit
- `500 Internal Server Error`: Storage service error

**Implementation Details**:
- File is streamed in 64KB chunks
- Progress is reported via callback
- Automatic retry on connection errors (up to 3 attempts)
- Exponential backoff between retries

---

### 3. Upload Thumbnail File to Gateway

**Endpoint**: Direct upload to DigitalOcean Spaces (not via API)

**Purpose**: Upload thumbnail image directly to DigitalOcean Spaces using the signed URL from the bridge.

**Method**: `PUT`

**URL**: The `gateway_url_thumbnail` from the bridge response

**Authentication**: Not required (URL is pre-signed)

**Request Headers**:
```
Content-Type: image/jpeg
Content-Length: <file_size_in_bytes>
x-amz-acl: public-read
```

**Request Body**: Binary image file data (JPEG format)

**Supported Thumbnail Formats**:
- JPEG (image/jpeg) - Primary format
- PNG (image/png) - Supported but converted to JPEG

**Response** (200 OK):
```
Empty response body
```

**Response Headers**:
```
ETag: "<etag_value>"
Content-Length: 0
```

**Error Responses**:
- `400 Bad Request`: Invalid image file
- `403 Forbidden`: Signed URL expired or invalid
- `413 Payload Too Large`: File size exceeds limit
- `500 Internal Server Error`: Storage service error

**Implementation Notes**:
- Thumbnail upload is **non-critical** - upload continues even if thumbnail fails
- Auto-generated thumbnails are created from video at 2-second mark
- Custom thumbnails can be uploaded by the user
- Thumbnail is optional but recommended

---

### 4. Acknowledge Upload Completion

**Endpoint**: `POST /videos/upload/ack/{bridgeId}`

**Purpose**: Notifies the backend that video and thumbnail uploads are complete and ready for processing.

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `bridgeId` (string, required): The bridge ID from the upload bridge response

**Request Headers**:
```
Authorization: Bearer <firebase_id_token>
Content-Type: application/json
Accept: application/json
```

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Video uploaded successfully",
  "video_id": "unique_video_identifier",
  "video_url": "path/to/video.mp4",
  "video_thumbnail": "path/to/thumbnail.jpg"
}
```

**Response Fields**:
- `status` (string): "success" or "error"
- `message` (string): Human-readable message
- `video_id` (string, optional): Unique identifier for the uploaded video
- `video_url` (string, optional): Storage path to the video file
- `video_thumbnail` (string, optional): Storage path to the thumbnail

**Error Responses**:
- `400 Bad Request`: Invalid bridge ID or upload not completed
  ```json
  {
    "status": "error",
    "message": "Upload not completed or files missing"
  }
  ```
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: Bridge ID not found
  ```json
  {
    "status": "error",
    "message": "Upload bridge not found"
  }
  ```
- `500 Internal Server Error`: Server error during acknowledgment
  ```json
  {
    "status": "error",
    "message": "Failed to process upload acknowledgment"
  }
  ```

**Implementation Notes**:
- Must be called after both video and thumbnail uploads complete
- Backend validates that files exist in storage before acknowledging
- Video becomes available in the feed after successful acknowledgment
- If acknowledgment fails but video was uploaded, the upload is still considered successful to prevent duplicate uploads

---

## Thumbnail Upload Endpoints

### Thumbnail Generation

**Not an API Endpoint**: Thumbnail generation happens client-side using the `video_thumbnail` package.

**Process**:
1. User selects video file
2. Client extracts frame at 2 seconds using `VideoThumbnail.thumbnailFile()`
3. Thumbnail saved as JPEG in system temp directory
4. Thumbnail path stored for upload

**Thumbnail Specifications**:
- Format: JPEG
- Max Width: 1280px
- Quality: 75%
- Time Position: 2000ms (2 seconds)
- Output Path: System temp directory

**Custom Thumbnail Upload**:
- User can optionally upload a custom thumbnail image
- Custom thumbnail takes precedence over auto-generated
- Same upload process as auto-generated thumbnail

---

## Video Retrieval Endpoints

### 1. Get Video URL

**Endpoint**: `GET /{videoUrl}`

**Purpose**: Retrieves a signed URL for streaming a video file.

**Method**: `GET`

**Authentication**: Optional (Bearer token for authenticated users, works without auth for public videos)

**Path Parameters**:
- `videoUrl` (string, required): The `video_url` field from the video model (e.g., "videos/abc123/video.mp4")

**Request Headers** (Optional):
```
Authorization: Bearer <firebase_id_token>
Accept: application/json
```

**Response** (200 OK):
```json
{
  "video_url": "https://blr1.digitaloceanspaces.com/dev.hiffi/videos/abc123/video.mp4?X-Amz-Algorithm=..."
}
```

**Response Fields**:
- `video_url` (string, required): Pre-signed GET URL for video streaming

**Error Responses**:
- `404 Not Found`: Video not found
  ```json
  {
    "error": "Video not found"
  }
  ```
- `403 Forbidden`: Access denied (for private videos)
  ```json
  {
    "error": "Access denied"
  }
  ```
- `500 Internal Server Error`: Server error
  ```json
  {
    "error": "Failed to generate video URL"
  }
  ```

**Implementation Notes**:
- Signed URLs typically expire after 1 hour
- URLs are regenerated on each request
- Supports progressive download/streaming
- Works for both authenticated and unauthenticated users

---

### 2. Get Video List (Including Thumbnails)

**Endpoint**: `POST /videos/list`

**Purpose**: Retrieves a paginated list of videos with metadata including thumbnail URLs.

**Method**: `POST`

**Authentication**: Not required (optional for personalized results)

**Request Body**:
```json
{
  "page": 1,
  "limit": 10,
  "search": "optional_search_query"
}
```

**Response** (200 OK):
```json
{
  "videos": [
    {
      "video_id": "string",
      "video_url": "path/to/video.mp4",
      "video_thumbnail": "path/to/thumbnail.jpg",
      "video_title": "string",
      "video_description": "string",
      "video_tags": ["string"],
      "video_views": 0,
      "video_upvotes": 0,
      "video_downvotes": 0,
      "video_comments": 0,
      "user_uid": "string",
      "user_username": "string",
      "created_at": "ISO8601 datetime",
      "updated_at": "ISO8601 datetime",
      "user_vote_status": "upvoted" | "downvoted" | null
    }
  ]
}
```

**Thumbnail URL Construction**:
The `video_thumbnail` field contains the storage path. The full URL is constructed as:
```
https://blr1.digitaloceanspaces.com/dev.hiffi/{video_thumbnail}
```

**Example**:
- `video_thumbnail`: "thumbnails/abc123/thumb.jpg"
- Full URL: `https://blr1.digitaloceanspaces.com/dev.hiffi/thumbnails/abc123/thumb.jpg`

---

## Upload Flow Architecture

### Complete Upload Sequence

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 1. POST /videos/upload
       │    {title, description, tags}
       │
       ▼
┌─────────────┐
│   Backend   │
└──────┬──────┘
       │
       │ 2. Generate signed URLs
       │    Return: bridge_id, gateway_url, gateway_url_thumbnail
       │
       ▼
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ 3. PUT gateway_url (video file)
       │    Stream video in 64KB chunks
       │    Report progress
       │
       ▼
┌─────────────────────┐
│ DigitalOcean Spaces │
└──────┬──────────────┘
       │
       │ 4. PUT gateway_url_thumbnail (thumbnail file)
       │    Upload thumbnail (optional, non-critical)
       │
       ▼
┌─────────────────────┐
│ DigitalOcean Spaces │
└──────┬──────────────┘
       │
       │ 5. POST /videos/upload/ack/{bridgeId}
       │    Notify backend of completion
       │
       ▼
┌─────────────┐
│   Backend   │
└──────┬──────┘
       │
       │ 6. Validate files exist
       │    Process video metadata
       │    Make video available in feed
       │
       ▼
┌─────────────┐
│   Client    │
└─────────────┘
```

### Upload Stages

1. **Preparing** (`VideoUploadStage.preparing`)
   - Creating upload bridge
   - Receiving signed URLs
   - Validating response

2. **Uploading Video** (`VideoUploadStage.uploadingVideo`)
   - Streaming video file to DigitalOcean Spaces
   - Progress tracking (bytes sent/total)
   - Retry logic on failures

3. **Uploading Thumbnail** (`VideoUploadStage.uploadingThumbnail`)
   - Uploading thumbnail image (optional)
   - Non-critical (upload continues if fails)

4. **Acknowledging** (`VideoUploadStage.acknowledging`)
   - Notifying backend of completion
   - Receiving video ID and paths
   - Final validation

---

## Implementation Details

### Video Upload Service

**Location**: `lib/features/upload/domain/services/video_upload_service.dart`

**Key Methods**:

#### `uploadVideo()`
Main orchestration method for the upload process.

```dart
Future<VideoUploadResult> uploadVideo(
  VideoUploadPayload payload, {
  VideoUploadStageCallback? onStage,
  VideoUploadProgressCallback? onVideoProgress,
})
```

**Parameters**:
- `payload`: Contains video path, thumbnail path, metadata, and auth token
- `onStage`: Callback for stage changes (preparing, uploadingVideo, etc.)
- `onVideoProgress`: Callback for video upload progress (bytes sent/total)

**Returns**: `VideoUploadResult` with success status and message

**Process**:
1. Call `onStage(VideoUploadStage.preparing)`
2. POST to `/videos/upload` to create bridge
3. Extract `gateway_url`, `gateway_url_thumbnail`, `bridge_id`
4. Call `onStage(VideoUploadStage.uploadingVideo)`
5. Upload video file using `uploadFileToGateway()`
6. If thumbnail exists, call `onStage(VideoUploadStage.uploadingThumbnail)`
7. Upload thumbnail using `uploadFileToGateway()`
8. Call `onStage(VideoUploadStage.acknowledging)`
9. POST to `/videos/upload/ack/{bridgeId}`
10. Return success result

#### `_detectVideoMimeType()`
Detects MIME type from file extension.

```dart
String _detectVideoMimeType(String path)
```

**Supported Formats**:
- `.mp4` → `video/mp4` (default)
- `.mov` → `video/quicktime`
- `.mkv` → `video/x-matroska`
- `.webm` → `video/webm`
- `.avi` → `video/x-msvideo`

---

### API Client Upload Method

**Location**: `lib/core/services/api_client.dart`

**Key Method**:

#### `uploadFileToGateway()`
Handles direct file uploads to DigitalOcean Spaces.

```dart
Future<http.StreamedResponse> uploadFileToGateway(
  String gatewayUrl,
  File file, {
  String? contentType,
  void Function(int sent, int total)? onProgress,
  int maxRetries = 3,
})
```

**Parameters**:
- `gatewayUrl`: Pre-signed PUT URL from bridge
- `file`: File to upload
- `contentType`: MIME type (e.g., "video/mp4", "image/jpeg")
- `onProgress`: Progress callback (sent bytes, total bytes)
- `maxRetries`: Maximum retry attempts (default: 3)

**Returns**: `StreamedResponse` from the storage service

**Features**:
- Automatic retry on connection errors
- Exponential backoff between retries
- Progress tracking via callbacks
- Chunked streaming (64KB chunks)
- SSL/TLS error handling
- Connection reset detection

#### `_performUpload()`
Internal method that performs the actual upload.

**Process**:
1. Parse gateway URL
2. Create PUT request with headers:
   - `Content-Type`: MIME type
   - `Content-Length`: File size
   - `x-amz-acl`: "public-read"
3. Open file for reading
4. Stream file in 64KB chunks
5. Report progress after each chunk
6. Close request sink
7. Wait for response (5-minute timeout)
8. Return response

**Chunk Size**: 64KB (64 * 1024 bytes)

**Progress Reporting**: Called after each chunk is sent

---

## DigitalOcean Spaces Integration

### Storage Configuration

**Region**: `blr1` (Bangalore)

**Bucket**: `dev.hiffi`

**Access Type**: Public read, authenticated write

### URL Structure

**Base URL**:
```
https://blr1.digitaloceanspaces.com/dev.hiffi/
```

**Video Path Pattern**:
```
videos/{video_id}/{filename}.mp4
```

**Thumbnail Path Pattern**:
```
thumbnails/{video_id}/{filename}.jpg
```

### Signed URL Format

**PUT URLs** (for uploads):
```
https://blr1.digitaloceanspaces.com/dev.hiffi/path/to/file?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=3600&X-Amz-SignedHeaders=host%3Bx-amz-acl&X-Amz-Signature=...
```

**GET URLs** (for streaming):
```
https://blr1.digitaloceanspaces.com/dev.hiffi/path/to/file?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&X-Amz-Signature=...
```

### Required Headers for Upload

**PUT Request Headers**:
```
Content-Type: <mime_type>
Content-Length: <file_size>
x-amz-acl: public-read
```

**Note**: The `x-amz-acl` header is required because it's included in the signed headers list (`X-Amz-SignedHeaders`).

---

## File Handling

### Video File Processing

**File Selection**:
- User selects video via `FilePicker`
- File path stored in `VideoUploadPayload`
- File validated before upload

**File Validation**:
- File existence check
- File size validation (implicit via upload)
- Format validation (via MIME type detection)

**File Streaming**:
- Files are streamed, not loaded into memory
- 64KB chunk size for efficient memory usage
- Random access file (`RandomAccessFile`) for reading

### Thumbnail File Processing

**Auto-Generation**:
```dart
final thumbnailPath = await VideoThumbnail.thumbnailFile(
  video: videoPath,
  thumbnailPath: Directory.systemTemp.path,
  imageFormat: ImageFormat.JPEG,
  maxWidth: 1280,
  quality: 75,
  timeMs: 2000, // 2 seconds
);
```

**Custom Thumbnail**:
- User selects image via `FilePicker`
- Validated as image file
- Stored alongside video path

**Thumbnail Resolution**:
- Custom thumbnail takes precedence
- Falls back to auto-generated if custom not provided
- Falls back to placeholder if both unavailable

### File Path Resolution

**Priority Order**:
1. Custom thumbnail path (if provided)
2. Auto-generated thumbnail path (if available)
3. Null (no thumbnail)

**Implementation**:
```dart
String? get resolvedThumbnailPath => 
  customThumbnailPath ?? autoThumbnailPath;
```

---

## Error Handling & Retry Logic

### Retry Strategy

**Automatic Retries**: Up to 3 attempts with exponential backoff

**Retry Conditions**:
- SSL/TLS handshake errors
- Connection reset errors
- Socket exceptions
- HTTP client exceptions

**Backoff Strategy**:
```dart
await Future.delayed(Duration(seconds: attempt * 2));
```
- Attempt 1: Immediate
- Attempt 2: 2 seconds delay
- Attempt 3: 4 seconds delay

### Error Types Handled

#### 1. HandshakeException
SSL/TLS certificate validation errors.

**Handling**: Retry with custom certificate validation (development only)

#### 2. SocketException
Network connection errors.

**Handling**: 
- Check for "Connection reset" message
- Retry if connection reset detected
- Re-throw other socket errors

#### 3. ClientException
HTTP client-level errors.

**Handling**:
- Check for connection reset
- Retry on connection reset
- Re-throw other errors

#### 4. TimeoutException
Upload response timeout (5 minutes).

**Handling**: Re-throw (no retry for timeouts)

### Error Response Handling

**Video Upload Failures**:
- Return `VideoUploadResult` with `success: false`
- Include error message for user display
- Log error details for debugging

**Thumbnail Upload Failures**:
- Log error but continue upload
- Don't fail entire upload process
- User can retry thumbnail later if needed

**Acknowledgment Failures**:
- If video was uploaded, treat as success to prevent duplicates
- Log acknowledgment failure
- User can manually verify upload

---

## Progress Tracking

### Progress Callbacks

**Video Upload Progress**:
```dart
void Function(int sentBytes, int totalBytes) onVideoProgress
```

**Stage Progress**:
```dart
Future<void> Function(VideoUploadStage stage) onStage
```

### Progress Calculation

**Percentage Calculation**:
```dart
final percent = total > 0
    ? ((sent / total) * 100).clamp(0, 100).toInt()
    : 0;
```

**Progress Updates**:
- Called after each 64KB chunk is sent
- Updates UI in real-time
- Used for progress bars and notifications

### Progress Notification

**In-App Notifications**:
- SnackBar with progress percentage
- Progress bar visualization
- Upload status text

**Local Notifications** (Background):
- Progress percentage in notification
- Ongoing notification with progress
- Updated every 10% progress

**Progress Stages**:
1. **0%**: Preparing upload
2. **0-90%**: Uploading video file
3. **90-95%**: Uploading thumbnail (if provided)
4. **95-100%**: Acknowledging upload
5. **100%**: Upload complete

---

## Background Upload Support

### WorkManager Integration

**Task Registration**:
```dart
await Workmanager().registerOneOffTask(
  taskId,
  videoUploadTaskName,
  existingWorkPolicy: ExistingWorkPolicy.replace,
  constraints: Constraints(networkType: NetworkType.connected),
  inputData: payload.toMap(),
);
```

**Background Worker**:
- Location: `lib/core/workers/video_upload_worker.dart`
- Handles uploads when app is terminated
- Uses same upload service as foreground
- Sends results back to main isolate

### Network Connectivity

**Monitoring**:
- Real-time network status tracking
- Automatic upload cancellation on connection loss
- User notification for network errors

**Connectivity Check**:
```dart
final connectivity = Connectivity();
final results = await connectivity.checkConnectivity();
final hasConnection = results.any(
  (result) =>
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn,
);
```

---

## Best Practices

### Upload Optimization

1. **Chunk Size**: 64KB provides good balance between memory usage and network efficiency
2. **Progress Updates**: Update UI every 10% to avoid excessive rebuilds
3. **Error Handling**: Always provide user-friendly error messages
4. **Retry Logic**: Use exponential backoff to avoid overwhelming the server
5. **Background Support**: Always register WorkManager task as backup

### Security Considerations

1. **Signed URLs**: Always use pre-signed URLs with expiration
2. **Token Refresh**: Automatically refresh tokens on 401 errors
3. **File Validation**: Validate file types and sizes before upload
4. **Error Messages**: Don't expose sensitive information in error messages

### Performance Tips

1. **Streaming**: Always stream large files, never load into memory
2. **Progress**: Use callbacks to update UI without blocking upload
3. **Thumbnails**: Generate thumbnails asynchronously
4. **Caching**: Cache resolved video URLs to reduce API calls

---

## Testing Considerations

### Unit Tests

- Test MIME type detection for all formats
- Test error handling and retry logic
- Test progress calculation
- Test file path resolution

### Integration Tests

- Test complete upload flow
- Test retry on connection errors
- Test background upload continuation
- Test acknowledgment flow

### Manual Testing

- Test with various video formats
- Test with large files (>100MB)
- Test with poor network conditions
- Test app termination during upload
- Test thumbnail generation and upload

---

## Troubleshooting

### Common Issues

#### 1. Upload Fails with 403 Forbidden
**Cause**: Signed URL expired or invalid

**Solution**: 
- Check URL expiration time
- Regenerate bridge if URL expired
- Verify `x-amz-acl` header is included

#### 2. Upload Progress Stuck
**Cause**: Network connection lost or slow

**Solution**:
- Check network connectivity
- Verify retry logic is working
- Check for timeout errors

#### 3. Thumbnail Upload Fails
**Cause**: Invalid image format or size

**Solution**:
- Verify image is valid JPEG
- Check file size limits
- Regenerate thumbnail if needed

#### 4. Acknowledgment Fails After Upload
**Cause**: Backend validation failed or files not found

**Solution**:
- Verify files exist in storage
- Check bridge ID is correct
- Verify token is still valid

---

## Conclusion

The video and thumbnail upload system provides a robust, scalable solution for handling large file uploads with progress tracking, error handling, and background support. The three-stage process (bridge creation, file upload, acknowledgment) ensures reliability while maintaining good user experience through real-time progress updates and automatic retry logic.

