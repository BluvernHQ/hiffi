import 'package:flutter/foundation.dart';

import '../../data/search_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../video/domain/models/video_model.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required SearchRepository searchRepository,
    required UserRepository userRepository,
    required AuthRepository authRepository,
  }) : _searchRepository = searchRepository,
       _userRepository = userRepository,
       _authRepository = authRepository;

  final SearchRepository _searchRepository;
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  // Search state
  String _query = '';
  List<UserModel> _userResults = [];
  List<VideoModel> _videoResults = [];
  int _userCount = 0;
  int _videoCount = 0;
  bool _isLoading = false;
  bool _isLoadingMoreUsers = false;
  bool _isLoadingMoreVideos = false;
  String? _error;
  int _userPage = 1;
  int _videoPage = 1;
  static const int _userPageLimit = 50;
  static const int _videoPageLimit = 30;
  bool _hasMoreUsers = true;
  bool _hasMoreVideos = true;

  // Getters
  String get query => _query;
  List<UserModel> get userResults => _userResults;
  List<VideoModel> get videoResults => _videoResults;
  int get userCount => _userCount;
  int get videoCount => _videoCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreUsers => _isLoadingMoreUsers;
  bool get isLoadingMoreVideos => _isLoadingMoreVideos;
  String? get error => _error;
  bool get hasResults => _userResults.isNotEmpty || _videoResults.isNotEmpty;
  bool get hasNoResults => !_isLoading && _query.isNotEmpty && !hasResults;
  bool get hasMoreUsers => _hasMoreUsers;
  bool get hasMoreVideos => _hasMoreVideos;

  /// Search for both users and videos in parallel
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    _query = query.trim();
    _resetPagination();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Search both users and videos in parallel
      final results = await Future.wait([
        _searchRepository.searchUsers(_query, page: _userPage, limit: _userPageLimit),
        _searchRepository.searchVideos(
          _query,
          page: _videoPage,
          limit: _videoPageLimit,
        ),
      ]);

      final userResult = results[0] as UserSearchResult;
      final videoResult = results[1] as VideoSearchResult;

      // Deduplicate users by UID to prevent showing the same user twice
      final uniqueUsers = _deduplicateUsersByUid(userResult.users);

      // Update current user's profile if they appear in search results
      final updatedUsers = await _updateCurrentUserProfile(uniqueUsers);

      // Use the actual deduplicated count, not the API count
      // This ensures we only show what we actually have
      _userResults = updatedUsers;
      _videoResults = videoResult.videos;
      _userCount = updatedUsers.length; // Use actual displayed count
      _videoCount = videoResult.count;
      _hasMoreUsers = updatedUsers.length >= _userPageLimit;
      _hasMoreVideos = videoResult.videos.length >= _videoPageLimit;
      _error = null;
    } catch (e) {
      _error = 'Failed to search: ${e.toString()}';
      _userResults = [];
      _videoResults = [];
      _userCount = 0;
      _videoCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search only users
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _userResults = [];
      _userCount = 0;
      notifyListeners();
      return;
    }

    _query = query.trim();
    _userPage = 1;
    _hasMoreUsers = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchUsers(
        _query,
        page: _userPage,
        limit: _userPageLimit,
      );

      // Deduplicate users by UID to prevent showing the same user twice
      final uniqueUsers = _deduplicateUsersByUid(result.users);

      // Update current user's profile if they appear in search results
      final updatedUsers = await _updateCurrentUserProfile(uniqueUsers);

      // Use the actual deduplicated count, not the API count
      _userResults = updatedUsers;
      _userCount = updatedUsers.length; // Use actual displayed count
      _hasMoreUsers = updatedUsers.length >= _userPageLimit;
      _error = null;
    } catch (e) {
      _error = 'Failed to search users: ${e.toString()}';
      _userResults = [];
      _userCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search only videos
  Future<void> searchVideos(String query) async {
    if (query.trim().isEmpty) {
      _videoResults = [];
      _videoCount = 0;
      notifyListeners();
      return;
    }

    _query = query.trim();
    _videoPage = 1;
    _hasMoreVideos = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchVideos(
        _query,
        page: _videoPage,
        limit: _videoPageLimit,
      );
      _videoResults = result.videos;
      _videoCount = result.count;
      _hasMoreVideos = result.videos.length >= _videoPageLimit;
      _error = null;
    } catch (e) {
      _error = 'Failed to search videos: ${e.toString()}';
      _videoResults = [];
      _videoCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get suggestions for search overlay (limited results)
  Future<SearchSuggestions> getSuggestions(String query) async {
    if (query.trim().isEmpty) {
      return SearchSuggestions(users: [], videos: []);
    }

    try {
      // Get limited results for suggestions (5 users, 5 videos)
      final results = await Future.wait([
        _searchRepository.searchUsers(query.trim(), page: 1, limit: 5),
        _searchRepository.searchVideos(query.trim(), page: 1, limit: 5),
      ]);

      final userResult = results[0] as UserSearchResult;
      final videoResult = results[1] as VideoSearchResult;

      // Deduplicate users by UID to prevent showing the same user twice
      final uniqueUsers = _deduplicateUsersByUid(userResult.users);

      // Update current user's profile if they appear in suggestions
      final updatedUsers = await _updateCurrentUserProfile(uniqueUsers);

      return SearchSuggestions(users: updatedUsers, videos: videoResult.videos);
    } catch (e) {
      print('Error getting suggestions: $e');
      return SearchSuggestions(users: [], videos: []);
    }
  }

  void _clearResults() {
    _query = '';
    _userResults = [];
    _videoResults = [];
    _userCount = 0;
    _videoCount = 0;
    _isLoading = false;
    _error = null;
    _resetPagination();
    notifyListeners();
  }

  Future<void> loadMoreUsers() async {
    if (_query.isEmpty || _isLoading || _isLoadingMoreUsers || !_hasMoreUsers) {
      return;
    }

    _isLoadingMoreUsers = true;
    notifyListeners();

    try {
      final nextPage = _userPage + 1;
      final result = await _searchRepository.searchUsers(
        _query,
        page: nextPage,
        limit: _userPageLimit,
      );

      final merged = _deduplicateUsersByUid([..._userResults, ...result.users]);
      final updatedUsers = await _updateCurrentUserProfile(merged);

      _userPage = nextPage;
      _userResults = updatedUsers;
      _userCount = updatedUsers.length;
      _hasMoreUsers = result.users.length >= _userPageLimit;
    } catch (e) {
      _error = 'Failed to load more users: ${e.toString()}';
    } finally {
      _isLoadingMoreUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreVideos() async {
    if (_query.isEmpty || _isLoading || _isLoadingMoreVideos || !_hasMoreVideos) {
      return;
    }

    _isLoadingMoreVideos = true;
    notifyListeners();

    try {
      final nextPage = _videoPage + 1;
      final result = await _searchRepository.searchVideos(
        _query,
        page: nextPage,
        limit: _videoPageLimit,
      );

      final existingVideoIds = _videoResults.map((v) => v.videoId).toSet();
      final uniqueNewVideos = result.videos
          .where((video) => !existingVideoIds.contains(video.videoId))
          .toList();

      _videoPage = nextPage;
      _videoResults = [..._videoResults, ...uniqueNewVideos];
      _videoCount = _videoResults.length;
      _hasMoreVideos = result.videos.length >= _videoPageLimit;
    } catch (e) {
      _error = 'Failed to load more videos: ${e.toString()}';
    } finally {
      _isLoadingMoreVideos = false;
      notifyListeners();
    }
  }

  void _resetPagination() {
    _userPage = 1;
    _videoPage = 1;
    _hasMoreUsers = true;
    _hasMoreVideos = true;
    _isLoadingMoreUsers = false;
    _isLoadingMoreVideos = false;
  }

  void clear() {
    _clearResults();
  }

  /// Deduplicates users by UID to prevent showing the same user twice
  /// Only removes true duplicates (same UID), keeps all unique users from API
  List<UserModel> _deduplicateUsersByUid(List<UserModel> users) {
    final seenUids = <String>{};
    final uniqueUsers = <UserModel>[];

    print('🔍 Deduplicating ${users.length} users from API...');

    for (final user in users) {
      // Use UID if available, otherwise fall back to username
      final identifier = user.uid ?? user.username;

      if (!seenUids.contains(identifier)) {
        seenUids.add(identifier);
        uniqueUsers.add(user);
      } else {
        print(
          '⚠️ Duplicate user removed: ${user.username} (UID: ${user.uid}) - already seen',
        );
      }
    }

    print(
      '✅ Deduplication complete: ${uniqueUsers.length} unique users (removed ${users.length - uniqueUsers.length} duplicates)',
    );
    return uniqueUsers;
  }

  /// Updates the current user's profile in search results with latest data
  /// IMPORTANT: This only REPLACES an existing user, never adds a new one
  Future<List<UserModel>> _updateCurrentUserProfile(
    List<UserModel> users,
  ) async {
    // Check if user is logged in
    final authUser = _authRepository.currentUser;
    if (authUser == null) {
      return users; // Not logged in, return as-is
    }

    // Try to match by UID first (more reliable), then fall back to username
    final currentUid = authUser.uid;
    final currentUsername = authUser.username?.toLowerCase();

    int currentUserIndex = -1;

    // Match by UID if available and not empty (most reliable)
    if (currentUid.isNotEmpty) {
      currentUserIndex = users.indexWhere(
        (user) => user.uid != null && user.uid == currentUid,
      );
    }

    // Fall back to username if UID match failed
    // Note: If multiple users have the same username, this will only match the first one
    if (currentUserIndex == -1 && currentUsername != null) {
      currentUserIndex = users.indexWhere(
        (user) => user.username.toLowerCase() == currentUsername,
      );
    }

    if (currentUserIndex == -1) {
      return users; // Current user not in results, return as-is
    }

    try {
      // Fetch latest profile for current user
      final latestProfile = await _userRepository.getCurrentUser();

      // IMPORTANT: Only replace, never add - ensure we maintain the same list length
      final updatedUsers = List<UserModel>.from(users);
      if (currentUserIndex >= 0 && currentUserIndex < updatedUsers.length) {
        updatedUsers[currentUserIndex] = latestProfile;
        print(
          '✅ Updated current user profile in search results (replaced at index $currentUserIndex)',
        );
      } else {
        print('⚠️ Invalid index for current user update: $currentUserIndex');
        return users; // Return original if index is invalid
      }

      // Verify we didn't accidentally change the list length
      if (updatedUsers.length != users.length) {
        print(
          '⚠️ ERROR: List length changed during profile update! Original: ${users.length}, Updated: ${updatedUsers.length}',
        );
        return users; // Return original if length changed
      }

      return updatedUsers;
    } catch (e) {
      print('⚠️ Failed to fetch latest profile for current user: $e');
      // Return original results if fetch fails
      return users;
    }
  }
}

/// Model for search suggestions (used in overlay)
class SearchSuggestions {
  final List<UserModel> users;
  final List<VideoModel> videos;

  SearchSuggestions({required this.users, required this.videos});

  int get totalCount => users.length + videos.length;
  bool get isEmpty => users.isEmpty && videos.isEmpty;
}
