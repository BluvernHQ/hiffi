import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/upload/presentation/viewmodels/video_upload_view_model.dart';

class GlobalUploadOverlay extends StatelessWidget {
  const GlobalUploadOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoUploadViewModel>(
      builder: (context, viewModel, child) {
        final isUploading = viewModel.uploadStatus == UploadStatus.uploading;
        final isSuccess = viewModel.uploadStatus == UploadStatus.success;
        final isError = viewModel.uploadStatus == UploadStatus.error;

        if (!isUploading && !isSuccess && !isError) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: _getBackgroundColor(context, viewModel),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _getIcon(viewModel),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTitle(viewModel),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (viewModel.currentStageMessage != null && isUploading)
                              Text(
                                viewModel.currentStageMessage!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            if (isError)
                              Text(
                                viewModel.errorMessage ?? 'Unknown error',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (isUploading)
                        Text(
                          '${(viewModel.uploadProgressPercent * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      if (isSuccess || isError)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () {
                            if (isSuccess) viewModel.clearSuccess();
                            if (isError) viewModel.clearError();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: viewModel.uploadProgressPercent,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(BuildContext context, VideoUploadViewModel viewModel) {
    if (viewModel.uploadStatus == UploadStatus.success) return Colors.green;
    if (viewModel.uploadStatus == UploadStatus.error) return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  Widget _getIcon(VideoUploadViewModel viewModel) {
    if (viewModel.uploadStatus == UploadStatus.success) {
      return const Icon(Icons.check_circle, color: Colors.white);
    }
    if (viewModel.uploadStatus == UploadStatus.error) {
      return const Icon(Icons.error, color: Colors.white);
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  String _getTitle(VideoUploadViewModel viewModel) {
    if (viewModel.uploadStatus == UploadStatus.success) return 'Upload Complete';
    if (viewModel.uploadStatus == UploadStatus.error) return 'Upload Failed';
    return 'Uploading Video...';
  }
}

