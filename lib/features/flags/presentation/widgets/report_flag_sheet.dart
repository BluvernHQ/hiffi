import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../data/flag_repository.dart';

class ReportFlagSheet extends StatefulWidget {
  const ReportFlagSheet({
    super.key,
    required this.title,
    required this.reportType,
    required this.targetId,
    required this.targetType,
    this.metadata = const {},
  });

  final String title;
  final String reportType;
  final String targetId;
  final String targetType;
  final Map<String, dynamic> metadata;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String reportType,
    required String targetId,
    required String targetType,
    Map<String, dynamic> metadata = const {},
  }) async {
    final result = await showModalBottomSheet<FlagSubmissionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportFlagSheet(
        title: title,
        reportType: reportType,
        targetId: targetId,
        targetType: targetType,
        metadata: metadata,
      ),
    );
    if (result == null || !context.mounted) return;
    await ReportSubmittedDialog.show(context, result: result);
  }

  @override
  State<ReportFlagSheet> createState() => _ReportFlagSheetState();
}

class _ReportFlagSheetState extends State<ReportFlagSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  late final FlagRepository _repository;
  bool _isLoadingConfig = true;
  bool _isSubmitting = false;
  String? _loadErrorMessage;
  String? _selectedReason;
  int _maxDescriptionLength = 500;
  List<String> _reasons = const ['other'];

  bool _isOtherReason(String? reason) =>
      (reason ?? '').trim().toLowerCase() == 'other';

  @override
  void initState() {
    super.initState();
    _repository = FlagRepository(apiClient: context.read<ApiClient>());
    _loadConfig();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _repository.getConfig();
      final typeConfig = config.config[widget.reportType];
      final reasons = (typeConfig?.reasons ?? const ['other'])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _reasons = reasons.isEmpty ? const ['other'] : reasons;
        _selectedReason = _reasons.first;
        _maxDescriptionLength = typeConfig?.maxDescriptionLength ?? 500;
        _isLoadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadErrorMessage = userFriendlyErrorMessage(
          e,
          fallback: 'Could not load report options. Please try again.',
        );
        _isLoadingConfig = false;
      });
    }
  }

  void _retryLoadConfig() {
    setState(() {
      _loadErrorMessage = null;
      _isLoadingConfig = true;
    });
    _loadConfig();
  }

  void _showSubmitErrorSnackBar(Object error) {
    final message = userFriendlyErrorMessage(
      error,
      fallback: 'Could not submit report. Please try again.',
    );
    final isOffline = isOfflineErrorMessage(message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) return;
    final description = _descriptionController.text.trim();
    if (_isOtherReason(reason) && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add details when selecting "other".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (description.length > _maxDescriptionLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Description is too long (max $_maxDescriptionLength).',
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await _repository.createFlag(
        reportType: widget.reportType,
        targetId: widget.targetId,
        targetType: widget.targetType,
        reason: reason,
        description: description,
        metadata: widget.metadata,
      );
      if (!mounted) return;
      unawaited(
        AnalyticsCapture.click(
          context,
          elementUiName: AnalyticsTags.reportSubmitted(widget.reportType),
          screenName: 'report',
          properties: {
            'report_type': widget.reportType,
            'target_type': widget.targetType,
            'target_id': widget.targetId,
            'reason': reason,
          },
        ),
      );
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSubmitErrorSnackBar(e);
    }
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildLoadErrorState(ThemeData theme) {
    final message = _loadErrorMessage!;
    final isOffline = isOfflineErrorMessage(message);
    final title = isOffline
        ? 'No internet connection'
        : 'Could not load report options';
    final subtitle = isOffline
        ? 'Please check your network and try again.'
        : message;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDragHandle(theme),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (isOffline
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer)
                  .withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 40,
              color: isOffline
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _retryLoadConfig,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requiresDetails = _isOtherReason(_selectedReason);
    final hasDetails = _descriptionController.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: _isLoadingConfig
              ? SizedBox(
                  height: 180,
                  child: Column(
                    children: [
                      _buildDragHandle(theme),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                )
              : _loadErrorMessage != null
              ? _buildLoadErrorState(theme)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDragHandle(theme),
                      Text(
                        'Report ${widget.title}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tell us what is wrong. Our moderation team will review this report.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reasons.map((reason) {
                          final selected = reason == _selectedReason;
                          return ChoiceChip(
                            label: Text(reason.replaceAll('_', ' ')),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedReason = reason),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: _maxDescriptionLength,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: requiresDetails
                              ? 'Additional details *'
                              : 'Additional details (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting || (requiresDetails && !hasDetails)
                              ? null
                              : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit report'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class ReportSubmittedDialog extends StatelessWidget {
  const ReportSubmittedDialog({super.key, required this.result});

  final FlagSubmissionResult result;

  static Future<void> show(
    BuildContext context, {
    required FlagSubmissionResult result,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportSubmittedDialog(result: result),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _copyReference(BuildContext context, String referenceId) async {
    await Clipboard.setData(ClipboardData(text: referenceId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reference copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceId = result.referenceId?.trim() ?? '';
    final statusLabel = _titleCase(result.status);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report submitted',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thank you for helping keep Hiffi safe. Save your case reference to track this report.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B6B6B),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF3F3F6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CASE REFERENCE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (referenceId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      referenceId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.15,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Status: $statusLabel',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 340;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/my-reports');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B6B6B),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View my reports'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (referenceId.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _copyReference(context, referenceId),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copy reference'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2B2B2B),
                                  side: const BorderSide(
                                    color: Color(0xFFD8D8DE),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          if (referenceId.isNotEmpty)
                            const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFED1C2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/my-reports');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B6B6B),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View my reports'),
                    ),
                    const Spacer(),
                    if (referenceId.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            _copyReference(context, referenceId),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy reference'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2B2B2B),
                          side: const BorderSide(color: Color(0xFFD8D8DE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFED1C2F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
