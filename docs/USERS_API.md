# Users API Documentation

This document provides comprehensive API documentation for the Users endpoints in the Hifi backend.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [User Model](#user-model)
- [Endpoints](#endpoints)
  - [Get User by Username](#1-get-user-by-username)
  - [Get Self](#2-get-self)
  - [Update User](#3-update-user)
  - [Delete User](#4-delete-user)
  - [Check Username Availability](#5-check-username-availability)
  - [List Users](#6-list-users)
  - [Upload Profile Photo](#7-upload-profile-photo)
- [Validation Rules](#validation-rules)
- [Error Responses](#error-responses)

---

## Overview

The Users API provides endpoints for managing user profiles, including retrieval, updates, deletion, and listing operations. All endpoints require authentication except for username availability checks.

**Base Path:** `/users`

---

## Authentication

Most endpoints require authentication via JWT token. The token should be included in the `Authorization` header:

```
Authorization: Bearer <jwt_token>
```

The token is validated using the `Auth.GetClaims` function, which extracts and validates the JWT claims from the request.

---

## User Model

The User object contains the following fields:

```json
{
  "id": 1,
  "uid": "string",
  "username": "string",
  "name": "string",
  "role": "string",
  "profile_picture": "string",
  "followers": 0,
  "following": 0,
  "total_streams": 0,
  "total_videos": 0,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Field Descriptions:**
- `id`: Internal database ID (integer)
- `uid`: Unique user identifier (string, 32 characters)
- `username`: User's username (string, lowercase, 3-30 characters)
- `name`: User's display name (string)
- `role`: User's role in the system (string)
  - Default value: `"user"`
  - Valid values: `"user"`, `"creator"`, `"admin"`
  - Can be updated via Update User endpoint (only to `"user"` or `"creator"`, not `"admin"`)
- `profile_picture`: URL to user's profile picture (string)
- `followers`: Number of followers (integer)
- `following`: Number of users being followed (integer)
- `total_streams`: Total number of streams (integer)
- `total_videos`: Total number of videos (integer)
- `created_at`: Account creation timestamp (ISO 8601)
- `updated_at`: Last update timestamp (ISO 8601)

---

## Endpoints

### 1. Get User by Username

Retrieves public profile information for a specific user by their username.

**Endpoint:** `GET /users/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user to retrieve (case-insensitive)

**Request Example:**
```http
GET /users/johndoe
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "user": {
    "id": 1,
    "uid": "abc123def456...",
    "username": "johndoe",
    "name": "John Doe",
    "role": "user",
    "profile_picture": "https://example.com/pic.jpg",
    "followers": 150,
    "following": 75,
    "total_streams": 42,
    "total_videos": 10,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-20T14:22:00Z"
  }
}
```

**Error Responses:**
- `400 Bad Request`: Username is required
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: User not found
- `500 Internal Server Error`: Failed to fetch user

---

### 2. Get Self

⚠️ **DEPRECATED**: This endpoint is deprecated. Use `GET /users/{username}` with your own username instead.

Retrieves the authenticated user's own profile information.

**Endpoint:** `GET /users/self`

**Authentication:** Required

**Request Example:**
```http
GET /users/self
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "user": {
    "id": 1,
    "uid": "abc123def456...",
    "username": "johndoe",
    "name": "John Doe",
    "role": "user",
    "profile_picture": "https://example.com/pic.jpg",
    "followers": 150,
    "following": 75,
    "total_streams": 42,
    "total_videos": 10,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-20T14:22:00Z"
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: User not found
- `500 Internal Server Error`: Failed to fetch user

---

### 3. Update User

Updates user profile information. Users can only update their own account (identified by JWT token).

**Endpoint:** `PUT /users/self`

**Authentication:** Required

**Request Body:**
All fields are optional. Only provided fields will be updated. Note: Username cannot be updated through this endpoint.

```json
{
  "name": "New Name",
  "profile_picture": "https://example.com/newpic.jpg",
  "role": "creator"
}
```

**Request Body Parameters:**
- `name` (string, optional): User's display name
  - Must be less than 30 characters
  - Cannot be empty
- `profile_picture` (string, optional): URL to user's profile picture
- `role` (string, optional): User's role
  - Valid values: `"user"`, `"creator"`
  - Cannot be set to `"admin"` via this endpoint
  - Default: `"user"`

**Request Example:**
```http
PUT /users/self
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "John Smith",
  "profile_picture": "https://example.com/newpic.jpg"
}
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "user": {
    "id": 1,
    "uid": "abc123def456...",
    "username": "johndoe",
    "name": "John Smith",
    "role": "user",
    "profile_picture": "https://example.com/newpic.jpg",
    "followers": 150,
    "following": 75,
    "total_streams": 42,
    "total_videos": 10,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-21T09:15:00Z"
  }
}
```

**Error Responses:**
- `400 Bad Request`: 
  - Invalid request body
  - Name validation failed (see [Validation Rules](#validation-rules))
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: User not found
- `500 Internal Server Error`: 
  - Failed to load user
  - Failed to update user
  - Failed to load updated user

**Notes:**
- The user is identified from the JWT token (same as `GetSelf` endpoint)
- **Username cannot be updated** through this endpoint
- `name`, `profile_picture`, and `role` can be updated
- Role can only be set to `"user"` or `"creator"` (not `"admin"`)
- If no fields are provided in the request body, the current user data is returned unchanged
- The `updated_at` timestamp is automatically updated
- **Elasticsearch Integration**: If `profile_picture` is updated, the user is automatically re-indexed in Elasticsearch (non-blocking operation)
  - Indexed fields: `uid`, `username`, `profile_picture`
  - If Elasticsearch indexing fails, the operation logs an error but does not fail the update

---

### 4. Delete User

Deletes a user account (soft delete - moves user to `deleted_users` table). Users can only delete their own account.

**Endpoint:** `DELETE /users/{username}`

**Authentication:** Required

**URL Parameters:**
- `username` (string, required): The username of the user to delete (must match authenticated user)

**Request Example:**
```http
DELETE /users/johndoe
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "User deleted successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Username is required
- `401 Unauthorized`: Missing or invalid authentication token
- `403 Forbidden`: You can only delete your own account
- `404 Not Found`: User not found
- `500 Internal Server Error`: 
  - Failed to load user
  - Failed to start transaction
  - Failed to archive deleted user
  - Failed to delete user
  - Failed to complete deletion

**Notes:**
- Deletion is performed using a database transaction to ensure atomicity
- User data is moved to the `deleted_users` table before deletion
- The operation includes a `deleted_at` timestamp in the archived record
- **Elasticsearch Integration**: Automatically deletes the user from Elasticsearch index (non-blocking operation)
  - If Elasticsearch deletion fails, the operation logs an error but does not fail the deletion
- Foreign key CASCADE automatically deletes related data:
  - All videos uploaded by the user
  - All followers relationships (both followed_by and followed_to)
  - All blocklists relationships (both blocked_by and blocked_to)
  - All upvotes, downvotes, comments, replies, and views

---

### 5. Check Username Availability

Checks if a username is available for registration. This endpoint does not require authentication.

**Endpoint:** `GET /users/availability/{username}`

**Authentication:** Not required

**URL Parameters:**
- `username` (string, required): The username to check for availability

**Request Example:**
```http
GET /users/availability/johndoe
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "available": true,
  "username": "johndoe"
}
```

If username is taken:
```json
{
  "status": "success",
  "available": false,
  "username": "johndoe"
}
```

**Error Responses:**
- `400 Bad Request`: 
  - Username is required
  - Username validation failed (see [Validation Rules](#validation-rules))
- `500 Internal Server Error`: Error checking username availability

**Notes:**
- Username is automatically converted to lowercase and trimmed
- Username format is validated before checking availability
- ⚠️ **TODO**: Rate limiting middleware should be added to prevent abuse

---

### 6. List Users

Retrieves a paginated list of all users using deterministic random pagination (stable shuffle). The results appear in a pseudo-random order that is consistent across pagination requests, ensuring no duplicates or missed items when navigating through pages.

**Endpoint:** `GET /users/list`

**Authentication:** Required

**Query Parameters:**
- `limit` (integer, optional): Number of users to return per page
  - Default: `20`
  - Maximum: `100`
  - Must be greater than 0
- `offset` (integer, optional): Number of users to skip
  - Default: `0`
  - Must be greater than or equal to 0
- `seed` (string, optional): Seed for deterministic random pagination
  - If not provided, uses default seed: `"hifi_users_shuffle_2024"`
  - Different seeds produce different shuffle orders
  - Same seed always produces the same order (stable shuffle)

**Request Example:**
```http
GET /users/list?limit=10&offset=0&seed=my_custom_seed
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "users": [
    {
      "id": 1,
      "uid": "abc123def456...",
      "username": "johndoe",
      "name": "John Doe",
      "role": "user",
      "profile_picture": "https://example.com/pic.jpg",
      "followers": 150,
      "following": 75,
      "total_streams": 42,
      "total_videos": 10,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-20T14:22:00Z"
    },
    {
      "id": 2,
      "uid": "xyz789ghi012...",
      "username": "janedoe",
      "name": "Jane Doe",
      "role": "user",
      "profile_picture": "https://example.com/jane.jpg",
      "followers": 200,
      "following": 50,
      "total_streams": 30,
      "total_videos": 8,
      "created_at": "2024-01-14T08:20:00Z",
      "updated_at": "2024-01-19T16:45:00Z"
    }
  ],
  "limit": 10,
  "offset": 0,
  "count": 2,
  "seed": "my_custom_seed"
}
```

**Error Responses:**
- `401 Unauthorized`: Missing or invalid authentication token
- `500 Internal Server Error`: 
  - Failed to fetch users
  - Failed to iterate users

**Notes:**
- Results use **deterministic random pagination** (stable shuffle) - the order appears random but is consistent across requests
- The `seed` parameter controls the shuffle order - same seed = same order, different seed = different order
- If no seed is provided, a default seed is used (`"hifi_users_shuffle_2024"`)
- This ensures safe pagination: requesting page 1, then page 2 with the same seed will show different users without duplicates or gaps
- The shuffle order is stable and will remain the same for all pagination requests using the same seed
- The response includes the `seed` value used (either provided or default) for reference
- Invalid `limit` or `offset` values are ignored and defaults are used
- The `count` field represents the number of users returned in the current page

---

### 7. Upload Profile Photo

Generates a presigned URL for uploading a profile photo to cloud storage. This is a two-step process: first get the presigned URL, then upload the photo directly to storage using that URL.

**Endpoint:** `POST /users/profile-photo/upload`

**Authentication:** Required

**Request Example:**
```http
POST /users/profile-photo/upload
Authorization: Bearer <jwt_token>
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Profile photo upload URL generated",
  "gateway_url": "https://storage.example.com/presigned-url-here",
  "path": "ProfileProto/users/abc123def456.jpg"
}
```

**Response Fields:**
- `message`: Confirmation message
- `gateway_url`: Presigned URL for uploading the profile photo (valid for 20 minutes)
- `path`: Storage path where the photo will be stored (`ProfileProto/users/{uid}.jpg`)

**Error Responses:**
- `401 Unauthorized`: Missing or invalid authentication token
- `500 Internal Server Error`: Failed to generate presigned upload URL

**Upload Workflow:**
1. **Step 1**: Call this endpoint to get a presigned upload URL
2. **Step 2**: Use the returned `gateway_url` to upload the photo file directly (PUT request with the image file as body)
3. **Step 3**: After successful upload, call `PUT /users/self` with `profile_picture` field set to the returned `path` value to update the user's profile

**Notes:**
- The presigned URL expires after **20 minutes**
- The photo will be stored at path `ProfileProto/users/{uid}.jpg` where `{uid}` is the authenticated user's UID
- The user is automatically identified from the JWT token
- After uploading the photo to storage, you must update the user's `profile_picture` field via the [Update User](#3-update-user) endpoint to reflect the new photo
- This endpoint only generates the upload URL - it does not modify the user's profile
- Each call generates a new presigned URL for the same path, allowing users to replace their profile photo

**Example Complete Flow:**
```bash
# 1. Get presigned upload URL
curl -X POST https://api.example.com/users/profile-photo/upload \
  -H "Authorization: Bearer <jwt_token>"

# Response: { "gateway_url": "https://...", "path": "ProfileProto/users/user123.jpg" }

# 2. Upload photo to the presigned URL
curl -X PUT "https://storage.example.com/presigned-url-here" \
  -H "Content-Type: image/jpeg" \
  --data-binary @profile-photo.jpg

# 3. Update user profile with the new photo path
curl -X PUT https://api.example.com/users/self \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"profile_picture": "ProfileProto/users/user123.jpg"}'
```

---

## Validation Rules

### Username Validation

- **Length**: Must be between 3 and 30 characters (inclusive)
- **Format**: Must contain only:
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Underscores (_)
- **Case**: Automatically converted to lowercase
- **Whitespace**: Automatically trimmed
- **Regex Pattern**: `^[a-z0-9_]{3,30}$`

**Examples:**
- ✅ Valid: `john_doe`, `user123`, `test_user_99`
- ❌ Invalid: `ab` (too short), `JohnDoe` (uppercase), `user-name` (hyphen not allowed), `user name` (spaces not allowed)

### Name Validation

- **Length**: Must be less than 30 characters
- **Required**: Cannot be empty
- **Whitespace**: Automatically trimmed

---

## Error Responses

All error responses follow a consistent format:

```json
{
  "status": "error",
  "message": "Error message description"
}
```

**Common HTTP Status Codes:**
- `400 Bad Request`: Invalid request parameters or body
- `401 Unauthorized`: Missing or invalid authentication token
- `403 Forbidden`: Insufficient permissions (e.g., trying to update/delete another user's account)
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict (e.g., username already exists)
- `500 Internal Server Error`: Server-side error

---

## Implementation Notes

### Database Indexes

For optimal performance, ensure the following indexes exist:
- `users(uid)` - Primary lookup index
- `users(username)` - Username lookup and uniqueness checks

### Transaction Safety

The `DeleteUser` endpoint uses database transactions to ensure atomicity when:
1. Archiving the user to `deleted_users` table
2. Deleting the user from `users` table

If either operation fails, the transaction is rolled back.

### Username Normalization

All usernames are automatically:
- Converted to lowercase
- Trimmed of leading/trailing whitespace

This ensures consistent storage and lookup regardless of how the username is provided in requests.

---

## Rate Limiting

⚠️ **Note**: The `UsernameAvailability` endpoint currently lacks rate limiting. It is recommended to add rate limiting middleware to prevent abuse.

---

## Changelog

- Initial API documentation created
- Added `role` field with default value `"user"`
  - Role can be updated via Update User endpoint (only to `"user"` or `"creator"`, not `"admin"`)
- Added Elasticsearch integration for user indexing and search
  - Users are automatically indexed when registered
  - Users are automatically re-indexed when profile picture is updated
  - Users are automatically removed from Elasticsearch index when deleted
- Added `POST /users/profile-photo/upload` endpoint for generating presigned URLs to upload profile photos
  - Returns presigned URL valid for 20 minutes
  - Photos stored at path `ProfileProto/users/{uid}.jpg`
  - Requires authentication via JWT token
- **DEPRECATED** `GET /users/self` endpoint
  - Use `GET /users/{username}` with your own username instead
  - This provides the same functionality with a consistent interface

