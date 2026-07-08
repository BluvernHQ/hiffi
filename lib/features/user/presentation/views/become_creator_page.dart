import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/error_toast_utils.dart';
import '../../../../core/widgets/otp_code_input.dart';
import '../viewmodels/user_view_model.dart';
import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';

class BecomeCreatorPage extends StatefulWidget {
  const BecomeCreatorPage({super.key});

  @override
  State<BecomeCreatorPage> createState() => _BecomeCreatorPageState();
}

class _BecomeCreatorPageState extends State<BecomeCreatorPage> {
  final _otpController = TextEditingController();
  bool _isBusy = false;
  bool _showOtpStep = false;
  String? _otpMessage;
  int _resendTimer = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  bool get _canResendOtp => _resendTimer == 0 && !_isBusy;

  Future<void> _requestUpgrade() async {
    final viewModel = context.read<UserViewModel>();
    final user = viewModel.currentUser;
    final email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      if (!mounted) return;
      final addEmail = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Email required'),
          content: const Text(
            'Add an email to your profile before upgrading to creator. '
            'We will send a verification code to that address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to profile'),
            ),
          ],
        ),
      );
      if (addEmail == true && mounted && user != null) {
        context.push('/users/${user.username}');
      }
      return;
    }

    setState(() => _isBusy = true);
    try {
      unawaited(
        AnalyticsCapture.click(
          context,
          elementUiName: AnalyticsTags.creatorBecomeCreatorButton,
          screenName: 'become_creator',
        ),
      );
      final result = await viewModel.requestCreatorUpgrade();
      if (!mounted) return;
      setState(() {
        _showOtpStep = true;
        _otpMessage = result.message;
      });
      _startResendTimer();
    } catch (error) {
      if (!mounted) return;
      showCatchToast(
        context,
        error,
        fallback: 'Could not start creator upgrade. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyUpgrade() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the verification code from your email.')),
      );
      return;
    }

    final viewModel = context.read<UserViewModel>();
    setState(() => _isBusy = true);
    try {
      await viewModel.verifyCreatorUpgrade(otp: otp);
      await viewModel.loadCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Congratulations! You are now a creator'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) context.go('/studio');
    } catch (error) {
      if (!mounted) return;
      showCatchToast(
        context,
        error,
        fallback: 'Could not verify creator upgrade. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResendOtp) return;
    await _requestUpgrade();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const primaryColor = Color(0xFFED1C2F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, size: 48, color: primaryColor),
              ),
              const SizedBox(height: 32),
              Text(
                _showOtpStep ? 'Verify your email' : 'Become a Hiffi Creator',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _showOtpStep
                    ? (_otpMessage ??
                          'Enter the verification code sent to your registered email.')
                    : 'Unlock the power to upload videos, build your audience, and share your creativity with the world',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_showOtpStep) ...[
                const SizedBox(height: 48),
                const _BenefitCard(
                  icon: Icons.videocam_outlined,
                  title: 'Upload Videos',
                  description:
                      'Share your content, tutorials, music, and more with the Hiffi community',
                  color: primaryColor,
                ),
                const SizedBox(height: 20),
                const _BenefitCard(
                  icon: Icons.trending_up_outlined,
                  title: 'Grow Your Audience',
                  description:
                      'Build followers, get views, and engage with your community through comments and interactions',
                  color: primaryColor,
                ),
                const SizedBox(height: 20),
                const _BenefitCard(
                  icon: Icons.bolt_outlined,
                  title: 'Creator Features',
                  description:
                      'Access exclusive creator tools and features to enhance your content and reach',
                  color: primaryColor,
                ),
                const SizedBox(height: 48),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Start Creating?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We will email a verification code to confirm your upgrade to creator.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 32),
                OtpCodeInput(
                  controller: _otpController,
                  enabled: !_isBusy,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _canResendOtp ? _resendOtp : null,
                  child: Text(
                    _canResendOtp
                        ? 'Resend code'
                        : 'Resend in ${_resendTimer}s',
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBusy
                      ? null
                      : (_showOtpStep ? _verifyUpgrade : _requestUpgrade),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isBusy
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showOtpStep ? Icons.verified_outlined : Icons.bolt,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showOtpStep ? 'Verify & become creator' : 'Become a Creator',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_showOtpStep) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _showOtpStep = false;
                            _otpController.clear();
                          });
                        },
                  child: const Text('Back'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'By becoming a creator, you agree to follow our community guidelines and terms of service',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
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
