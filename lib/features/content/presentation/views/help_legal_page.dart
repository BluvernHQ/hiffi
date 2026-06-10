import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routes/app_router.dart';

class HelpLegalPage extends StatelessWidget {
  const HelpLegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Legal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Quick access to our policies and support resources.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 14),
          const _SectionHeader('LEGAL'),
          const _LinkTile(title: 'Terms of Use', slug: 'terms-of-use'),
          const _LinkTile(title: 'Payment Terms', slug: 'payment-terms'),
          const _LinkTile(title: 'Privacy Policy', slug: 'privacy-policy'),
          const SizedBox(height: 18),
          const _SectionHeader('SUPPORT'),
          const _RouteTile(title: 'My Reports', route: '/my-reports'),
          const _LinkTile(title: 'FAQ', slug: 'faq'),
          const _LinkTile(title: 'Support', slug: 'support'),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.92),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.slug});

  final String title;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openInBrowser(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.92),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final uri = AppRouter.contentUriForSlug(slug);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open browser link.')),
    );
  }
}
