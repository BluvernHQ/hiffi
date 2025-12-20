# Authentication API Documentation

This document provides comprehensive API documentation for user registration and authentication endpoints in the Hifi backend.

## Table of Contents

- [Overview](#overview)
- [Authentication Flow](#authentication-flow)
- [Endpoints](#endpoints)
  - [Register](#1-register)
  - [Login](#2-login)
- [Using JWT Tokens](#using-jwt-tokens)
- [Validation Rules](#validation-rules)
- [Error Responses](#error-responses)
- [Security Notes](#security-notes)

---

## Overview

The Authentication API provides endpoints for user registration and login. The system uses **JWT (JSON Web Tokens)** for authentication. After successful registration or login, you receive a JWT token that must be included in subsequent API requests.

**Base Path:** `/auth`

---

## Authentication Flow

1. **Register** a new user account → Receive JWT token
2. **Login** with existing credentials → Receive JWT token
3. **Use the token** in the `Authorization` header for protected endpoints

### Token Details

- **Token Type:** JWT (HS256 signing method)
- **Token Validity:** 24 hours (configurable via `JWT_TOKEN_VALIDITY_HOURS` environment variable)
- **Token Format:** `Bearer <jwt_token>`
- **Token Claims:** Contains user `uid` (unique user identifier)

---

## Endpoints

### 1. Register

Creates a new user account and returns a JWT token for immediate authentication.

**Endpoint:** `POST /auth/register`

**Authentication:** Not required

**Request Body:**
```json
{
  "username": "johndoe",
  "name": "John Doe",
  "password": "securepassword123"
}
```

**Request Example:**
```http
POST /auth/register
Content-Type: application/json

{
  "username": "johndoe",
  "name": "John Doe",
  "password": "mypassword123"
}
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "id": 1,
  "uid": "abc123def456...",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "uid": "abc123def456...",
    "username": "johndoe",
    "name": "John Doe"
  }
}
```

**Response Fields:**
- `id`: Internal database ID of the created user
- `uid`: Unique user identifier (32-character hash)
- `token`: JWT token for authentication (use in `Authorization` header)
- `user`: Basic user information

**Error Responses:**

**400 Bad Request** - Invalid input:
```json
{
  "status": "error",
  "message": "username must be between 3 and 30 characters"
}
```

**400 Bad Request** - Password too short:
```json
{
  "status": "error",
  "message": "password must be at least 6 characters"
}
```

**409 Conflict** - Username already exists:
```json
{
  "status": "error",
  "message": "username already in use"
}
```

**500 Internal Server Error** - Server errors:
```json
{
  "status": "error",
  "message": "failed to create user"
}
```

**Common Error Messages:**
- `"username is required"` - Username field is missing or empty
- `"username must be between 3 and 30 characters"` - Username length validation failed
- `"username must contain only lowercase letters, numbers, and underscores"` - Username format validation failed
- `"name cannot be empty"` - Name field is missing or empty
- `"name must be less than 30 characters"` - Name length validation failed
- `"password must be at least 6 characters"` - Password too short
- `"username already in use"` - Username is already taken
- `"failed to check username availability"` - Database error checking username
- `"failed to process password"` - Password hashing error
- `"failed to create user"` - Database error creating user
- `"failed to generate authentication token"` - JWT token generation error

---

### 2. Login

Authenticates an existing user and returns a JWT token.

**Endpoint:** `POST /auth/login`

**Authentication:** Not required

**Request Body:**
```json
{
  "username": "johndoe",
  "password": "securepassword123"
}
```

**Request Example:**
```http
POST /auth/login
Content-Type: application/json

{
  "username": "johndoe",
  "password": "mypassword123"
}
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "uid": "abc123def456...",
    "username": "johndoe",
    "name": "John Doe"
  }
}
```

**Response Fields:**
- `token`: JWT token for authentication (use in `Authorization` header)
- `user`: Basic user information

**Error Responses:**

**400 Bad Request** - Missing fields:
```json
{
  "status": "error",
  "message": "username and password are required"
}
```

**401 Unauthorized** - Invalid credentials:
```json
{
  "status": "error",
  "message": "invalid username or password"
}
```

**500 Internal Server Error** - Server errors:
```json
{
  "status": "error",
  "message": "failed to authenticate"
}
```

**Common Error Messages:**
- `"username and password are required"` - Missing username or password
- `"invalid username or password"` - Username doesn't exist or password is incorrect
- `"failed to authenticate"` - Database error during authentication
- `"failed to generate authentication token"` - JWT token generation error

**Security Note:** The API returns the same error message (`"invalid username or password"`) for both non-existent users and incorrect passwords to prevent username enumeration attacks.

---

## Using JWT Tokens

After receiving a JWT token from registration or login, include it in all authenticated API requests using the `Authorization` header.

### Header Format

```
Authorization: Bearer <jwt_token>
```

### Example Request

```http
GET /users/self
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJhYmMxMjNkZWY0NTYiLCJleHAiOjE3MDk4NzY0MDAsImlhdCI6MTcwOTc5MDAwMH0.signature
```

### Token Expiration

- Tokens expire after **24 hours** by default
- When a token expires, you'll receive a `401 Unauthorized` response
- To continue accessing protected endpoints, you must **login again** to get a new token

### Token Validation

The backend validates tokens by:
1. Checking the `Authorization` header for a Bearer token
2. Verifying the token signature using the JWT secret
3. Checking token expiration
4. Extracting the user `uid` from token claims

---

## Validation Rules

### Username Validation

- **Length:** Must be between 3 and 30 characters (inclusive)
- **Format:** Must contain only:
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Underscores (_)
- **Case:** Automatically converted to lowercase
- **Whitespace:** Automatically trimmed
- **Regex Pattern:** `^[a-z0-9_]{3,30}$`
- **Uniqueness:** Must be unique across all users

**Valid Examples:**
- ✅ `johndoe`
- ✅ `user123`
- ✅ `test_user_99`
- ✅ `admin_2024`

**Invalid Examples:**
- ❌ `ab` (too short)
- ❌ `JohnDoe` (uppercase not allowed)
- ❌ `user-name` (hyphens not allowed)
- ❌ `user name` (spaces not allowed)
- ❌ `user@name` (special characters not allowed)

### Name Validation

- **Length:** Must be less than 30 characters
- **Required:** Cannot be empty
- **Whitespace:** Automatically trimmed

**Valid Examples:**
- ✅ `John Doe`
- ✅ `Jane Smith`
- ✅ `Admin User`

**Invalid Examples:**
- ❌ `` (empty string)
- ❌ `A very long name that exceeds thirty characters` (too long)

### Password Validation

- **Length:** Must be at least 6 characters
- **Required:** Cannot be empty
- **Storage:** Passwords are hashed using bcrypt before storage

**Valid Examples:**
- ✅ `password123`
- ✅ `SecurePass!`
- ✅ `123456`

**Invalid Examples:**
- ❌ `pass` (too short, less than 6 characters)
- ❌ `` (empty)

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
- `400 Bad Request`: Invalid request parameters or validation errors
- `401 Unauthorized`: Invalid credentials or expired token
- `409 Conflict`: Username already exists (registration only)
- `500 Internal Server Error`: Server-side errors

---

## Security Notes

### Password Security

- Passwords are **never stored in plain text**
- Passwords are hashed using **bcrypt** with default cost (10 rounds)
- Password hashes cannot be reversed to obtain original passwords
- Password comparison is done using secure hash comparison

### Token Security

- JWT tokens are signed using **HS256** (HMAC SHA-256)
- Token secret is stored in environment variable `JWT_SECRET`
- Tokens include expiration time to limit exposure window
- Tokens should be stored securely on the client side (e.g., secure storage, httpOnly cookies)

### Best Practices

1. **Always use HTTPS** in production to protect tokens in transit
2. **Store tokens securely** on the client (avoid localStorage for sensitive apps)
3. **Implement token refresh** mechanism for better UX (currently requires re-login)
4. **Validate inputs** on both client and server side
5. **Use strong passwords** (consider adding password strength requirements)
6. **Rate limit** authentication endpoints to prevent brute force attacks

### Environment Variables

Required environment variables:
- `JWT_SECRET`: Secret key for signing JWT tokens (required in production)
- `JWT_TOKEN_VALIDITY_HOURS`: Token validity duration in hours (optional, default: 24)

**Warning:** If `JWT_SECRET` is not set, a random secret is generated at startup. This is **not recommended for production** as the secret will change on each restart, invalidating all existing tokens.

---

## Example Workflow

### Complete Registration and Authentication Flow

```bash
# 1. Register a new user
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "name": "John Doe",
    "password": "mypassword123"
  }'

# Response:
# {
#   "status": "success",
#   "id": 1,
#   "uid": "abc123...",
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "user": { ... }
# }

# 2. Use the token to access protected endpoints
curl -X GET http://localhost:8080/users/self \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# 3. Login (if token expires or for new session)
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "password": "mypassword123"
  }'

# Response:
# {
#   "status": "success",
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "user": { ... }
# }
```

### JavaScript/TypeScript Example

```javascript
// Register
async function register(username, name, password) {
  const response = await fetch('http://localhost:8080/auth/register', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ username, name, password }),
  });
  
  const data = await response.json();
  if (data.status === 'success') {
    // Store token securely
    localStorage.setItem('token', data.token);
    return data;
  } else {
    throw new Error(data.message);
  }
}

// Login
async function login(username, password) {
  const response = await fetch('http://localhost:8080/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ username, password }),
  });
  
  const data = await response.json();
  if (data.status === 'success') {
    // Store token securely
    localStorage.setItem('token', data.token);
    return data;
  } else {
    throw new Error(data.message);
  }
}

// Make authenticated request
async function getSelf() {
  const token = localStorage.getItem('token');
  const response = await fetch('http://localhost:8080/users/self', {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });
  
  return await response.json();
}
```

---

## Changelog

- Initial API documentation created

