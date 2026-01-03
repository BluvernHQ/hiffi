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
  String? _error;

  // Getters
  String get query => _query;
  List<UserModel> get userResults => _userResults;
  List<VideoModel> get videoResults => _videoResults;
  int get userCount => _userCount;
  int get videoCount => _videoCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasResults => _userResults.isNotEmpty || _videoResults.isNotEmpty;
  bool get hasNoResults => !_isLoading && _query.isNotEmpty && !hasResults;

  /// Search for both users and videos in parallel
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    _query = query.trim();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Search both users and videos in parallel
      final results = await Future.wait([
        _searchRepository.searchUsers(_query, limit: 50),
        _searchRepository.searchVideos(_query, limit: 100),
      ]);

      final userResult = results[0] as UserSearchResult;
      final videoResult = results[1] as VideoSearchResult;

      // Update current user's profile if they appear in search results
      final updatedUsers = await _updateCurrentUserProfile(userResult.users);

      _userResults = updatedUsers;
      _videoResults = videoResult.videos;
      _userCount = userResult.count;
      _videoCount = videoResult.count;
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchUsers(_query, limit: 50);

      // Update current user's profile if they appear in search results
      final updatedUsers = await _updateCurrentUserProfile(result.users);

      _userResults = updatedUsers;
      _userCount = result.count;
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _searchRepository.searchVideos(_query, limit: 100);
      _videoResults = result.videos;
      _videoCount = result.count;
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
        _searchRepository.searchUsers(query.trim(), limit: 5),
        _searchRepository.searchVideos(query.trim(), limit: 5),
      ]);

      final userResult = results[0] as UserSearchResult;
      final videoResult = results[1] as VideoSearchResult;

      // Update current user's profile if they appear in suggestions
      final updatedUsers = await _updateCurrentUserProfile(userResult.users);

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
    notifyListeners();
  }

  void clear() {
    _clearResults();
  }

  /// Updates the current user's profile in search results with latest data
  Future<List<UserModel>> _updateCurrentUserProfile(
    List<UserModel> users,
  ) async {
    // Check if user is logged in
    final authUser = _authRepository.currentUser;
    if (authUser == null || authUser.username == null) {
      return users; // Not logged in, return as-is
    }

    final currentUsername = authUser.username!.toLowerCase();

    // Find if current user is in the search results
    final currentUserIndex = users.indexWhere(
      (user) => user.username.toLowerCase() == currentUsername,
    );

    if (currentUserIndex == -1) {
      return users; // Current user not in results, return as-is
    }

    try {
      // Fetch latest profile for current user
      final latestProfile = await _userRepository.getCurrentUser();

      // Replace the search result with latest profile data
      final updatedUsers = List<UserModel>.from(users);
      updatedUsers[currentUserIndex] = latestProfile;

      print('✅ Updated current user profile in search results');
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
