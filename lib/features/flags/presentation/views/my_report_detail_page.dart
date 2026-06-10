import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/api_client.dart';
import '../../data/flag_repository.dart';

class MyReportDetailPage extends StatefulWidget {
  const MyReportDetailPage({super.key, required this.referenceId});

  final String referenceId;

  @override
  State<MyReportDetailPage> createState() => _MyReportDetailPageState();
}

class _MyReportDetailPageState extends State<MyReportDetailPage> {
  late final FlagRepository _repository;
  late Future<FlagCaseDetail> _future;

  @override
  void initState() {
    super.initState();
    _repository = FlagRepository(apiClient: context.read<ApiClient>());
    _future = _repository.getByReference(widget.referenceId);
  }

  void _retry() {
    setState(() {
      _future = _repository.getByReference(widget.referenceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/my-reports');
            }
          },
        ),
      ),
      body: FutureBuilder<FlagCaseDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 32),
                    const SizedBox(height: 10),
                    const Text('Could not load this report.'),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final report = snapshot.data!;
          final metadata = report.metadata.entries
              .where(
                (entry) =>
                    entry.value != null &&
                    entry.key.toLowerCase() != 'thumbnail_url' &&
                    entry.key.toLowerCase() != 'thumbnail',
              )
              .toList();
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                Text(
                  'Case ${report.referenceId}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Submitted ${DateFormat('MMMM d, y \'at\' h:mm a').format(report.createdAt.toLocal())}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _CardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              report.referenceId,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: report.referenceId),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reference copied'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy reference'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LabelValue(
                        label: 'Status',
                        value: _titleCase(report.status),
                      ),
                      const SizedBox(height: 10),
                      _LabelValue(
                        label: 'Type',
                        value: _titleCase(report.reportType),
                      ),
                      const SizedBox(height: 10),
                      _LabelValue(
                        label: 'Reason',
                        value: _titleCase(report.reason.replaceAll('_', ' ')),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () => _openReportedContent(report),
                        child: const Text('View reported content'),
                      ),
                    ],
                  ),
                ),
                if ((report.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CardSection(
                    title: 'Additional details',
                    child: Text(report.description!.trim()),
                  ),
                ],
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CardSection(
                    title: 'Captured context',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: metadata
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _MetadataValueRow(
                                label: entry.key,
                                value: entry.value,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openReportedContent(FlagCaseDetail report) async {
    final type = report.targetType.toLowerCase();
    if (type == 'video') {
      context.push('/watch/${report.targetId}');
      return;
    }
    if (type == 'user' || type == 'creator') {
      final username =
          (report.metadata['username']?.toString().trim().isNotEmpty ?? false)
          ? report.metadata['username'].toString().trim()
          : report.targetId;
      context.push('/users/$username');
      return;
    }
    if (type == 'comment') {
      final maybeVideoId = report.metadata['video_id']?.toString().trim();
      if (maybeVideoId != null && maybeVideoId.isNotEmpty) {
        context.push('/watch/$maybeVideoId');
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No direct route for this reported content yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final words = value.replaceAll('_', ' ').split(' ');
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title!,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetadataValueRow extends StatelessWidget {
  const _MetadataValueRow({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text('$label: $value', style: theme.textTheme.bodyMedium);
  }
}
