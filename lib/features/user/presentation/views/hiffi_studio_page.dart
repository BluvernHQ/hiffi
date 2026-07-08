import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../migration/data/migration_repository.dart';
import '../../../migration/domain/models/migration_request.dart';
import '../../../migration/presentation/widgets/migration_status_card.dart';
import '../../domain/models/user_model.dart';
import '../viewmodels/user_view_model.dart';
import 'edit_profile_page.dart';

const _studioRed = Color(0xFFED1C2F);
const _pageBackground = Color(0xFFFAFAFA);
const _cardBorder = Color(0xFFE8E8E8);
const _mutedText = Color(0xFF6B6B6B);
const _labelText = Color(0xFF9A9A9A);

class HiffiStudioPage extends StatefulWidget {
  const HiffiStudioPage({super.key});

  @override
  State<HiffiStudioPage> createState() => _HiffiStudioPageState();
}

class _HiffiStudioPageState extends State<HiffiStudioPage> {
  bool _isCheckingCreator = true;
  bool _isCreator = false;
  bool _isLoadingMigrationStatus = true;
  MigrationRequest? _migrationRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCreatorStatus());
  }

  Future<void> _loadMigrationStatus() async {
    setState(() => _isLoadingMigrationStatus = true);
    try {
      final request = await context.read<MigrationRepository>().getMyStatus();
      if (!mounted) return;
      setState(() {
        _migrationRequest = request;
        _isLoadingMigrationStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMigrationStatus = false);
    }
  }

  Future<void> _checkCreatorStatus() async {
    final viewModel = context.read<UserViewModel>();
    UserModel? user = viewModel.currentUser;
    if (user == null) {
      try {
        await viewModel.loadCurrentUser();
        user = viewModel.currentUser;
      } catch (_) {
        // Handled below.
      }
    }

    if (!mounted) return;

    final isCreator = user?.role == 'creator';
    setState(() {
      _isCreator = isCreator;
      _isCheckingCreator = false;
    });

    if (!isCreator) {
      context.go('/become-creator');
      return;
    }

    await _loadMigrationStatus();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _openUpload() {
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.creatorStudioUploadNewVideoButton,
        screenName: 'studio',
      ),
    );
    context.push('/upload/video');
  }

  void _openMigrate() {
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.creatorStudioStartMigrationButton,
        screenName: 'studio',
      ),
    );
    context.push('/studio/migrate');
  }

  void _openMigrationStatus() {
    context.push('/studio/migrate?status=1');
  }

  Future<void> _openCreatorProfile() async {
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.creatorStudioManageProfileButton,
        screenName: 'studio',
      ),
    );
    final user = context.read<UserViewModel>().currentUser;
    if (user == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: user),
      ),
    );
    if (!mounted) return;
    await context.read<UserViewModel>().loadCurrentUser();
  }

  void _openCreatorSupport() {
    context.push('/content/support');
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingCreator || !_isCreator) {
      return const Scaffold(
        backgroundColor: _pageBackground,
        body: Center(child: CircularProgressIndicator(color: _studioRed)),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: _studioRed,
          onRefresh: _loadMigrationStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hiffi Studio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  color: const Color(0xFF1A1A1A),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your space to publish and manage content on Hiffi.',
                style: TextStyle(
                  fontSize: 15,
                  color: _mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const _CreatorStatusCard(),
              const SizedBox(height: 16),
              _UploadVideoCard(onUpload: _openUpload),
              const SizedBox(height: 16),
              _MigrateContentCard(
                onMigrate: _openMigrate,
                hasActiveRequest: _migrationRequest?.blocksNewSubmission ?? false,
              ),
              if (_isLoadingMigrationStatus)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _studioRed,
                      ),
                    ),
                  ),
                )
              else if (_migrationRequest != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _openMigrationStatus,
                  child: MigrationStatusCard(
                    request: _migrationRequest!,
                    compact: true,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'CREATOR TOOLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: _labelText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CreatorToolCard(
                      icon: Icons.account_circle_outlined,
                      title: 'Creator Profile',
                      description: 'Update your bio, links, and branding.',
                      onTap: _openCreatorProfile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreatorToolCard(
                      icon: Icons.support_agent_outlined,
                      title: 'Creator Support',
                      description: 'Get help with uploads and account.',
                      onTap: _openCreatorSupport,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _CreatorStatusCard extends StatelessWidget {
  const _CreatorStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CREATOR STATUS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: _labelText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your channel is ready to publish.',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF1F9D55)),
                SizedBox(width: 6),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F9D55),
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

class _UploadVideoCard extends StatelessWidget {
  const _UploadVideoCard({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _studioRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.video_call_outlined,
              color: _studioRed,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload a Video',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share a new release with your audience and track its performance in real-time.',
            style: TextStyle(
              fontSize: 14,
              color: _mutedText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 20),
              label: const Text('Upload New Video'),
              style: FilledButton.styleFrom(
                backgroundColor: _studioRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MigrateContentCard extends StatelessWidget {
  const _MigrateContentCard({
    required this.onMigrate,
    required this.hasActiveRequest,
  });

  final VoidCallback onMigrate;
  final bool hasActiveRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sync_alt_rounded,
              color: Color(0xFF6B6B6B),
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Migrate Content',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Submit your YouTube channel or playlist for review. '
            'Our team migrates approved content manually (3–5 business days).',
            style: TextStyle(
              fontSize: 14,
              color: _mutedText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: hasActiveRequest ? null : onMigrate,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1A1A),
                side: const BorderSide(color: _cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                hasActiveRequest ? 'Request in progress' : 'Start migration',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorToolCard extends StatelessWidget {
  const _CreatorToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _studioRed, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: _mutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
