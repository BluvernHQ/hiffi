import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';
import '../viewmodels/video_upload_view_model.dart';

class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({super.key});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  bool _isCheckingCreator = true;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    // Check if user is creator and clear any previous success/error state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkCreatorStatus();
      if (mounted) {
        context.read<VideoUploadViewModel>().clear();
      }
    });
  }

  Future<void> _checkCreatorStatus() async {
    try {
      final userRepository = context.read<UserRepository>();
      // Try to get current user - retry a few times for first-time creators
      UserModel? currentUser;
      int retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries) {
        try {
          currentUser = await userRepository.getCurrentUser();
          if (currentUser.role == 'creator') {
            break; // Found creator status, exit retry loop
          }
        } catch (e) {
          // If error, try again
        }

        // If not creator yet, wait a bit and retry (for first-time creators)
        if (currentUser?.role != 'creator' && retries < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        retries++;
      }

      if (mounted) {
        setState(() {
          _isCreator = currentUser != null && currentUser.role == 'creator';
          _isCheckingCreator = false;
        });

        // Redirect to become creator page if not a creator
        if (!_isCreator) {
          // Add a small delay to ensure navigation happens smoothly
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            context.go('/become-creator');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCheckingCreator = false;
        });
        // If error, still redirect to become creator page
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          context.go('/become-creator');
        }
      }
    }
  }

  void _showExitConfirmation(
    BuildContext context,
    VideoUploadViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Are you sure you want to leave? Any unsaved changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await viewModel.cancelUpload();
              viewModel.clear();
              Navigator.of(context).pop(); // Close dialog
              // If there's a route to pop back to, pop it
              // Otherwise, navigate to home
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking creator status
    if (_isCheckingCreator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Video')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If not creator, show nothing (will redirect)
    if (!_isCreator) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final viewModel = context.watch<VideoUploadViewModel>();

    // Don't auto-pop on success - let user see success message and action buttons
    // The success message will show with action buttons for "Upload Another Video" or "Go to Home"
    if (viewModel.shouldPopAfterSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        viewModel.consumePopRequest();
        // Refresh video list after successful upload
        context.read<VideoViewModel>().refresh();
        // Don't auto-pop - let user choose what to do next
      });
    }

    return PopScope(
      canPop:
          !viewModel.isUploading &&
          !viewModel.isQueued &&
          (viewModel.uploadStatus == UploadStatus.success ||
              !viewModel.hasData),
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If uploading or queued, prevent navigation
        if (viewModel.isUploading || viewModel.isQueued) {
          return;
        }

        // If upload was successful, allow navigation
        if (viewModel.uploadStatus == UploadStatus.success) {
          viewModel.clear();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
          return;
        }

        // If no data is filled, navigate to home without dialog
        if (!viewModel.hasData) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
          return;
        }

        // If data is filled, show exit confirmation dialog
        _showExitConfirmation(context, viewModel);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Video'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: viewModel.isUploading || viewModel.isQueued
                ? null
                : () {
                    if (viewModel.uploadStatus == UploadStatus.success) {
                      // If there's a route to pop back to, pop it
                      // Otherwise, navigate to home
                      viewModel.clear();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    } else if (!viewModel.hasData) {
                      // No data filled, navigate without dialog
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    } else {
                      // Data is filled, show confirmation
                      _showExitConfirmation(context, viewModel);
                    }
                  },
          ),
          actions: [
            if (viewModel.isUploading || viewModel.isQueued)
              TextButton.icon(
                onPressed: () async {
                  unawaited(
                    context.read<FirstPartyAnalyticsService>().capture(
                      r'$click',
                      elementUiName: 'upload-cancel-draft-button',
                      screenName: 'upload',
                    ),
                  );
                  await viewModel.cancelUpload();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Upload canceled'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Video Preview Section
                if (viewModel.selectedVideo != null) ...[
                  _VideoPreviewCard(
                    videoFile: viewModel.selectedVideo!,
                    thumbnailFile: viewModel.currentThumbnail,
                    isGeneratingThumbnail: viewModel.isGeneratingThumbnail,
                    hasCustomThumbnail: viewModel.selectedThumbnail != null,
                    showCustomBadge:
                        false, // Don't show custom badge when adding thumbnails
                    onThumbnailTap: viewModel.isUploading
                        ? null
                            : () {
                                unawaited(
                                  context
                                      .read<FirstPartyAnalyticsService>()
                                      .capture(
                                        r'$click',
                                        elementUiName:
                                            'upload-custom-thumbnail-button',
                                        screenName: 'upload',
                                      ),
                                );
                                viewModel.pickThumbnail();
                              },
                    onRemoveCustomThumbnail: viewModel.isUploading
                        ? null
                            : () {
                                unawaited(
                                  context
                                      .read<FirstPartyAnalyticsService>()
                                      .capture(
                                        r'$click',
                                        elementUiName:
                                            'upload-remove-thumbnail-button',
                                        screenName: 'upload',
                                      ),
                                );
                                viewModel.removeCustomThumbnail();
                              },
                    onReplaceVideo: viewModel.isUploading || viewModel.isQueued
                        ? null
                            : () {
                                unawaited(
                                  context
                                      .read<FirstPartyAnalyticsService>()
                                      .capture(
                                        r'$click',
                                        elementUiName: 'upload-select-files-button',
                                        screenName: 'upload',
                                      ),
                                );
                                viewModel.pickVideo();
                              },
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Video Selection Card (when no video selected)
                  _FileSelectionCard(
                    title: 'Video',
                    subtitle: 'Select your video file',
                    icon: Icons.videocam,
                    file: viewModel.selectedVideo,
                    onTap: viewModel.isUploading
                        ? null
                        : () {
                            unawaited(
                              context.read<FirstPartyAnalyticsService>().capture(
                                r'$click',
                                elementUiName: 'upload-select-files-button',
                                screenName: 'upload',
                              ),
                            );
                            viewModel.pickVideo();
                          },
                    isRequired: true,
                  ),
                  const SizedBox(height: 24),
                ],

                // Title Field
                Row(
                  children: [
                    Text(
                      'Title',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: viewModel.titleController,
                  enabled: !viewModel.isUploading,
                  decoration: InputDecoration(
                    hintText: 'Enter video title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),

                // Description Field
                Row(
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: viewModel.descriptionController,
                  enabled: !viewModel.isUploading,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tell viewers about your video...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),

                // Tags Field
                Row(
                  children: [
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (viewModel.tags.isEmpty)
                      Text(
                        '(Required)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...viewModel.tags.map(
                            (tag) => Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(fontSize: 13),
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              deleteIcon: Icon(
                                Icons.close,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              onDeleted: viewModel.isUploading
                                  ? null
                                  : () => viewModel.removeTag(tag),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                          if (viewModel.canAddMoreTags)
                            SizedBox(
                              width: double.infinity,
                              child: TextField(
                                controller: viewModel.tagInputController,
                                focusNode: viewModel.tagFocusNode,
                                enabled: !viewModel.isUploading,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: viewModel.tags.isEmpty
                                      ? 'Add tags (comma or semicolon separated, press Enter)'
                                      : 'Add more tags...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onChanged: (value) {
                                  // Auto-add tags when comma or semicolon is typed
                                  if (value.endsWith(',') ||
                                      value.endsWith(';')) {
                                    final tagToAdd = value
                                        .substring(0, value.length - 1)
                                        .trim();
                                    if (tagToAdd.isNotEmpty &&
                                        viewModel.canAddMoreTags) {
                                      viewModel.addTag(tagToAdd);
                                    }
                                  }
                                },
                                onSubmitted: (value) {
                                  if (!viewModel.isUploading &&
                                      value.trim().isNotEmpty &&
                                      viewModel.canAddMoreTags) {
                                    viewModel.addTag(value);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (viewModel.tags.isNotEmpty)
                            Text(
                              '${viewModel.tags.length} tag${viewModel.tags.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                            ),
                          if (viewModel.tags.isNotEmpty &&
                              !viewModel.canAddMoreTags) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Maximum tags reached (20)',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                              ),
                            ),
                          ] else if (viewModel.tags.isEmpty)
                            Expanded(
                              child: Text(
                                'Separate multiple tags with commas (e.g., gaming, funny, tutorial)',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.7),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Status Messages
                if (viewModel.uploadStatus == UploadStatus.success) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          'Upload Successful!',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          viewModel.successMessage ??
                              'Your video has been uploaded successfully.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withOpacity(0.9)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Clear form and allow another upload
                                  unawaited(
                                    context.read<FirstPartyAnalyticsService>().capture(
                                      r'$click',
                                      elementUiName: 'upload-another-video-button',
                                      screenName: 'upload_success',
                                    ),
                                  );
                                  viewModel.clear();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Upload Another Video'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  // Navigate to home
                                  unawaited(
                                    context.read<FirstPartyAnalyticsService>().capture(
                                      r'$click',
                                      elementUiName: 'upload-success-watch-video-button',
                                      screenName: 'upload_success',
                                    ),
                                  );
                                  viewModel.clear();
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/home');
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Go to Home'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (viewModel.uploadStatus == UploadStatus.canceled) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            viewModel.errorMessage ?? 'Upload canceled',
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (viewModel.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            viewModel.errorMessage ?? '',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (viewModel.isQueued) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your video is being uploaded in the background. '
                            'Upload will continue even if you close the app. '
                            'Notifications will appear when the app is in background.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Upload Progress Indicator
                if (viewModel.isUploading) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Uploading video...',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                            Text(
                              '${(viewModel.uploadProgressPercent * 100).toInt()}%',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: viewModel.uploadProgressPercent,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatBytes(viewModel.uploadProgress),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withOpacity(0.7),
                                  ),
                            ),
                            Text(
                              _formatBytes(viewModel.uploadTotal),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Upload Button
                FilledButton(
                  onPressed: viewModel.canUpload && !viewModel.isUploading
                      ? () async {
                          unawaited(
                            context.read<FirstPartyAnalyticsService>().capture(
                              r'$click',
                              elementUiName: 'upload-submit-video-button',
                              screenName: 'upload',
                            ),
                          );
                          final success = await viewModel.startUpload();
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Video upload started. '
                                  'Upload will continue even if you close the app.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 4),
                              ),
                            );
                            // Refresh video list after upload starts
                            context.read<VideoViewModel>().refresh();
                            // Go back to previous screen
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: viewModel.isUploading
                      ? const InlineShimmer(width: 20, height: 20)
                      : const Text(
                          'Upload Video',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({
    required this.videoFile,
    this.thumbnailFile,
    required this.isGeneratingThumbnail,
    required this.hasCustomThumbnail,
    this.showCustomBadge = true,
    this.onThumbnailTap,
    this.onRemoveCustomThumbnail,
    this.onReplaceVideo,
  });

  final File videoFile;
  final File? thumbnailFile;
  final bool isGeneratingThumbnail;
  final bool hasCustomThumbnail;
  final bool showCustomBadge;
  final VoidCallback? onThumbnailTap;
  final VoidCallback? onRemoveCustomThumbnail;
  final VoidCallback? onReplaceVideo;

  @override
  Widget build(BuildContext context) {
    final fileSize = videoFile.lengthSync();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video Thumbnail Preview
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: thumbnailFile != null
                      ? Image.file(
                          thumbnailFile!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.video_library,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: isGeneratingThumbnail
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Keep progress indicator for upload progress
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Generating thumbnail...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : Icon(
                                  Icons.video_library,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                        ),
                ),
                // Play Icon Overlay
                if (thumbnailFile != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_circle_filled,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                // Custom Thumbnail Badge
                if (hasCustomThumbnail && showCustomBadge)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Custom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Change Thumbnail Button
                if (onThumbnailTap != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onThumbnailTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasCustomThumbnail
                                    ? Icons.edit
                                    : Icons.add_photo_alternate,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasCustomThumbnail ? 'Change' : 'Add Thumbnail',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Remove Custom Thumbnail Button
                if (hasCustomThumbnail && onRemoveCustomThumbnail != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onRemoveCustomThumbnail,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Video Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '$fileSizeMB MB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (onReplaceVideo != null)
                  TextButton.icon(
                    onPressed: onReplaceVideo,
                    icon: Icon(
                      Icons.swap_horiz,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'Replace Video',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileSelectionCard extends StatelessWidget {
  const _FileSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.file,
    this.onTap,
    this.isRequired = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final dynamic file;
  final VoidCallback? onTap;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFile
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasFile
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFile
                        ? (file.path?.split('/').last ?? 'File selected')
                        : subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasFile
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check_circle : Icons.add_circle_outline,
              color: hasFile
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
