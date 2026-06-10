import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/api_client.dart';
import '../../data/flag_repository.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  late final FlagRepository _repository;
  late Future<List<FlagCase>> _future;

  @override
  void initState() {
    super.initState();
    _repository = FlagRepository(apiClient: context.read<ApiClient>());
    _future = _repository.listMyFlags(limit: 50, offset: 0);
  }

  void _retry() {
    setState(() {
      _future = _repository.listMyFlags(limit: 50, offset: 0);
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
              context.go('/help-legal');
            }
          },
        ),
      ),
      body: FutureBuilder<List<FlagCase>>(
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
                    Text(
                      'Could not load reports',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
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
          final reports = snapshot.data ?? const <FlagCase>[];
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Text(
                  'My reports',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reports you have submitted for review. Use your case reference when contacting support.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                if (reports.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      'No reports yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.45,
                        ),
                      ),
                    ),
                    child: Column(
                      children: List.generate(reports.length, (index) {
                        final report = reports[index];
                        final ref = report.referenceId.isEmpty
                            ? report.id
                            : report.referenceId;
                        final row = InkWell(
                          onTap: report.referenceId.isEmpty
                              ? null
                              : () => context.push(
                                  '/my-reports/${Uri.encodeComponent(report.referenceId)}',
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ref,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_titleCase(report.reportType)} · ${_titleCase(report.reason.replaceAll('_', ' '))}',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _titleCase(
                                        report.status.replaceAll('_', ' '),
                                      ),
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'MMM d, y',
                                      ).format(report.createdAt.toLocal()),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        if (index == reports.length - 1) return row;
                        return Column(
                          children: [
                            row,
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.35),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final words = value.split(' ');
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
