# Hiffi Streaming Platform - Complete Documentation

## Table of Contents
1. [Platform Overview](#platform-overview)
2. [Architecture & Tech Stack](#architecture--tech-stack)
3. [Core Features](#core-features)
4. [API Documentation](#api-documentation)
5. [Application Structure](#application-structure)
6. [User Flows](#user-flows)
7. [Technical Implementation Details](#technical-implementation-details)

---

## Platform Overview

**Hiffi** is a modern video streaming platform built with Flutter, designed for mobile devices (iOS and Android). The platform enables users to upload, discover, watch, and interact with video content. It features a social media-like experience with user profiles, following capabilities, comments, voting, and real-time video streaming.

### Key Characteristics
- **Video-First Platform**: Focus on video content consumption and creation
- **Social Features**: User profiles, following, comments, and engagement metrics
- **Real-Time Streaming**: Progressive video playback with adaptive buffering
- **Background Uploads**: WorkManager-based background video uploads
- **Cross-Platform**: Native iOS and Android support via Flutter

---

## Architecture & Tech Stack

### Frontend Framework
- **Flutter**: Cross-platform mobile framework
- **Dart**: Programming language

### State Management
- **Provider**: Dependency injection and state management
- **ChangeNotifier**: Reactive state updates

### Navigation
- **GoRouter**: Declarative routing with authentication guards

### Authentication
- **Firebase Authentication**: Email/password authentication
- **Firebase ID Tokens**: Bearer token authentication for API calls

### Backend Integration
- **RESTful API**: Base URL: `https://hiffi.alterwork.in/api`
- **HTTP Client**: Custom `ApiClient` with automatic token refresh
- **DigitalOcean Spaces**: Video and thumbnail storage

### Background Processing
- **WorkManager**: Background video upload tasks
- **Isolate Communication**: Main isolate to background worker messaging

### Video Processing
- **video_player**: Core video playback
- **chewie**: Enhanced video player UI
- **video_thumbnail**: Automatic thumbnail generation

### Storage
- **SharedPreferences**: Local token storage
- **File System**: Temporary video and thumbnail files

### Notifications
- **flutter_local_notifications**: Local push notifications
- **In-App Notifications**: SnackBar-based notifications

### Network
- **connectivity_plus**: Network connectivity monitoring
- **http**: HTTP client for API calls

---

## Core Features

### 1. Authentication System

#### Sign Up Flow
1. User enters: name, username, email, password
2. Real-time username availability checking (debounced 500ms)
3. Firebase account creation
4. Backend user profile creation
5. Automatic sign-out and redirect to sign-in

#### Sign In Flow
1. Email and password authentication
2. Firebase token retrieval
3. Token storage in SharedPreferences
4. User profile fetching
5. Navigation to home feed

#### Sign Out
- Firebase sign out
- Token deletion from SharedPreferences
- Navigation to login page

### 2. Home Feed

#### Features
- **Video Grid Layout**: 2-column responsive grid with thumbnails
- **Infinite Scroll**: Paginated video loading (10 videos per page)
- **Pull-to-Refresh**: Refresh video feed
- **Search Functionality**:
  - Real-time search suggestions (5 results)
  - Full search with pagination
  - Twitch-like search overlay
  - Highlighted search terms in results
- **User Profile Section**: Compact profile card with avatar, name, username
- **Upload Button**: Quick access to video upload
- **Sign In Prompt**: For unauthenticated users

#### Video Card Display
- Thumbnail (16:9 aspect ratio)
- Video title (2 lines max)
- Creator username with avatar
- View count overlay
- Responsive sizing based on screen dimensions

### 3. Video Upload

#### Upload Flow
1. **Video Selection**: File picker for video files
2. **Automatic Thumbnail Generation**: Extracts frame at 2 seconds
3. **Custom Thumbnail Option**: User can upload custom thumbnail
4. **Metadata Entry**:
   - Title (required)
   - Description (required)
   - Tags (multiple, required)
5. **Upload Process**:
   - Foreground upload with progress tracking
   - WorkManager backup for background continuation
   - Network connectivity checks
   - Progress notifications (in-app and local)
6. **Upload Stages**:
   - Preparing upload
   - Uploading video file
   - Uploading thumbnail
   - Acknowledging completion

#### Background Upload Support
- WorkManager integration for app termination scenarios
- Network connectivity monitoring
- Automatic retry on connection loss
- Progress tracking via notifications

### 4. Video Player

#### Features
- **Full-Screen Player**: 16:9 aspect ratio
- **Progressive Playback**: Starts playing while buffering
- **Player Controls**: Play, pause, seek, volume, fullscreen
- **Video Metadata**:
  - Title and description (expandable)
  - View count and upload date
  - Tags (clickable)
- **Engagement Actions**:
  - Upvote/Downvote (authenticated users only)
  - Share dialog
  - Follow creator button
- **Creator Section**: Avatar, username, follow button
- **Comments Section**:
  - Comment list with pagination
  - Post comment functionality
  - Reply to comments
  - Expandable replies
  - Sign-in prompt for unauthenticated users

#### Video URL Resolution
- API call to get signed video URL
- Optional authentication (works for both authenticated and unauthenticated users)
- Progressive download support

### 5. User Profiles

#### Profile Display
- **Avatar**: Profile picture or generated initial
- **Live Status Indicator**: Red badge for live streams
- **Statistics**: Followers, Following, Streams, Videos
- **User Information**:
  - Username (editable for own profile)
  - Name (editable for own profile)
  - Email (read-only)
  - Bio (read-only)
  - Role (read-only)
  - Member since date

#### Profile Actions
- **Follow/Unfollow**: For other users' profiles
- **Edit Profile**: Username and name editing (own profile only)
- **Delete Account**: Account deletion with confirmation (own profile only)
- **Username Availability**: Real-time checking during editing

### 6. Search System

#### Search Features
- **Real-Time Suggestions**: As-you-type suggestions (debounced)
- **Search Overlay**: Twitch-style dropdown with results
- **Result Highlighting**: Matched terms highlighted in orange
- **Full Search**: Complete search with pagination
- **Search Indicators**: Visual feedback for active searches

### 7. Social Features

#### Following System
- Follow/unfollow users
- Follow status tracking
- Follower/following counts
- Follow button in video player and profiles

#### Engagement Metrics
- Video views
- Upvotes/downvotes
- Comment counts
- User vote status tracking

### 8. Comments System

#### Features
- **Comment Threading**: Comments with nested replies
- **Pagination**: 20 comments per page
- **Real-Time Updates**: Comments refresh after posting
- **Reply System**: Expandable replies per comment
- **User Attribution**: Username and avatar display
- **Timestamps**: Relative time display (e.g., "2h ago")

---

## API Documentation

### Base URL
```
https://hiffi.alterwork.in/api
```

### Authentication
Most endpoints require Bearer token authentication using Firebase ID tokens:
```
Authorization: Bearer <firebase_id_token>
```

The token is automatically refreshed on 401 responses.

---

### User Endpoints

#### 1. Check Username Availability
**Endpoint**: `GET /users/availability/{username}`

**Method**: `GET`

**Authentication**: Not required

**Path Parameters**:
- `username` (string, required): Username to check

**Response** (200 OK):
```json
{
  "available": true
}
```

**Error Responses**:
- `200 OK` with `"available": false` - Username is taken
- `500 Internal Server Error` - Server error

---

#### 2. Create User
**Endpoint**: `POST /users/create`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Request Body**:
```json
{
  "username": "string",
  "name": "string"
}
```

**Response** (200 OK):
```json
{
  "username": "string",
  "name": "string",
  "email": "string",
  "bio": "string",
  "avatarUrl": "string",
  "profile_picture": "string",
  "DocID": "string",
  "uid": "string",
  "created_at": "ISO8601 datetime",
  "updated_at": "ISO8601 datetime",
  "role": "string",
  "followers": 0,
  "following": 0,
  "total_streams": 0,
  "total_videos": 0,
  "status": {
    "is_live": false,
    "session_id": "string"
  },
  "is_following": false
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `400 Bad Request` - Invalid input data
- `409 Conflict` - Username already exists

---

#### 3. Get Current User
**Endpoint**: `GET /users/self`

**Method**: `GET`

**Authentication**: Required (Bearer token)

**Response** (200 OK):
```json
{
  "success": true,
  "user": {
    "username": "string",
    "name": "string",
    "email": "string",
    "bio": "string",
    "avatarUrl": "string",
    "profile_picture": "string",
    "DocID": "string",
    "uid": "string",
    "created_at": "ISO8601 datetime",
    "updated_at": "ISO8601 datetime",
    "role": "string",
    "followers": 0,
    "following": 0,
    "total_streams": 0,
    "total_videos": 0,
    "status": {
      "is_live": false,
      "session_id": "string"
    },
    "is_following": false
  }
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - User not found

---

#### 4. Get User by Username
**Endpoint**: `GET /users/{username}`

**Method**: `GET`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `username` (string, required): Username to fetch

**Response** (200 OK):
```json
{
  "username": "string",
  "name": "string",
  "email": "string",
  "bio": "string",
  "avatarUrl": "string",
  "profile_picture": "string",
  "DocID": "string",
  "uid": "string",
  "created_at": "ISO8601 datetime",
  "updated_at": "ISO8601 datetime",
  "role": "string",
  "followers": 0,
  "following": 0,
  "total_streams": 0,
  "total_videos": 0,
  "status": {
    "is_live": false,
    "session_id": "string"
  },
  "is_following": false
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - User not found

---

#### 5. Update User
**Endpoint**: `PUT /users/{username}`

**Method**: `PUT`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `username` (string, required): Current username

**Request Body**:
```json
{
  "name": "string",
  "username": "string"
}
```

**Note**: Both fields are optional. Only include fields to update.

**Response** (200 OK):
```json
{
  "username": "string",
  "name": "string",
  "email": "string",
  "bio": "string",
  "avatarUrl": "string",
  "profile_picture": "string",
  "DocID": "string",
  "uid": "string",
  "created_at": "ISO8601 datetime",
  "updated_at": "ISO8601 datetime",
  "role": "string",
  "followers": 0,
  "following": 0,
  "total_streams": 0,
  "total_videos": 0,
  "status": {
    "is_live": false,
    "session_id": "string"
  },
  "is_following": false
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `400 Bad Request` - Invalid input or username taken
- `404 Not Found` - User not found
- `403 Forbidden` - Not authorized to update this user

---

#### 6. Delete User
**Endpoint**: `DELETE /users/{username}`

**Method**: `DELETE`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `username` (string, required): Username to delete

**Response** (200 OK or 204 No Content):
Empty response body

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - User not found
- `403 Forbidden` - Not authorized to delete this user

---

### Video Endpoints

#### 7. Upload Video (Create Upload Bridge)
**Endpoint**: `POST /videos/upload`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Request Body**:
```json
{
  "video_title": "string",
  "video_description": "string",
  "video_tags": ["string"]
}
```

**Response** (200 OK):
```json
{
  "bridge_id": "string",
  "gateway_url": "string",
  "gateway_url_thumbnail": "string"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `400 Bad Request` - Invalid input data

**Note**: After receiving gateway URLs, upload video and thumbnail files to the provided URLs using PUT requests with binary data.

---

#### 8. Upload Video Acknowledgment
**Endpoint**: `POST /videos/upload/ack/{bridgeId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `bridgeId` (string, required): Bridge ID from upload response

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Video uploaded successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Bridge ID not found
- `400 Bad Request` - Upload not completed

---

#### 9. Get Video List
**Endpoint**: `POST /videos/list`

**Method**: `POST`

**Authentication**: Not required (optional for personalized results)

**Request Body**:
```json
{
  "page": 1,
  "limit": 10,
  "search": "string"
}
```

**Request Body Fields**:
- `page` (integer, required): Page number (1-indexed)
- `limit` (integer, required): Number of videos per page
- `search` (string, optional): Search query

**Response** (200 OK):
```json
{
  "videos": [
    {
      "video_id": "string",
      "video_url": "string",
      "video_thumbnail": "string",
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

**Error Responses**:
- `400 Bad Request` - Invalid pagination parameters
- `500 Internal Server Error` - Server error

---

#### 10. Get Video URL
**Endpoint**: `GET /{videoUrl}`

**Method**: `GET`

**Authentication**: Optional (Bearer token for authenticated users)

**Path Parameters**:
- `videoUrl` (string, required): Video URL path from video model

**Response** (200 OK):
```json
{
  "video_url": "string"
}
```

**Error Responses**:
- `404 Not Found` - Video not found
- `403 Forbidden` - Access denied (if authentication required)

**Note**: Returns a signed URL for video streaming. The `videoUrl` parameter is the `video_url` field from the video model.

---

### Social Endpoints

#### 11. Upvote Video
**Endpoint**: `POST /social/videos/upvote/{videoId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `videoId` (string, required): Video ID to upvote

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Video upvoted successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Video not found
- `400 Bad Request` - Already upvoted or invalid state

---

#### 12. Downvote Video
**Endpoint**: `POST /social/videos/downvote/{videoId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `videoId` (string, required): Video ID to downvote

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Video downvoted successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Video not found
- `400 Bad Request` - Already downvoted or invalid state

---

#### 13. Post Comment
**Endpoint**: `POST /social/videos/comment/{videoId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `videoId` (string, required): Video ID to comment on

**Request Body**:
```json
{
  "comment": "string"
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Comment posted successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Video not found
- `400 Bad Request` - Invalid comment data

---

#### 14. Get Comments
**Endpoint**: `POST /social/videos/comments/{videoId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `videoId` (string, required): Video ID to get comments for

**Request Body**:
```json
{
  "page": 1,
  "limit": 20
}
```

**Response** (200 OK):
```json
{
  "comments": [
    {
      "comment_id": "string",
      "commented_by": "string",
      "comment_by_username": "string",
      "commented_to": "string",
      "commented_at": "ISO8601 datetime",
      "comment": "string",
      "total_replies": 0
    }
  ]
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Video not found
- `400 Bad Request` - Invalid pagination parameters

---

#### 15. Post Reply
**Endpoint**: `POST /social/videos/reply/{commentId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `commentId` (string, required): Comment ID to reply to

**Request Body**:
```json
{
  "reply": "string"
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "Reply posted successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Comment not found
- `400 Bad Request` - Invalid reply data

---

#### 16. Get Replies
**Endpoint**: `POST /social/videos/replies/{commentId}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `commentId` (string, required): Comment ID to get replies for

**Request Body**:
```json
{
  "page": 1,
  "limit": 50
}
```

**Response** (200 OK):
```json
{
  "replies": [
    {
      "reply_id": "string",
      "replied_by": "string",
      "replied_to": "string",
      "replied_at": "ISO8601 datetime",
      "reply": "string"
    }
  ]
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - Comment not found
- `400 Bad Request` - Invalid pagination parameters

---

#### 17. Follow User
**Endpoint**: `POST /social/users/follow/{username}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `username` (string, required): Username to follow

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "User followed successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - User not found
- `400 Bad Request` - Already following or cannot follow self

---

#### 18. Unfollow User
**Endpoint**: `POST /social/users/unfollow/{username}`

**Method**: `POST`

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `username` (string, required): Username to unfollow

**Request Body**:
```json
{}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "message": "User unfollowed successfully"
}
```

**Error Responses**:
- `401 Unauthorized` - Invalid or missing token
- `404 Not Found` - User not found
- `400 Bad Request` - Not following this user

---

## Application Structure

### Directory Organization

```
lib/
├── app.dart                          # Main app widget with theme and routing
├── main.dart                         # Application entry point
├── firebase_options.dart             # Firebase configuration
│
├── core/
│   ├── constants/
│   │   ├── api_constants.dart        # API endpoint definitions
│   │   └── webrtc_constants.dart     # WebRTC configuration
│   │
│   ├── di/
│   │   └── app_providers.dart        # Dependency injection setup
│   │
│   ├── exceptions/
│   │   ├── api_exception.dart        # API error handling
│   │   └── auth_failure.dart         # Authentication errors
│   │
│   ├── presentation/
│   │   └── splash_screen.dart        # Loading screen
│   │
│   ├── routes/
│   │   └── app_router.dart           # Navigation and routing logic
│   │
│   ├── services/
│   │   ├── api_client.dart           # HTTP client with auth
│   │   ├── in_app_notification_service.dart  # SnackBar notifications
│   │   ├── network_connectivity_service.dart  # Network monitoring
│   │   ├── notification_service.dart # Local notifications
│   │   ├── token_storage_service.dart # Token persistence
│   │   └── workmanager_service.dart  # Background task management
│   │
│   └── workers/
│       └── video_upload_worker.dart  # Background upload handler
│
└── features/
    ├── auth/
    │   ├── data/
    │   │   └── auth_repository.dart  # Firebase auth implementation
    │   └── presentation/
    │       ├── viewmodels/
    │       │   └── auth_view_model.dart  # Auth state management
    │       └── views/
    │           └── auth_page.dart    # Sign in/sign up UI
    │
    ├── home/
    │   ├── domain/
    │   │   └── services/
    │   │       └── webrtc_service.dart  # WebRTC functionality
    │   └── presentation/
    │       ├── viewmodels/
    │       │   └── home_view_model.dart  # Home state management
    │       └── views/
    │           └── home_page.dart    # Home feed UI
    │
    ├── upload/
    │   ├── data/
    │   │   └── models/
    │   │       └── video_upload_payload.dart  # Upload data model
    │   ├── domain/
    │   │   └── services/
    │   │       ├── spaces_service.dart  # DigitalOcean Spaces client
    │   │       └── video_upload_service.dart  # Upload orchestration
    │   └── presentation/
    │       ├── viewmodels/
    │       │   ├── upload_view_model.dart  # File upload state
    │       │   └── video_upload_view_model.dart  # Video upload state
    │       └── views/
    │           └── video_upload_page.dart  # Upload UI
    │
    ├── user/
    │   ├── data/
    │   │   └── user_repository.dart  # User API client
    │   ├── domain/
    │   │   └── models/
    │   │       └── user_model.dart   # User data model
    │   └── presentation/
    │       ├── viewmodels/
    │       │   └── user_view_model.dart  # User state management
    │       └── views/
    │           └── user_profile_page.dart  # Profile UI
    │
    └── video/
        ├── domain/
        │   ├── models/
        │   │   ├── comment_model.dart  # Comment data model
        │   │   └── video_model.dart   # Video data model
        │   └── repositories/
        │       └── video_repository.dart  # Video API client
        └── presentation/
            ├── viewmodels/
            │   └── video_view_model.dart  # Video state management
            └── views/
                └── video_player_page.dart  # Video player UI
```

---

## User Flows

### 1. New User Registration Flow
```
1. User navigates to sign-up page
2. Enters name, username, email, password
3. Username availability checked in real-time (debounced)
4. Form validation
5. Firebase account creation
6. Backend user profile creation
7. Token saved to SharedPreferences
8. Automatic sign-out
9. Redirect to sign-in page
10. User signs in with credentials
11. Token retrieved and stored
12. User profile fetched
13. Navigation to home feed
```

### 2. Video Upload Flow
```
1. User navigates to upload page
2. Selects video file
3. Automatic thumbnail generation (2-second frame)
4. Option to upload custom thumbnail
5. Enters title, description, tags
6. Clicks "Upload Video"
7. Network connectivity check
8. Upload bridge creation (API call)
9. Receives gateway URLs
10. Video file upload to DigitalOcean Spaces (with progress)
11. Thumbnail upload (if provided)
12. Upload acknowledgment
13. Success notification
14. Automatic navigation back to home
15. Video feed refresh
```

### 3. Video Viewing Flow
```
1. User taps video card on home feed
2. Navigation to video player page
3. Video URL fetched from API (signed URL)
4. Video player initialization
5. Progressive playback starts
6. Video metadata displayed
7. Engagement actions available (vote, share, follow)
8. Comments section loaded (if authenticated)
9. User can interact with video and comments
```

### 4. Search Flow
```
1. User taps search icon
2. Search overlay appears
3. User types search query
4. Real-time suggestions appear (5 results)
5. User can:
   - Tap suggestion to view video
   - Tap "View all" for full search
   - Continue typing for more suggestions
6. Full search results displayed in feed
7. Pagination for more results
```

### 5. Profile Viewing Flow
```
1. User taps profile avatar/username
2. Navigation to profile page
3. User data fetched from API
4. Profile information displayed
5. If own profile:
   - Edit buttons for username/name
   - Delete account option
6. If other user's profile:
   - Follow/unfollow button
   - Read-only information
```

---

## Technical Implementation Details

### Authentication Flow

#### Token Management
- **Storage**: SharedPreferences with timestamp
- **Refresh**: Automatic on 401 responses
- **Format**: Firebase ID token as Bearer token
- **Lifecycle**: Saved on sign-in, deleted on sign-out

#### Router Guards
- **Authentication Check**: Delayed 100ms to allow Firebase state propagation
- **Redirect Logic**:
  - Unauthenticated users: Can access home, video player, upload, profiles
  - Authenticated users: Redirected from login/signup to home
  - Post-signup redirect: Special handling to prevent premature navigation

### Video Upload Architecture

#### Foreground Upload
- Immediate upload when user clicks "Upload"
- Real-time progress tracking
- In-app progress notifications
- WorkManager task registered as backup

#### Background Upload
- WorkManager task for app termination scenarios
- Network connectivity monitoring
- Automatic retry on connection loss
- Progress notifications via local notifications
- Isolate communication for status updates

#### Upload Stages
1. **Preparing**: Creating upload bridge
2. **Uploading Video**: Streaming video file to DigitalOcean Spaces
3. **Uploading Thumbnail**: Uploading thumbnail image
4. **Acknowledging**: Finalizing upload with backend

### Network Handling

#### Connectivity Monitoring
- Real-time network status tracking
- Automatic upload cancellation on connection loss
- User notifications for network errors
- Retry logic for failed uploads

#### API Client Features
- Automatic token injection
- Token refresh on 401 errors
- Retry logic for failed requests
- Optional authentication support
- Custom certificate handling for development

### State Management

#### Provider Pattern
- **ChangeNotifier**: Reactive state updates
- **Provider**: Dependency injection
- **Consumer/Selector**: Optimized rebuilds
- **MultiProvider**: Hierarchical providers

#### ViewModel Responsibilities
- Business logic encapsulation
- API communication
- State management
- Error handling
- Loading states

### Video Playback

#### Progressive Download
- Video starts playing while buffering
- Adaptive buffering based on network
- Error handling and retry
- Full-screen support
- Playback controls (play, pause, seek, volume)

#### URL Resolution
- API call to get signed video URL
- Optional authentication (works for both authenticated and unauthenticated)
- Caching of resolved URLs
- Error handling for missing videos

### Comments System

#### Threading
- Comments with nested replies
- Expandable reply sections
- Pagination for both comments and replies
- Real-time updates after posting

#### User Experience
- Sign-in prompt for unauthenticated users
- Optimistic UI updates
- Loading states
- Error handling with user feedback

### Search Implementation

#### Real-Time Suggestions
- Debounced API calls (500ms)
- 5 suggestion results
- Highlighted search terms
- Twitch-style overlay

#### Full Search
- Paginated results
- Search query persistence
- Clear search functionality
- Loading and error states

### Notification System

#### In-App Notifications
- SnackBar-based notifications
- Success/error styling
- Progress notifications
- Dismissible notifications

#### Local Notifications
- Background upload progress
- Completion notifications
- Error notifications
- Network error notifications

### Error Handling

#### API Errors
- Custom exception types
- User-friendly error messages
- Retry logic for transient errors
- Logging for debugging

#### Network Errors
- Connectivity checks
- Automatic retry with exponential backoff
- User notifications
- Graceful degradation

### Performance Optimizations

#### Image Loading
- Network images with error handling
- Loading placeholders
- Cached thumbnails
- Lazy loading for video feed

#### List Rendering
- Sliver widgets for efficient scrolling
- Pagination to limit data load
- Virtual scrolling for large lists
- Image caching

#### State Updates
- Selective rebuilds with Consumer/Selector
- Debounced API calls
- Optimistic UI updates
- Batch state updates

---

## Data Models

### User Model
```dart
{
  username: string (required)
  name: string (required)
  email: string (optional)
  bio: string (optional)
  avatarUrl: string (optional)
  profilePicture: string (optional)
  docId: string (optional)
  uid: string (optional)
  createdAt: DateTime (optional)
  updatedAt: DateTime (optional)
  role: string (optional)
  followers: int (default: 0)
  following: int (default: 0)
  totalStreams: int (default: 0)
  totalVideos: int (default: 0)
  status: UserStatus (optional)
  isFollowing: bool (optional)
}
```

### Video Model
```dart
{
  videoId: string (required)
  videoUrl: string (required)
  videoThumbnail: string (required)
  videoTitle: string (required)
  videoDescription: string (required)
  videoTags: List<string> (required)
  videoViews: int (default: 0)
  videoUpvotes: int (default: 0)
  videoDownvotes: int (default: 0)
  videoComments: int (default: 0)
  userUid: string (required)
  userUsername: string (required)
  createdAt: DateTime (required)
  updatedAt: DateTime (required)
  userVoteStatus: string? ("upvoted" | "downvoted" | null)
}
```

### Comment Model
```dart
{
  commentId: string (required)
  commentedBy: string (required)
  commentByUsername: string (optional)
  commentedTo: string (required)
  commentedAt: DateTime (required)
  comment: string (required)
  totalReplies: int (default: 0)
  replies: List<ReplyModel> (optional)
}
```

### Reply Model
```dart
{
  replyId: string (required)
  repliedBy: string (required)
  repliedTo: string (required)
  repliedAt: DateTime (required)
  reply: string (required)
}
```

---

## Security Considerations

### Authentication
- Firebase ID tokens for API authentication
- Automatic token refresh
- Secure token storage in SharedPreferences
- Token deletion on sign-out

### API Security
- Bearer token authentication
- HTTPS for all API calls
- Certificate validation (relaxed for development)
- Input validation on client side

### Data Privacy
- User data encrypted in transit
- Secure storage of authentication tokens
- No sensitive data in logs
- Proper error message sanitization

---

## Future Enhancements (Not Yet Implemented)

### Potential Features
- Live streaming support
- Video editing capabilities
- Playlist creation
- Video recommendations
- Push notifications for engagement
- Social sharing integration
- Video quality selection
- Offline video download
- User subscriptions
- Monetization features
- Analytics dashboard
- Content moderation tools

---

## Development Notes

### Environment Configuration
- Base API URL: `https://hiffi.alterwork.in/api`
- Firebase project configuration in `firebase_options.dart`
- DigitalOcean Spaces credentials in `app_providers.dart`
- Development certificate validation relaxed

### Build Configuration
- Flutter SDK required
- Platform-specific configurations in `android/` and `ios/` directories
- WorkManager initialization in `main.dart`
- Notification channel setup for Android

### Testing Considerations
- Unit tests for view models
- Integration tests for API clients
- Widget tests for UI components
- E2E tests for critical user flows

---

## Conclusion

Hiffi is a comprehensive video streaming platform with robust features for content creation, consumption, and social interaction. The application leverages modern Flutter architecture patterns, Firebase authentication, and a RESTful API backend to deliver a seamless user experience across iOS and Android platforms.

The platform supports both authenticated and unauthenticated users, with progressive enhancement of features based on authentication status. Background processing ensures reliable video uploads even when the app is terminated, and real-time network monitoring provides a responsive user experience.

