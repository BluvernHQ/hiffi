import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../viewmodels/search_view_model.dart';

/// Search overlay widget that shows real-time suggestions (Twitch-style)
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onResultTap,
    required this.onViewAllResults,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final Function(VideoModel) onResultTap;
  final VoidCallback onViewAllResults;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  Timer? _debounceTimer;
  SearchSuggestions? _suggestions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) {
      _performSearch(widget.query);
    }
  }

  @override
  void didUpdateWidget(SearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _debounceSearch(widget.query);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debounceSearch(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = SearchSuggestions(users: [], videos: []);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = SearchSuggestions(users: [], videos: []);
        _isLoading = false;
      });
      return;
    }

    try {
      final searchViewModel = Provider.of<SearchViewModel>(
        context,
        listen: false,
      );
      final suggestions = await searchViewModel.getSuggestions(query);

      if (mounted && widget.query == query) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = SearchSuggestions(users: [], videos: []);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            : _suggestions == null || _suggestions!.isEmpty
            ? _buildNoResults()
            : _buildSuggestions(),
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _suggestions!;
    final allResults = <_SearchResultItem>[];

    // Add users
    for (final user in suggestions.users) {
      allResults.add(_SearchResultItem.user(user: user));
    }

    // Add videos
    for (final video in suggestions.videos) {
      allResults.add(_SearchResultItem.video(video: video));
    }

    // Limit to 8 total suggestions
    final limitedResults = allResults.take(8).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                '${limitedResults.length} ${limitedResults.length == 1 ? 'result' : 'results'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Results list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: limitedResults.length,
            itemBuilder: (context, index) {
              final item = limitedResults[index];
              return _SearchSuggestionTile(
                item: item,
                searchQuery: widget.query,
                onTap: () {
                  if (item.isVideo) {
                    widget.onResultTap(item.video!);
                  } else {
                    context.push('/users/${item.user!.username}');
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultItem {
  final UserModel? user;
  final VideoModel? video;

  _SearchResultItem.user({required this.user}) : video = null;
  _SearchResultItem.video({required this.video}) : user = null;

  bool get isVideo => video != null;
  bool get isUser => user != null;
}

class _SearchSuggestionTile extends StatelessWidget {
  const _SearchSuggestionTile({
    required this.item,
    required this.searchQuery,
    required this.onTap,
  });

  final _SearchResultItem item;
  final String searchQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon or thumbnail
            if (item.isVideo)
              _buildVideoThumbnail(context, item.video!)
            else
              _buildUserAvatar(context, item.user!),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isVideo)
                    _buildVideoTitle(context, item.video!)
                  else
                    _buildUserName(context, item.user!),
                  const SizedBox(height: 4),
                  if (item.isVideo)
                    _buildVideoMeta(context, item.video!)
                  else
                    _buildUserMeta(context, item.user!),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(BuildContext context, VideoModel video) {
    final thumbnailUrl = ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 60,
        height: 40,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: thumbnailUrl != null
            ? Image.network(
                thumbnailUrl,
                headers: ImageUtils.getVideoThumbnailHeaders(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.video_library,
                    size: 24,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                  );
                },
              )
            : Icon(
                Icons.video_library,
                size: 24,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, UserModel user) {
    final profileUrl = ImageUtils.getProfileImageUrl(
      user.profilePicture ?? user.avatarUrl ?? '',
    );

    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: profileUrl != null
          ? NetworkImage(
              profileUrl,
              headers: ImageUtils.getProfileImageHeaders(profileUrl),
            )
          : null,
      child:
          (user.profilePicture == null || user.profilePicture!.isEmpty) &&
              (user.avatarUrl == null || user.avatarUrl!.isEmpty)
          ? Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildVideoTitle(BuildContext context, VideoModel video) {
    return Text(
      video.videoTitle,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUserName(BuildContext context, UserModel user) {
    return Text(
      user.name,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildVideoMeta(BuildContext context, VideoModel video) {
    return Row(
      children: [
        Text(
          '@${video.userUsername.toLowerCase()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMeta(BuildContext context, UserModel user) {
    return Row(
      children: [
        Text(
          '@${user.username.toLowerCase()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        if (user.followers > 0) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.people,
            size: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Text(
            _formatCount(user.followers),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
