import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../viewmodels/video_upload_view_model.dart';

class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({super.key});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  @override
  void initState() {
    super.initState();
    // Clear any previous success/error state when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoUploadViewModel>().clear();
    });
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
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VideoUploadViewModel>();

    if (viewModel.shouldPopAfterSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        viewModel.consumePopRequest();
        // Clear the form immediately
        viewModel.clear();
        // Refresh video list after successful upload
        context.read<VideoViewModel>().refresh();
        // Pop without showing success message
        if (Navigator.of(context).canPop()) {
          context.pop();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: viewModel.isUploading
              ? null
              : () {
                  if (viewModel.uploadStatus == UploadStatus.success) {
                    context.pop();
                  } else {
                    _showExitConfirmation(context, viewModel);
                  }
                },
        ),
        actions: [
          if (viewModel.isUploading || viewModel.isQueued)
            TextButton.icon(
              onPressed: () async {
                await viewModel.cancelUpload();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Upload canceled'),
                    backgroundColor: Colors.orange,
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
                  onThumbnailTap: viewModel.isUploading
                      ? null
                      : () => viewModel.pickThumbnail(),
                  onRemoveCustomThumbnail: viewModel.isUploading
                      ? null
                      : () => viewModel.removeCustomThumbnail(),
                  onReplaceVideo: viewModel.isUploading || viewModel.isQueued
                      ? null
                      : () => viewModel.pickVideo(),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Video Selection Card (when no video selected)
                _FileSelectionCard(
                  title: 'Video',
                  subtitle: 'Select your video file',
                  icon: Icons.videocam,
                  file: viewModel.selectedVideo,
                  onTap: viewModel.isUploading ? null : viewModel.pickVideo,
                  isRequired: true,
                ),
                const SizedBox(height: 24),
              ],

              // Title Field
              Text(
                'Title',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
              Text(
                'Description',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
              Text(
                'Tags',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
                            label: Text(tag),
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
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: viewModel.tagInputController,
                            enabled: !viewModel.isUploading,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Add a tag and press Enter',
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) {
                              if (!viewModel.isUploading) {
                                viewModel.addTag(value);
                              }
                            },
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
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.successMessage ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (viewModel.uploadStatus == UploadStatus.canceled) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          viewModel.errorMessage ?? 'Upload canceled',
                          style: TextStyle(color: Colors.orange.shade900),
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
                                  color: Theme.of(context).colorScheme.primary,
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
                          // (will refresh again when upload completes)
                          context.read<VideoViewModel>().refresh();
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
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
    this.onThumbnailTap,
    this.onRemoveCustomThumbnail,
    this.onReplaceVideo,
  });

  final File videoFile;
  final File? thumbnailFile;
  final bool isGeneratingThumbnail;
  final bool hasCustomThumbnail;
  final VoidCallback? onThumbnailTap;
  final VoidCallback? onRemoveCustomThumbnail;
  final VoidCallback? onReplaceVideo;

  @override
  Widget build(BuildContext context) {
    final fileName = videoFile.path.split('/').last;
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
                if (hasCustomThumbnail)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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
