# Search Implementation Documentation

## Overview

The Hiffi platform implements a comprehensive search system that allows users to search for both videos and users simultaneously. The search functionality consists of two main components:

1. **Search Overlay** - Real-time suggestions dropdown (Twitch-style)
2. **Search Results Page** - Full search results with tabs for filtering

---

## Architecture

### Components Structure

```
app/
├── search/
│   └── page.tsx              # Full search results page
components/
├── search/
│   └── search-overlay.tsx    # Search dropdown overlay
lib/
└── api-client.ts             # API methods for search endpoints
```

---

## API Implementation

### Base URL
```
https://beta.hiffi.com/api
```

### Search Endpoints

#### 1. Search Users
**Endpoint:** `GET /search/users/{query}`

**Method:** `apiClient.searchUsers(query, limit)`

**Parameters:**
- `query` (string, required): Search query (URL encoded)
- `limit` (number, optional): Maximum number of results (default: 10)

**Authentication:** Not required

**Implementation:**
```typescript
async searchUsers(query: string, limit: number = 10): Promise<{
  success: boolean
  users: any[]
  count: number
}> {
  const response = await this.request<{
    success: boolean
    data?: {
      users: any[]
      count: number
      limit: number
      query: string
    }
  }>(`/search/users/${encodeURIComponent(query)}`, {}, false)
  
  if (response.success && response.data) {
    return {
      success: true,
      users: response.data.users || [],
      count: response.data.count || 0,
    }
  }
  
  return {
    success: false,
    users: [],
    count: 0,
  }
}
```

**Response Format:**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "uid": "string",
        "username": "string",
        "name": "string",
        "profile_picture": "string",
        "image": "string",
        "followers": 0,
        "following": 0,
        "total_videos": 0,
        "role": "user" | "creator",
        "created_at": "ISO8601",
        "updated_at": "ISO8601"
      }
    ],
    "count": 5,
    "limit": 50,
    "query": "john"
  }
}
```

---

#### 2. Search Videos
**Endpoint:** `GET /search/videos/{query}`

**Method:** `apiClient.searchVideos(query, limit)`

**Parameters:**
- `query` (string, required): Search query (URL encoded)
- `limit` (number, optional): Maximum number of results (default: 10)

**Authentication:** Not required

**Implementation:**
```typescript
async searchVideos(query: string, limit: number = 10): Promise<{
  success: boolean
  videos: any[]
  count: number
}> {
  const response = await this.request<{
    success: boolean
    data?: {
      videos: any[]
      count: number
      limit: number
      query: string
    }
  }>(`/search/videos/${encodeURIComponent(query)}`, {}, false)
  
  if (response.success && response.data) {
    return {
      success: true,
      videos: response.data.videos || [],
      count: response.data.count || 0,
    }
  }
  
  return {
    success: false,
    videos: [],
    count: 0,
  }
}
```

**Response Format:**
```json
{
  "success": true,
  "data": {
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
        "created_at": "ISO8601",
        "updated_at": "ISO8601"
      }
    ],
    "count": 10,
    "limit": 100,
    "query": "hip hop"
  }
}
```

**Search Capabilities:**
The backend search API handles:
- ✅ Title matching
- ✅ Description matching
- ✅ Tag-based searches (e.g., "hip hop", "rap")
- ✅ Fuzzy matching (handles variations like "hiphop" → "hip hop")
- ✅ Partial matches

---

## Component Implementation

### 1. Search Overlay (`components/search/search-overlay.tsx`)

**Purpose:** Provides real-time search suggestions in a dropdown overlay (similar to Twitch).

**Features:**
- Real-time search as you type (debounced: 400ms)
- Shows up to 8 suggestions (mix of users and videos)
- Keyboard navigation (Arrow keys, Enter, Escape)
- Clickable results for quick navigation
- Profile picture fetching with authentication
- Highlighted search terms in results

**State Management:**
```typescript
const [query, setQuery] = useState('')
const [suggestions, setSuggestions] = useState<SearchResult[]>([])
const [isLoading, setIsLoading] = useState(false)
const [selectedIndex, setSelectedIndex] = useState(-1)
const debounceTimerRef = useRef<NodeJS.Timeout | null>(null)
const previousBlobUrlsRef = useRef<Set<string>>(new Set())
```

**Search Flow:**
1. User types in search input
2. Query is debounced (400ms delay)
3. Parallel API calls: `searchUsers(query, 5)` and `searchVideos(query, 5)`
4. Results are combined and limited to 8 total suggestions
5. Profile pictures are fetched with authentication for users
6. Suggestions are displayed grouped by type (Users, Videos)

**Key Implementation Details:**
```typescript
// Debounced search effect
useEffect(() => {
  if (debounceTimerRef.current) {
    clearTimeout(debounceTimerRef.current)
  }

  if (query.trim().length > 0) {
    setIsLoading(true)
    debounceTimerRef.current = setTimeout(async () => {
      // Fetch both users and videos in parallel
      const [usersResponse, videosResponse] = await Promise.all([
        apiClient.searchUsers(searchQuery, 5).catch(() => ({ success: false, users: [], count: 0 })),
        apiClient.searchVideos(searchQuery, 5).catch(() => ({ success: false, videos: [], count: 0 })),
      ])
      
      // Combine and limit results
      const allSuggestions: SearchResult[] = []
      // ... process results
      setSuggestions(allSuggestions.slice(0, 8))
    }, 400)
  }
}, [query])
```

**Profile Picture Handling:**
- For Workers URLs, profile pictures are fetched with `x-api-key` header
- Blob URLs are created and tracked for cleanup
- Fallback to avatar initials if image fails to load

---

### 2. Search Results Page (`app/search/page.tsx`)

**Purpose:** Displays comprehensive search results with filtering options.

**Features:**
- Tabbed interface: All, Videos, Users
- Full search results (up to 100 videos, 50 users)
- Profile picture fetching with authentication
- Empty states for no results
- Loading states during search
- URL-based query persistence (`/search?q=query`)

**State Management:**
```typescript
const [videoResults, setVideoResults] = useState<any[]>([])
const [userResults, setUserResults] = useState<any[]>([])
const [videoCount, setVideoCount] = useState(0)
const [userCount, setUserCount] = useState(0)
const [loading, setLoading] = useState(false)
const [activeTab, setActiveTab] = useState<'all' | 'videos' | 'users'>('all')
const [userProfilePictures, setUserProfilePictures] = useState<Map<string, string>>(new Map())
```

**Search Flow:**
1. Query is extracted from URL params (`?q=query`)
2. On initial load, fetch both users and videos
3. Fetch profile pictures for all users with authentication
4. Display results in tabs (All, Videos, Users)
5. Handle empty states appropriately

**Key Implementation:**
```typescript
const fetchSearchResults = async (searchQuery: string, isInitialLoad: boolean = true) => {
  if (isInitialLoad) {
    // Search users (limit: 50)
    const usersResponse = await apiClient.searchUsers(searchQuery, 50)
    setUserResults(usersResponse.users || [])
    setUserCount(usersResponse.count || 0)
    
    // Fetch profile pictures with authentication
    const profilePictureMap = new Map<string, string>()
    await Promise.all(
      users.map(async (user: any) => {
        const profilePicUrl = getProfilePictureUrl({ profile_picture: user.profile_picture }, true)
        if (profilePicUrl.includes('black-paper-83cf.hiffi.workers.dev')) {
          const blobUrl = await fetchProfilePictureWithAuth(profilePicUrl)
          profilePictureMap.set(user.username, blobUrl)
        }
      })
    )
    setUserProfilePictures(profilePictureMap)
    
    // Search videos (limit: 100)
    const videosResponse = await apiClient.searchVideos(searchQuery, 100)
    setVideoResults(videosResponse.videos || [])
    setVideoCount(videosResponse.count || 0)
  }
}
```

**Tab Filtering:**
- **All Tab:** Shows both users and videos sections
- **Videos Tab:** Shows only video results using `VideoGrid` component
- **Users Tab:** Shows only user results in a card grid

---

## User Experience Flow

### Search Overlay Flow

1. **User clicks search icon in navbar**
   - Overlay opens with empty input
   - Trending searches are shown (if query is empty)

2. **User starts typing**
   - Input is debounced (400ms)
   - Loading indicator appears
   - API calls are made in parallel
   - Results appear grouped by type (Users, Videos)

3. **User interacts with results**
   - **Keyboard:** Arrow keys to navigate, Enter to select, Escape to close
   - **Mouse:** Click on any result to navigate
   - **"View all results"** button navigates to full search page

4. **User presses Enter (no selection)**
   - Navigates to `/search?q={query}` page

### Search Results Page Flow

1. **Page loads with query from URL**
   - Extracts query from `?q=query` parameter
   - Shows loading state
   - Fetches both users and videos

2. **Results display**
   - Default tab: "All" (shows both)
   - User can switch to "Videos" or "Users" tabs
   - Results are displayed with appropriate UI components

3. **No results**
   - Shows empty state with helpful message
   - Suggests checking spelling or trying different keywords

---

## Design Patterns

### 1. Debouncing
- **Purpose:** Reduce API calls while user is typing
- **Implementation:** 400ms delay before API call
- **Location:** Search Overlay component

### 2. Parallel API Calls
- **Purpose:** Fetch users and videos simultaneously for better performance
- **Implementation:** `Promise.all([searchUsers(), searchVideos()])`
- **Location:** Both Search Overlay and Search Results Page

### 3. Blob URL Management
- **Purpose:** Handle authenticated profile picture requests
- **Implementation:** 
  - Fetch image with `x-api-key` header
  - Create blob URL
  - Track blob URLs in refs
  - Cleanup on unmount/close
- **Location:** Both components

### 4. URL-based State
- **Purpose:** Persist search query in URL for shareability
- **Implementation:** Query stored in `?q=query` URL parameter
- **Location:** Search Results Page

### 5. Tabbed Filtering
- **Purpose:** Allow users to filter between videos and users
- **Implementation:** Radix UI Tabs component
- **Location:** Search Results Page

---

## Performance Optimizations

### 1. Debounced Search
- Prevents excessive API calls during typing
- 400ms delay balances responsiveness and efficiency

### 2. Parallel API Calls
- Users and videos fetched simultaneously
- Reduces total wait time

### 3. Limited Results in Overlay
- Only shows 5 users and 5 videos (8 total)
- Fast response time for suggestions

### 4. Result Caching
- Profile pictures are fetched once and stored in state
- Blob URLs are reused across renders

### 5. Cleanup on Unmount
- Blob URLs are properly revoked to prevent memory leaks
- Timers are cleared on component unmount

---

## Error Handling

### API Error Handling
```typescript
// Graceful degradation - continue even if one API call fails
const [usersResponse, videosResponse] = await Promise.all([
  apiClient.searchUsers(searchQuery, 5).catch(() => ({ success: false, users: [], count: 0 })),
  apiClient.searchVideos(searchQuery, 5).catch(() => ({ success: false, videos: [], count: 0 })),
])
```

### Profile Picture Error Handling
```typescript
try {
  const blobUrl = await fetchProfilePictureWithAuth(profilePicUrl)
  profilePictureMap.set(user.username, blobUrl)
} catch (error) {
  console.error('Failed to fetch profile picture:', error)
  // Falls back to avatar initials
}
```

### Empty State Handling
- Shows appropriate messages for no results
- Provides suggestions for better searches
- Allows user to "search anyway" from overlay

---

## Integration Points

### Navbar Integration
- Search icon triggers overlay
- Overlay is rendered at root level (portal)

### VideoGrid Component
- Used to display video results in search page
- Handles video card rendering with thumbnails

### ProfilePicture Component
- Used in search results for user avatars
- Handles authenticated profile picture fetching

### AuthenticatedImage Component
- Used for video thumbnails
- Handles authenticated image requests with `x-api-key` header

---

## API Request/Response Examples

### Search Users Example

**Request:**
```
GET /search/users/john
```

**Response:**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "uid": "abc123",
        "username": "john_doe",
        "name": "John Doe",
        "profile_picture": "ProfileProto/users/abc123.jpg",
        "followers": 150,
        "following": 50,
        "total_videos": 10,
        "role": "creator",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-12-19T00:00:00Z"
      }
    ],
    "count": 1,
    "limit": 50,
    "query": "john"
  }
}
```

### Search Videos Example

**Request:**
```
GET /search/videos/hip%20hop
```

**Response:**
```json
{
  "success": true,
  "data": {
    "videos": [
      {
        "video_id": "xyz789",
        "video_url": "videos/xyz789",
        "video_thumbnail": "thumbnails/videos/xyz789.jpg",
        "video_title": "Hip Hop Beats Mix",
        "video_description": "Best hip hop beats",
        "video_tags": ["hip hop", "rap", "beats"],
        "video_views": 5000,
        "video_upvotes": 120,
        "video_downvotes": 5,
        "video_comments": 25,
        "user_uid": "def456",
        "user_username": "producer123",
        "created_at": "2024-12-15T10:00:00Z",
        "updated_at": "2024-12-15T10:05:00Z"
      }
    ],
    "count": 1,
    "limit": 100,
    "query": "hip hop"
  }
}
```

---

## Testing Considerations

### Unit Tests
- API client methods
- Search result processing
- Profile picture URL generation

### Integration Tests
- Search overlay keyboard navigation
- Search results page tab switching
- URL query parameter handling

### E2E Tests
- Complete search flow from overlay to results
- Profile picture loading
- Empty state display
- Error handling

---

## Future Enhancements

1. **Pagination for Search Results**
   - Currently shows all results at once
   - Could add pagination for large result sets

2. **Search Filters**
   - Filter by date range
   - Filter by video tags
   - Filter by user role

3. **Search History**
   - Store recent searches in localStorage
   - Quick access to previous searches

4. **Autocomplete Suggestions**
   - Pre-populated suggestions based on popular searches
   - Trending searches displayed when empty

5. **Typo Correction**
   - "Did you mean?" suggestions
   - Automatic correction for common typos

6. **Advanced Search**
   - Boolean operators (AND, OR, NOT)
   - Field-specific search (title:, tag:, user:)
   - Date range filtering

---

## Summary

The search implementation provides a comprehensive, user-friendly search experience with:

- ✅ Real-time suggestions in overlay
- ✅ Full search results page with tabs
- ✅ Parallel API calls for performance
- ✅ Authenticated profile picture handling
- ✅ Keyboard navigation support
- ✅ Graceful error handling
- ✅ URL-based state persistence
- ✅ Efficient debouncing
- ✅ Proper resource cleanup

The architecture is scalable, maintainable, and follows React best practices with proper state management and component separation.