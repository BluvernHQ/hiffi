import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/migration_content_type.dart';
import '../../domain/models/migration_request.dart';

const _cardBorder = Color(0xFFE8E8E8);
const _mutedText = Color(0xFF6B6B6B);
const _labelText = Color(0xFF9A9A9A);

class MigrationStatusCard extends StatelessWidget {
  const MigrationStatusCard({
    super.key,
    required this.request,
    this.compact = false,
  });

  final MigrationRequest request;
  final bool compact;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = _statusBadge(request.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MIGRATION REQUEST',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: _labelText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badge.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) const SizedBox(height: 16),
          if (request.referenceId != null &&
              request.referenceId!.trim().isNotEmpty) ...[
            _DetailRow(
              label: 'Reference ID',
              child: SelectableText(
                request.referenceId!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _DetailRow(
            label: 'Submitted',
            child: Text(_dateFormat.format(request.createdAt.toLocal())),
          ),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'Platform',
            child: Text(request.platform.name.toUpperCase()),
          ),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'Content type',
            child: Text(extractContentTypeFromNote(request.note)),
          ),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'Channel URL',
            child: _ChannelUrlLink(url: request.channelUrl),
          ),
          if (request.status == MigrationStatus.rejected &&
              request.adminNotes != null &&
              request.adminNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF5C2C2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin notes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.adminNotes!.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7A271A),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 12),
            const Text(
              'Processing typically takes 3–5 business days.',
              style: TextStyle(fontSize: 13, color: _mutedText, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _mutedText),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ChannelUrlLink extends StatelessWidget {
  const _ChannelUrlLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Text(
        url,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

({String label, Color background, Color foreground}) _statusBadge(
  MigrationStatus status,
) {
  return switch (status) {
    MigrationStatus.pending => (
      label: status.label,
      background: const Color(0xFFF3F3F3),
      foreground: const Color(0xFF6B6B6B),
    ),
    MigrationStatus.underReview => (
      label: status.label,
      background: const Color(0xFFE8F0FE),
      foreground: const Color(0xFF1A56DB),
    ),
    MigrationStatus.approved => (
      label: status.label,
      background: const Color(0xFFE8F8EE),
      foreground: const Color(0xFF1F9D55),
    ),
    MigrationStatus.completed => (
      label: status.label,
      background: const Color(0xFFE8F8EE),
      foreground: const Color(0xFF1F9D55),
    ),
    MigrationStatus.rejected => (
      label: status.label,
      background: const Color(0xFFFFF0F0),
      foreground: const Color(0xFFB42318),
    ),
  };
}

class MigrationNextSteps extends StatelessWidget {
  const MigrationNextSteps({super.key});

  static const _steps = [
    ('Submit request', 'Share your channel URL and content details.'),
    ('Team review', 'We verify your content and rights.'),
    ('Content goes live', 'Approved content is published on Hiffi.'),
    ('You are notified', 'Status updates are sent to your account.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT HAPPENS NEXT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: _labelText,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFED1C2F).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFED1C2F),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _steps[i].$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i < _steps.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
