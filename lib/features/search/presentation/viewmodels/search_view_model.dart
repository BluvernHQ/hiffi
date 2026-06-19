import 'package:flutter/foundation.dart';

import '../../../../core/utils/network_error_utils.dart';
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
  int _userOffset = 0;
  int _videoOffset = 0;
  static const int _userPageLimit = 20;
  static const int _videoPageLimit = 20;
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
        _searchRepository.searchUsers(
          _query,
          offset: _userOffset,
          limit: _userPageLimit,
        ),
        _searchRepository.searchVideos(
          _query,
          offset: _videoOffset,
          limit: _videoPageLimit,
        ),
      ]);

      final userResult = results[0] as UserSearchResult;
      final videoResult = results[1] as VideoSearchResult;

      final uniqueUsers = _deduplicateUsersByUid(userResult.users);
      final updatedUsers = await _updateCurrentUserProfile(uniqueUsers);

      _userResults = updatedUsers;
      _videoResults = videoResult.videos;
      _userCount = userResult.count;
      _videoCount = videoResult.count;
      _userOffset = userResult.offset + userResult.users.length;
      _videoOffset = videoResult.offset + videoResult.videos.length;
      _hasMoreUsers = _hasMoreFromPage(
        returnedCount: userResult.users.length,
        limit: userResult.limit,
        loadedCount: _userResults.length,
        totalCount: userResult.count,
      );
      _hasMoreVideos = _hasMoreFromPage(
        returnedCount: videoResult.videos.length,
        limit: videoResult.limit,
        loadedCount: _videoResults.length,
        totalCount: videoResult.count,
      );
      _error = null;
    } catch (e) {
      _error = userFriendlyErrorMessage(
        e,
        fallback: 'Could not complete search. Please try again.',
      );
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
    _userOffset = 0;
    _hasMoreUsers = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchUsers(
        _query,
        offset: _userOffset,
        limit: _userPageLimit,
      );

      final uniqueUsers = _deduplicateUsersByUid(result.users);
      final updatedUsers = await _updateCurrentUserProfile(uniqueUsers);

      _userResults = updatedUsers;
      _userCount = result.count;
      _userOffset = result.offset + result.users.length;
      _hasMoreUsers = _hasMoreFromPage(
        returnedCount: result.users.length,
        limit: result.limit,
        loadedCount: _userResults.length,
        totalCount: result.count,
      );
      _error = null;
    } catch (e) {
      _error = userFriendlyErrorMessage(
        e,
        fallback: 'Could not search users. Please try again.',
      );
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
    _videoOffset = 0;
    _hasMoreVideos = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchVideos(
        _query,
        offset: _videoOffset,
        limit: _videoPageLimit,
      );
      _videoResults = result.videos;
      _videoCount = result.count;
      _videoOffset = result.offset + result.videos.length;
      _hasMoreVideos = _hasMoreFromPage(
        returnedCount: result.videos.length,
        limit: result.limit,
        loadedCount: _videoResults.length,
        totalCount: result.count,
      );
      _error = null;
    } catch (e) {
      _error = userFriendlyErrorMessage(
        e,
        fallback: 'Could not search videos. Please try again.',
      );
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
        _searchRepository.searchUsers(query.trim(), offset: 0, limit: 5),
        _searchRepository.searchVideos(query.trim(), offset: 0, limit: 5),
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
      final result = await _searchRepository.searchUsers(
        _query,
        offset: _userOffset,
        limit: _userPageLimit,
      );

      final merged = _deduplicateUsersByUid([..._userResults, ...result.users]);
      final updatedUsers = await _updateCurrentUserProfile(merged);

      _userResults = updatedUsers;
      _userCount = result.count;
      _userOffset = result.offset + result.users.length;
      _hasMoreUsers = _hasMoreFromPage(
        returnedCount: result.users.length,
        limit: result.limit,
        loadedCount: _userResults.length,
        totalCount: result.count,
      );
    } catch (e) {
      _error = userFriendlyErrorMessage(
        e,
        fallback: 'Could not load more users. Please try again.',
      );
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
      final result = await _searchRepository.searchVideos(
        _query,
        offset: _videoOffset,
        limit: _videoPageLimit,
      );

      final existingVideoIds = _videoResults.map((v) => v.videoId).toSet();
      final uniqueNewVideos = result.videos
          .where((video) => !existingVideoIds.contains(video.videoId))
          .toList();

      _videoResults = [..._videoResults, ...uniqueNewVideos];
      _videoCount = result.count;
      _videoOffset = result.offset + result.videos.length;
      _hasMoreVideos = _hasMoreFromPage(
        returnedCount: result.videos.length,
        limit: result.limit,
        loadedCount: _videoResults.length,
        totalCount: result.count,
      );
    } catch (e) {
      _error = userFriendlyErrorMessage(
        e,
        fallback: 'Could not load more videos. Please try again.',
      );
    } finally {
      _isLoadingMoreVideos = false;
      notifyListeners();
    }
  }

  void _resetPagination() {
    _userOffset = 0;
    _videoOffset = 0;
    _hasMoreUsers = true;
    _hasMoreVideos = true;
    _isLoadingMoreUsers = false;
    _isLoadingMoreVideos = false;
  }

  bool _hasMoreFromPage({
    required int returnedCount,
    required int limit,
    required int loadedCount,
    required int totalCount,
  }) {
    if (returnedCount == 0) return false;
    if (returnedCount < limit) return false;
    if (totalCount > loadedCount) return true;
    return returnedCount >= limit;
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
