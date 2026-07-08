import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/utils/error_toast_utils.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/utils/youtube_url.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../data/migration_repository.dart';
import '../../domain/models/migration_content_type.dart';
import '../../domain/models/migration_request.dart';
import '../widgets/migration_status_card.dart';

const _studioRed = Color(0xFFED1C2F);
const _pageBackground = Color(0xFFFAFAFA);
const _cardBorder = Color(0xFFE8E8E8);
const _mutedText = Color(0xFF6B6B6B);
const _labelText = Color(0xFF9A9A9A);

class MigrateContentPage extends StatefulWidget {
  const MigrateContentPage({super.key, this.scrollToStatusOnLoad = false});

  /// When true, scrolls to the status section after the first frame.
  final bool scrollToStatusOnLoad;

  @override
  State<MigrateContentPage> createState() => _MigrateContentPageState();
}

class _MigrateContentPageState extends State<MigrateContentPage> {
  final _urlController = TextEditingController();
  final _scrollController = ScrollController();
  final _statusSectionKey = GlobalKey();

  bool _isCheckingCreator = true;
  bool _isCreator = false;
  bool _isLoadingStatus = true;
  bool _isSubmitting = false;
  String? _statusError;
  MigrationRequest? _existingRequest;

  MigrationContentType _contentType = MigrationContentType.musicVideos;
  bool _ownershipConfirmed = false;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkCreatorStatus();
      if (!mounted) return;
      await _loadStatus();
      if (widget.scrollToStatusOnLoad && _existingRequest != null) {
        _scrollToStatus();
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    }
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoadingStatus = true;
      _statusError = null;
    });
    try {
      final request = await context.read<MigrationRepository>().getMyStatus();
      if (!mounted) return;
      setState(() {
        _existingRequest = request;
        _isLoadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStatus = false;
        _statusError = userFriendlyErrorMessage(
          e,
          fallback: 'Could not load migration status.',
        );
      });
    }
  }

  void _scrollToStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _statusSectionKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  bool get _canSubmitForm =>
      !_isLoadingStatus &&
      (_existingRequest == null || !_existingRequest!.blocksNewSubmission);

  String? _validateUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Enter a YouTube channel or playlist URL.';
    }
    if (!isValidYoutubeUrl(trimmed)) {
      return 'Enter a supported YouTube channel or playlist URL.';
    }
    return null;
  }

  Future<bool> _confirmSubmit(String url) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Submit migration request?'),
          content: Text(
            'You are submitting migration from\n$url\nto Hiffi.\n\n'
            'Request cannot be cancelled or modified until migration completes.\n'
            'Team may contact you for clarification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _studioRed),
              child: const Text('Yes, submit request'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _submit() async {
    final urlError = _validateUrl(_urlController.text);
    if (urlError != null) {
      setState(() => _urlError = urlError);
      return;
    }
    if (!_ownershipConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please confirm you own or have rights to migrate this content.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final url = _urlController.text.trim();
    final confirmed = await _confirmSubmit(url);
    if (!confirmed || !mounted) return;

    final username =
        context.read<UserViewModel>().currentUser?.username ?? '';

    setState(() => _isSubmitting = true);
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.creatorStudioStartMigrationSubmitButton,
        screenName: 'studio_migrate',
      ),
    );

    try {
      final request = await context.read<MigrationRepository>().submitRequest(
        channelUrl: url,
        artistName: username,
        contentType: _contentType,
      );
      if (!mounted) return;
      setState(() {
        _existingRequest = request;
        _isSubmitting = false;
        _urlController.clear();
        _ownershipConfirmed = false;
        _urlError = null;
      });
      _scrollToStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.referenceId != null
                ? 'Request submitted. Reference: ${request.referenceId}'
                : 'Migration request submitted.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (e is ApiException && e.statusCode == 409) {
        await _loadStatus();
        _scrollToStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request already exists'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      showCatchToast(
        context,
        e,
        fallback: 'Could not submit migration request. Please try again.',
      );
    }
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
          onRefresh: _loadStatus,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Migrate Content',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submit your YouTube channel or playlist for manual migration '
                  'by the Hiffi team. Processing takes 3–5 business days.',
                  style: TextStyle(fontSize: 15, color: _mutedText, height: 1.45),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _statusSectionKey,
                  child: _buildStatusSection(),
                ),
                if (_canSubmitForm) ...[
                  const SizedBox(height: 20),
                  _buildFormSection(),
                ],
                const SizedBox(height: 20),
                const MigrationNextSteps(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    if (_isLoadingStatus) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: _studioRed),
        ),
      );
    }

    if (_statusError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Text(_statusError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadStatus, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_existingRequest == null) {
      return const SizedBox.shrink();
    }

    return MigrationStatusCard(request: _existingRequest!);
  }

  Widget _buildFormSection() {
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
          Text(
            'REQUEST DETAILS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: _labelText,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'YouTube Channel / Playlist URL',
              hintText: 'https://www.youtube.com/@yourhandle',
              helperText:
                  'Accepts channel URLs (@handle, /channel/…) or playlist URLs.',
              errorText: _urlError,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onChanged: (_) {
              if (_urlError != null) setState(() => _urlError = null);
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Content type',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MigrationContentType.values.map((type) {
              final selected = _contentType == type;
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) => setState(() => _contentType = type),
                selectedColor: _studioRed.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: selected ? _studioRed : const Color(0xFF1A1A1A),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? _studioRed : _cardBorder,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _ownershipConfirmed,
            onChanged: (value) =>
                setState(() => _ownershipConfirmed = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I confirm that I own or have the necessary rights to migrate and '
              'publish this content on Hiffi.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            activeColor: _studioRed,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _studioRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit migration request',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
