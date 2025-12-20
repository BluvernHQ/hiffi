# Social API Documentation

This document provides comprehensive API documentation for the Social endpoints in the Hifi backend.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Data Models](#data-models)
- [User Social Endpoints](#user-social-endpoints)
  - [Follow User](#1-follow-user)
  - [Unfollow User](#2-unfollow-user)
  - [List Followers](#3-list-followers)
  - [List Following](#4-list-following)
- [Video Social Endpoints](#video-social-endpoints)
  - [Upvote Video](#5-upvote-video)
  - [Downvote Video](#6-downvote-video)
  - [Comment on Video](#7-comment-on-video)
  - [Reply to Comment](#8-reply-to-comment)
  - [List Comments](#9-list-comments)
  - [List Replies](#10-list-replies)
- [Pagination](#pagination)
- [Error Responses](#error-responses)

---

## Overview

The Social API provides endpoints for user interactions (following/unfollowing) and video engagement (upvotes, downvotes, comments, replies). The system supports deterministic random pagination for follower/following lists and timestamp-based ordering for comments and replies.

**Base Paths:**
- User Social: `/social/users`
- Video Social: `/social/videos`

---

## Authentication

All endpoints require authentication via JWT token. The token should be included in the `Authorization` header:

```
Authorization: Bearer <jwt_token>
```

The token is validated using the `Auth.GetClaims` function, which extracts and validates the JWT claims from the request.

---

## Data Models

### Followers Model

```json
{
  "followed_by": "string",
  "followed_to": "string",
  "followed_at": "2024-01-01T00:00:00Z"
}
```

**Field Descriptions:**
- `followed_by`: Username of the user who is following (string)
- `followed_to`: Username of the user being followed (string)
- `followed_at`: Timestamp when the follow relationship was created (ISO 8601)

### Comments Model

```json
{
  "comment_id": "string",
  "commented_by": "string",
  "commented_to": "string",
  "commented_at": "2024-01-01T00:00:00Z",
  "comment": "string",
  "comment_by_username": "string",
  "total_replies": 0
}
```

**Field Descriptions:**
- `comment_id`: Unique comment identifier (string, 64-character hex)
- `commented_by`: UID of the user who commented (string)
- `commented_to`: Video ID that was commented on (string)
- `commented_at`: Timestamp when the comment was created (ISO 8601)
- `comment`: The comment text (string)
- `comment_by_username`: Username of the user who commented (string)
- `total_replies`: Number of replies to this comment (integer)

### Replies Model

```json
{
  "reply_id": "string",
  "replied_by": "string",
  "replied_to": "string",
  "replied_at": "2024-01-01T00:00:00Z",
  "reply": "string",
  "reply_by_username": "string"
}
```

**Field Descriptions:**
- `reply_id`: Unique reply identifier (string, 64-character hex)
- `replied_by`: UID of the user who replied (string)
- `replied_to`: Comment ID that was replied to (string)
- `replied_at`: Timestamp when the reply was created (ISO 8601)
- `reply`: The reply text (string)
- `reply_by_username`: Username of the user who replied (string)

---

## User Social Endpoints

### 1. Follow User

Follows a user by creating a follower relationship.

**Endpoint:** `POST /social/users/follow/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user to follow

**Request Example:**
```http
POST /social/users/follow/johndoe
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Followed successfully"
  }
}
```

**Error Responses:**

- **400 Bad Request:** You are already following this user
  ```json
  {
    "success": false,
    "error": "You are already following this user"
  }
  ```

- **404 Not Found:** User not found
  ```json
  {
    "success": false,
    "error": "User not found"
  }
  ```

**Behavior:**
- Creates a record in the `followers` table
- Increments the `followers` count for the followed user
- Increments the `following` count for the authenticated user
- Returns an error if already following

---

### 2. Unfollow User

Unfollows a user by removing the follower relationship.

**Endpoint:** `POST /social/users/unfollow/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user to unfollow

**Request Example:**
```http
POST /social/users/unfollow/johndoe
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Unfollowed successfully"
  }
}
```

**Error Responses:**

- **400 Bad Request:** Not following this user
  ```json
  {
    "success": false,
    "error": "You are not following this user"
  }
  ```

- **404 Not Found:** User not found
  ```json
  {
    "success": false,
    "error": "User not found"
  }
  ```

**Behavior:**
- Removes the record from the `followers` table
- Decrements the `followers` count for the unfollowed user
- Decrements the `following` count for the authenticated user
- Returns an error if not following

---

### 3. List Followers

Retrieves a paginated list of users who follow a specific user.

**Endpoint:** `GET /social/users/followers/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user whose followers to list

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)
- `seed` (string, optional): Seed for deterministic random pagination (default: "default")

**Request Example:**
```http
GET /social/users/followers/johndoe?limit=20&offset=0&seed=myseed
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "followers": [
      {
        "followed_by": "user1",
        "followed_to": "johndoe",
        "followed_at": "2024-01-01T00:00:00Z"
      },
      {
        "followed_by": "user2",
        "followed_to": "johndoe",
        "followed_at": "2024-01-02T00:00:00Z"
      }
    ],
    "limit": 20,
    "offset": 0,
    "count": 150,
    "seed": "myseed"
  }
}
```

**Response Fields:**
- `followers`: Array of follower relationships
- `limit`: Number of results per page
- `offset`: Number of results skipped
- `count`: Total number of followers
- `seed`: Seed used for pagination

**Pagination:**
Uses deterministic random pagination (stable shuffle) based on the `seed` parameter. Same seed produces the same order.

---

### 4. List Following

Retrieves a paginated list of users that a specific user is following.

**Endpoint:** `GET /social/users/following/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user whose following list to retrieve

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)
- `seed` (string, optional): Seed for deterministic random pagination (default: "default")

**Request Example:**
```http
GET /social/users/following/johndoe?limit=20&offset=0&seed=myseed
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "following": [
      {
        "followed_by": "johndoe",
        "followed_to": "user1",
        "followed_at": "2024-01-01T00:00:00Z"
      },
      {
        "followed_by": "johndoe",
        "followed_to": "user2",
        "followed_at": "2024-01-02T00:00:00Z"
      }
    ],
    "limit": 20,
    "offset": 0,
    "count": 50,
    "seed": "myseed"
  }
}
```

**Response Fields:**
- `following`: Array of following relationships
- `limit`: Number of results per page
- `offset`: Number of results skipped
- `count`: Total number of users being followed
- `seed`: Seed used for pagination

**Pagination:**
Uses deterministic random pagination (stable shuffle) based on the `seed` parameter. Same seed produces the same order.

---

## Video Social Endpoints

### 5. Upvote Video

Upvotes a video. If the user has already upvoted, the action is idempotent. If the user has downvoted, the downvote is removed and the upvote is added.

**Endpoint:** `POST /social/videos/upvote/{videoID}`

**Authentication:** Required

**URL Parameters:**
- `videoID` (string, required): The video ID to upvote

**Request Example:**
```http
POST /social/videos/upvote/abc123def456...
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Video upvoted"
  }
```

**Special Cases:**
- If already upvoted: Returns `"Already upvoted, downvote removed if existed"`
- If previously downvoted: Removes the downvote and adds the upvote

**Behavior:**
- Removes any existing downvote from the user
- Adds an upvote (or confirms existing upvote)
- Increments the video's `video_upvotes` count
- Decrements the video's `video_downvotes` count if a downvote was removed

---

### 6. Downvote Video

Downvotes a video. If the user has already downvoted, the action is idempotent. If the user has upvoted, the upvote is removed and the downvote is added.

**Endpoint:** `POST /social/videos/downvote/{videoID}`

**Authentication:** Required

**URL Parameters:**
- `videoID` (string, required): The video ID to downvote

**Request Example:**
```http
POST /social/videos/downvote/abc123def456...
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Video downvoted"
  }
}
```

**Special Cases:**
- If already downvoted: Returns `"Already downvoted, upvote removed if existed"`
- If previously upvoted: Removes the upvote and adds the downvote

**Behavior:**
- Removes any existing upvote from the user
- Adds a downvote (or confirms existing downvote)
- Increments the video's `video_downvotes` count
- Decrements the video's `video_upvotes` count if an upvote was removed

---

### 7. Comment on Video

Adds a comment to a video.

**Endpoint:** `POST /social/videos/comment/{videoID}`

**Authentication:** Required

**URL Parameters:**
- `videoID` (string, required): The video ID to comment on

**Request Body:**
```json
{
  "comment": "This is a great video!"
}
```

**Request Example:**
```http
POST /social/videos/comment/abc123def456...
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "comment": "This is a great video!"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Video commented"
  }
}
```

**Error Responses:**

- **400 Bad Request:** Comment text is required
  ```json
  {
    "success": false,
    "error": "Comment text is required"
  }
  ```

- **404 Not Found:** Video not found
  ```json
  {
    "success": false,
    "error": "Video not found"
  }
  ```

**Behavior:**
- Creates a comment record with a unique `comment_id` (generated using blake3 hash)
- Increments the video's `video_comments` count
- Stores the comment text and associated metadata

---

### 8. Reply to Comment

Adds a reply to a comment. If the user has already replied to this comment, the existing reply is updated.

**Endpoint:** `POST /social/videos/reply/{commentID}`

**Authentication:** Required

**URL Parameters:**
- `commentID` (string, required): The comment ID to reply to

**Request Body:**
```json
{
  "reply": "I agree with your comment!"
}
```

**Request Example:**
```http
POST /social/videos/reply/xyz789abc123...
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "reply": "I agree with your comment!"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Reply added"
  }
}
```

**Special Case:**
If the user has already replied to this comment, the response will be:
```json
{
  "success": true,
  "data": {
    "message": "Reply updated"
  }
}
```

**Error Responses:**

- **400 Bad Request:** Reply text is required
  ```json
  {
    "success": false,
    "error": "Reply text is required"
  }
  ```

- **404 Not Found:** Comment not found
  ```json
  {
    "success": false,
    "error": "Comment not found"
  }
  ```

**Behavior:**
- If the user has not replied before: Creates a new reply and increments the comment's `total_replies` count
- If the user has already replied: Updates the existing reply (does not increment count)
- Generates a unique `reply_id` using blake3 hash

---

### 9. List Comments

Retrieves a paginated list of comments for a specific video.

**Endpoint:** `GET /social/videos/comments/{videoID}`

**Authentication:** Not required (but recommended for consistency)

**URL Parameters:**
- `videoID` (string, required): The video ID to get comments for

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Request Example:**
```http
GET /social/videos/comments/abc123def456...?limit=20&offset=0
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "comment_id": "xyz789abc123...",
        "commented_by": "user_uid_123",
        "commented_to": "abc123def456...",
        "commented_at": "2024-01-01T00:00:00Z",
        "comment": "Great video!",
        "comment_by_username": "johndoe",
        "total_replies": 5
      }
    ],
    "limit": 20,
    "offset": 0,
    "count": 150
  }
}
```

**Response Fields:**
- `comments`: Array of comment objects
- `limit`: Number of results per page
- `offset`: Number of results skipped
- `count`: Total number of comments for the video

**Ordering:**
Comments are ordered by timestamp in descending order (newest first). This ensures the most recent comments appear at the top of the list.

---

### 10. List Replies

Retrieves a paginated list of replies for a specific comment.

**Endpoint:** `GET /social/videos/replies/{commentID}`

**Authentication:** Not required (but recommended for consistency)

**URL Parameters:**
- `commentID` (string, required): The comment ID to get replies for

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Request Example:**
```http
GET /social/videos/replies/xyz789abc123...?limit=20&offset=0
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "replies": [
      {
        "reply_id": "def456ghi789...",
        "replied_by": "user_uid_456",
        "replied_to": "xyz789abc123...",
        "replied_at": "2024-01-01T12:00:00Z",
        "reply": "I agree!",
        "reply_by_username": "janedoe"
      }
    ],
    "limit": 20,
    "offset": 0,
    "count": 25
  }
}
```

**Response Fields:**
- `replies`: Array of reply objects
- `limit`: Number of results per page
- `offset`: Number of results skipped
- `count`: Total number of replies for the comment

**Ordering:**
Replies are ordered by timestamp in descending order (newest first). This ensures the most recent replies appear at the top of the list.

---

## Pagination

All list endpoints support pagination using the following query parameters:

- **`limit`**: Number of results per page (default: 20, maximum: 100)
- **`offset`**: Number of results to skip (default: 0)

### Pagination Types

#### Deterministic Random Pagination (Followers/Following)

The follower and following list endpoints use deterministic random pagination (stable shuffle) with an additional `seed` parameter:

- **`seed`** (string, optional): Seed for deterministic ordering (default: "default")

**How It Works:**

The pagination uses PostgreSQL's `hashtext()` function to create a deterministic but seemingly random order:

```sql
ORDER BY hashtext(id::text || $seed)
LIMIT $limit OFFSET $offset
```

**Benefits:**
- Same seed produces the same order (stable shuffle)
- Prevents duplicates and gaps during pagination
- Allows clients to cache pagination state
- Provides a randomized appearance while maintaining consistency

**Example Usage:**
```http
# First page
GET /social/users/followers/johndoe?limit=20&offset=0&seed=myseed

# Second page
GET /social/users/followers/johndoe?limit=20&offset=20&seed=myseed

# Third page
GET /social/users/followers/johndoe?limit=20&offset=40&seed=myseed
```

**Important:** Using the same `seed` ensures consistent ordering across requests. Changing the `seed` will produce a different ordering.

#### Timestamp-Based Pagination (Comments/Replies)

The comments and replies list endpoints use timestamp-based ordering (newest first):

```sql
ORDER BY commented_at DESC  -- for comments
ORDER BY replied_at DESC     -- for replies
LIMIT $limit OFFSET $offset
```

**Benefits:**
- Most recent content appears first
- Natural chronological ordering
- Simple and predictable pagination

**Example Usage:**
```http
# First page (newest comments)
GET /social/videos/comments/abc123...?limit=20&offset=0

# Second page
GET /social/videos/comments/abc123...?limit=20&offset=20

# Third page
GET /social/videos/comments/abc123...?limit=20&offset=40
```

---

## Error Responses

All endpoints use a standardized error response format:

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

### Common HTTP Status Codes

- **200 OK**: Request succeeded
- **400 Bad Request**: Invalid request parameters or data
- **401 Unauthorized**: Missing or invalid authentication token
- **404 Not Found**: Resource not found (user, video, comment, etc.)
- **500 Internal Server Error**: Server-side error occurred

### Error Response Examples

**Unauthorized:**
```json
{
  "success": false,
  "error": "Unauthorized"
}
```

**User Not Found:**
```json
{
  "success": false,
  "error": "User not found"
}
```

**Video Not Found:**
```json
{
  "success": false,
  "error": "Video not found"
}
```

**Already Following:**
```json
{
  "success": false,
  "error": "You are already following this user"
}
```

---

## Implementation Notes

### Vote System

The upvote/downvote system ensures mutual exclusivity:
- A user can only have one vote per video (either upvote or downvote)
- Upvoting removes any existing downvote
- Downvoting removes any existing upvote
- Re-upvoting or re-downvoting is idempotent

### Comment and Reply IDs

- Comment IDs and Reply IDs are generated using blake3 hash of: `UID + timestamp + UUID + videoID/commentID`
- This ensures uniqueness and prevents collisions
- IDs are 64-character hexadecimal strings

### View Tracking

Video views are tracked automatically when videos are accessed. The `View` function is called internally by the video retrieval endpoint and:
- Tracks views per authenticated user (prevents duplicate counting)
- Increments total view count for the video
- Uses `ON CONFLICT DO NOTHING` to handle concurrent requests

### Database Relationships

All social interactions use foreign key constraints with `ON DELETE CASCADE`:
- Deleting a user removes all their follows, votes, comments, and replies
- Deleting a video removes all votes, comments (and their replies), and views
- Deleting a comment removes all replies to that comment

---

## Changelog

### Recent Updates

- **2024-12-14**: Changed comments and replies ordering to timestamp-based (newest first) instead of deterministic random shuffle
- **2024-12-14**: Removed `seed` parameter from ListComments and ListReplies endpoints
- **2024-12-14**: Converted list endpoints from POST to GET with query parameters
- **2024-12-14**: Implemented deterministic random pagination for follower/following list endpoints
- **2024-12-14**: Standardized error and success responses across all endpoints
- **2024-12-14**: Added context-aware database queries for better request handling
- **2024-12-14**: Improved error handling using `errors.Is` for better error detection

---

## Related Documentation

- [Users API Documentation](../Users/USERS_API.md)
- [Videos API Documentation](../Videos/VIDEOS_API.md)
- [Auth API Documentation](../Auth/AUTH_API.md)
- [Architecture Documentation](../../ARCHITECTURE.md)

