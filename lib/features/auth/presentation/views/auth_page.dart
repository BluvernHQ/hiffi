import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../../../core/widgets/hiffi_logo.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';

class _LowerCaseTextFormatter extends TextInputFormatter {
  const _LowerCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.toLowerCase();
    if (lower == newValue.text) return newValue;
    return newValue.copyWith(
      text: lower,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Keeps [hintText] visible in the field (M3 default hides hint behind the label).
InputDecoration authInputDecoration({
  required String label,
  required String hint,
  Widget? suffixIcon,
  String? helperText,
  int? helperMaxLines,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    hintStyle: const TextStyle(
      color: Color(0xFF9A9AA1),
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: const TextStyle(
      color: Color(0xFF6B6B6B),
      fontSize: 14,
    ),
    suffixIcon: suffixIcon,
    helperText: helperText,
    helperMaxLines: helperMaxLines,
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.initialMode = AuthMode.signIn,
    this.returnRoute,
  });

  final AuthMode initialMode;
  final String? returnRoute;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Create form keys locally to avoid GlobalKey conflicts
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _forgotPasswordFormKey = GlobalKey<FormState>();
  final _resetPasswordFormKey = GlobalKey<FormState>();
  StreamSubscription? _authSubscription;

  // Password visibility toggles
  bool _signInPasswordVisible = false;
  bool _signUpPasswordVisible = false;
  bool _resetPasswordVisible = false;
  bool _confirmResetPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Set mode after build to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authViewModel = context.read<AuthViewModel>();
        authViewModel.setMode(widget.initialMode);
        // Clear all form fields when entering the auth flow
        authViewModel.reset();
        // Clear availability message when switching pages
        context.read<UserViewModel>().clearUsernameAvailability();
        _setupAuthListener();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    final authRepository = context.read<AuthRepository>();
    _authSubscription = authRepository.authStateChanges().listen((user) {
      if (mounted && user != null) {
        // User just logged in, navigate to return route or home
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            final route = widget.returnRoute ?? '/home';
            context.go(route);
          }
        });
      }
    });
  }

  void _handleSkip(BuildContext context) {
    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: widget.initialMode == AuthMode.signUp
            ? 'signup-skip-button'
            : 'login-skip-button',
        screenName: widget.initialMode == AuthMode.signUp ? 'signup' : 'login',
      ),
    );
    // If we have a return route, navigate to it using context.go()
    // This is the most reliable way to ensure we land on the intended page
    // even if the navigation stack was reset or if we came from a deep link.
    if (widget.returnRoute != null) {
      context.go(widget.returnRoute!);
    } else if (context.canPop()) {
      // If we can pop, it means we were pushed, so pop back to preserve stack
      context.pop();
    } else {
      // Fallback to home if no return route and can't pop
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final isSignIn = viewModel.mode == AuthMode.signIn;
    final isSignUp = viewModel.mode == AuthMode.signUp;
    final isVerifyOtp = viewModel.mode == AuthMode.verifyOtp;
    final isForgotPassword = viewModel.mode == AuthMode.forgotPassword;
    final isResetPassword = viewModel.mode == AuthMode.resetPassword;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isVerifyOtp && !isResetPassword,
        leading: isVerifyOtp || isResetPassword || isForgotPassword
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (isVerifyOtp) {
                    unawaited(
                      context.read<FirstPartyAnalyticsService>().capture(
                        r'$click',
                        elementUiName: 'signup-back-to-registration-button',
                        screenName: 'signup',
                      ),
                    );
                    viewModel.setMode(AuthMode.signUp);
                  } else if (isResetPassword) {
                    viewModel.setMode(AuthMode.forgotPassword);
                  } else {
                    viewModel.setMode(AuthMode.signIn);
                  }
                },
              )
            : null,
        actions: [
          if (!isVerifyOtp && !isResetPassword && !isForgotPassword)
            TextButton(
              onPressed: viewModel.isLoading
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      _handleSkip(context);
                    },
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HiffiLogo(size: 80),
                    const SizedBox(height: 8),
                    Text(
                      isSignIn
                          ? 'Sign in with your username or email.'
                          : isSignUp
                          ? 'Create an account to start using Hiffi.'
                          : isVerifyOtp
                          ? 'Enter the verification code sent to your email.'
                          : isForgotPassword
                          ? 'Enter your email to reset your password.'
                          : 'Enter the verification code and your new password.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (viewModel.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              viewModel.errorMessage!.contains('successfully')
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          viewModel.errorMessage ?? '',
                          style: TextStyle(
                            color:
                                viewModel.errorMessage!.contains('successfully')
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: isSignIn
                          ? _signInFormKey
                          : isSignUp
                          ? _signUpFormKey
                          : isVerifyOtp
                          ? _otpFormKey
                          : isForgotPassword
                          ? _forgotPasswordFormKey
                          : _resetPasswordFormKey,
                      child: Column(
                        children: [
                          if (isSignIn) ...[
                            TextFormField(
                              controller: viewModel.usernameController,
                              decoration: authInputDecoration(
                                label: 'Username or Email *',
                                hint: 'Enter your username or email',
                              ),
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              inputFormatters: [
                                // Allow alphanumeric, underscores, and common email characters
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9_@.]'),
                                ),
                                TextInputFormatter.withFunction((
                                  oldValue,
                                  newValue,
                                ) {
                                  // Convert to lowercase
                                  final lowercaseText = newValue.text
                                      .toLowerCase();
                                  return TextEditingValue(
                                    text: lowercaseText,
                                    selection: newValue.selection,
                                  );
                                }),
                              ],
                              validator: (value) {
                                final identifier = value?.trim() ?? '';
                                if (identifier.isEmpty) {
                                  return 'Please enter your username or email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.signInPasswordController,
                              decoration: authInputDecoration(
                                label: 'Password *',
                                hint: 'Enter your password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _signInPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      context
                                          .read<FirstPartyAnalyticsService>()
                                          .capture(
                                            r'$click',
                                            elementUiName:
                                                'login-toggle-password-visibility-button',
                                            screenName: 'login',
                                          ),
                                    );
                                    setState(() {
                                      _signInPasswordVisible =
                                          !_signInPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_signInPasswordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(
                                  RegExp(r'\s'),
                                ),
                              ],
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  unawaited(
                                    context
                                        .read<FirstPartyAnalyticsService>()
                                        .capture(
                                          r'$click',
                                          elementUiName: 'login-submit-button',
                                          screenName: 'login',
                                        ),
                                  );
                                  viewModel.submit(formKey: _signInFormKey);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password.';
                                }
                                if (value.contains(RegExp(r'\s'))) {
                                  return 'Password cannot contain spaces.';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: viewModel.isLoading
                                    ? null
                                    : () {
                                        viewModel.setMode(
                                          AuthMode.forgotPassword,
                                        );
                                      },
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                          ] else if (isSignUp) ...[
                            TextFormField(
                              controller: viewModel.nameController,
                              decoration: authInputDecoration(
                                label: 'Full name *',
                                hint: 'Enter your full name',
                              ),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z\s]'),
                                ),
                                LengthLimitingTextInputFormatter(30),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name.';
                                }
                                if (value.trim().length >= 30) {
                                  return 'Name must be less than 30 characters.';
                                }
                                if (!RegExp(
                                  r'^[a-zA-Z\s]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Name can only contain alphabets.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.emailController,
                              decoration: authInputDecoration(
                                label: 'Email *',
                                hint: 'Enter your email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              inputFormatters: const [_LowerCaseTextFormatter()],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email.';
                                }
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(
                                  value.trim().toLowerCase(),
                                )) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _UsernameField(
                              controller: viewModel.signUpUsernameController,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.signUpPasswordController,
                              decoration: authInputDecoration(
                                label: 'Password *',
                                hint: 'Enter your password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _signUpPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      context
                                          .read<FirstPartyAnalyticsService>()
                                          .capture(
                                            r'$click',
                                            elementUiName:
                                                'signup-toggle-password-visibility-button',
                                            screenName: 'signup',
                                          ),
                                    );
                                    setState(() {
                                      _signUpPasswordVisible =
                                          !_signUpPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_signUpPasswordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(
                                  RegExp(r'\s'),
                                ),
                              ],
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(formKey: _signUpFormKey);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please set a password.';
                                }
                                if (value.contains(RegExp(r'\s'))) {
                                  return 'Password cannot contain spaces.';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                          ] else if (isVerifyOtp) ...[
                            const SizedBox(height: 32),
                            _OtpInput(
                              controller: viewModel.otpController,
                              isLoading: viewModel.isLoading,
                              onSubmitted: () {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(formKey: _otpFormKey);
                                }
                              },
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "Didn't receive the code?",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        !viewModel.canResendOtp ||
                                            viewModel.isLoading
                                        ? null
                                        : () {
                                            unawaited(
                                              context
                                                  .read<
                                                    FirstPartyAnalyticsService
                                                  >()
                                                  .capture(
                                                    r'$click',
                                                    elementUiName:
                                                        'signup-resend-otp-button',
                                                    screenName: 'signup',
                                                  ),
                                            );
                                            viewModel.resendOtp();
                                          },
                                    child: Text(
                                      viewModel.canResendOtp
                                          ? 'Resend code'
                                          : 'Resend in ${viewModel.resendTimer}s',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isForgotPassword) ...[
                            TextFormField(
                              controller: viewModel.emailController,
                              decoration: authInputDecoration(
                                label: 'Email',
                                hint: 'Enter your registered email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              inputFormatters: const [_LowerCaseTextFormatter()],
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(
                                    formKey: _forgotPasswordFormKey,
                                  );
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email.';
                                }
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(
                                  value.trim().toLowerCase(),
                                )) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                          ] else if (isResetPassword) ...[
                            const SizedBox(height: 32),
                            _OtpInput(
                              controller: viewModel.otpController,
                              isLoading: viewModel.isLoading,
                              onSubmitted: () {
                                // Don't submit automatically, wait for password
                              },
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: viewModel.resetPasswordController,
                              decoration: authInputDecoration(
                                label: 'New Password',
                                hint: 'Enter your new password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _resetPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      context
                                          .read<FirstPartyAnalyticsService>()
                                          .capture(
                                            r'$click',
                                            elementUiName:
                                                'login-toggle-password-visibility-button',
                                            screenName: 'reset_password',
                                          ),
                                    );
                                    setState(() {
                                      _resetPasswordVisible =
                                          !_resetPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_resetPasswordVisible,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a new password.';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller:
                                  viewModel.confirmResetPasswordController,
                              decoration: authInputDecoration(
                                label: 'Confirm New Password',
                                hint: 'Confirm your new password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _confirmResetPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    unawaited(
                                      context
                                          .read<FirstPartyAnalyticsService>()
                                          .capture(
                                            r'$click',
                                            elementUiName:
                                                'login-toggle-password-visibility-button',
                                            screenName: 'reset_password',
                                          ),
                                    );
                                    setState(() {
                                      _confirmResetPasswordVisible =
                                          !_confirmResetPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_confirmResetPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(
                                    formKey: _resetPasswordFormKey,
                                  );
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password.';
                                }
                                if (value !=
                                    viewModel.resetPasswordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "Didn't receive the code?",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        !viewModel.canResendOtp ||
                                            viewModel.isLoading
                                        ? null
                                        : () {
                                            unawaited(
                                              context
                                                  .read<
                                                    FirstPartyAnalyticsService
                                                  >()
                                                  .capture(
                                                    r'$click',
                                                    elementUiName:
                                                        'signup-resend-otp-button',
                                                    screenName: 'reset_password',
                                                  ),
                                            );
                                            viewModel.resendOtp();
                                          },
                                    child: Text(
                                      viewModel.canResendOtp
                                          ? 'Resend code'
                                          : 'Resend in ${viewModel.resendTimer}s',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                final firstParty =
                                    context.read<FirstPartyAnalyticsService>();
                                if (isSignIn) {
                                  unawaited(
                                    firstParty.capture(
                                      r'$click',
                                      elementUiName: 'login-submit-button',
                                      screenName: 'login',
                                    ),
                                  );
                                } else if (isSignUp) {
                                  unawaited(
                                    firstParty.capture(
                                      r'$click',
                                      elementUiName:
                                          'signup-create-account-button',
                                      screenName: 'signup',
                                    ),
                                  );
                                } else if (isVerifyOtp) {
                                  unawaited(
                                    firstParty.capture(
                                      r'$click',
                                      elementUiName: 'signup-verify-otp-button',
                                      screenName: 'signup',
                                    ),
                                  );
                                }
                                final formKey = isSignIn
                                    ? _signInFormKey
                                    : isSignUp
                                    ? _signUpFormKey
                                    : isVerifyOtp
                                    ? _otpFormKey
                                    : isForgotPassword
                                    ? _forgotPasswordFormKey
                                    : _resetPasswordFormKey;
                                viewModel.submit(formKey: formKey);
                              },
                        child: viewModel.isLoading
                            ? const InlineShimmer(width: 20, height: 20)
                            : Text(
                                isSignIn
                                    ? 'Sign in'
                                    : isSignUp
                                    ? 'Create account'
                                    : isForgotPassword
                                    ? 'Send reset link'
                                    : 'Reset Password',
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isVerifyOtp && !isResetPassword)
                      Center(
                        child: TextButton(
                          onPressed: viewModel.isLoading
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  unawaited(
                                    context
                                        .read<FirstPartyAnalyticsService>()
                                        .capture(
                                          r'$click',
                                          elementUiName: isSignIn ||
                                                  isForgotPassword
                                              ? 'auth-dialog-signup-button'
                                              : 'auth-dialog-login-button',
                                          screenName:
                                              isSignIn ? 'login' : 'signup',
                                        ),
                                  );
                                  // Preserve return route when switching between sign in and sign up
                                  final returnRouteParam =
                                      widget.returnRoute != null
                                      ? '?returnTo=${Uri.encodeComponent(widget.returnRoute!)}'
                                      : '';
                                  if (isSignIn || isForgotPassword) {
                                    context.go('/signup$returnRouteParam');
                                  } else {
                                    context.go('/login$returnRouteParam');
                                  }
                                },
                          child: Text(
                            isSignIn || isForgotPassword
                                ? 'Need an account? Sign up'
                                : 'Already have an account? Sign in',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpInput extends StatefulWidget {
  const _OtpInput({
    required this.controller,
    required this.isLoading,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback? onSubmitted;

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // Ensure keyboard appears even after it's been dismissed
            // Unfocus first if already focused to reset the state
            if (_focusNode.hasFocus) {
              _focusNode.unfocus();
            }
            // Use a small delay to ensure unfocus completes before requesting focus
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) {
                _focusNode.requestFocus();
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final text = widget.controller.text;
              final len = text.length;
              final hasDigit = index < len;
              // Slot where the next digit will go (0–5); none when all 6 entered
              final isActive = index == len && len < 6;

              final scheme = theme.colorScheme;
              late final Color bg;
              late final Color borderColor;
              late final double borderWidth;

              if (hasDigit) {
                bg = scheme.primaryContainer.withOpacity(0.35);
                borderColor = scheme.primary.withOpacity(0.55);
                borderWidth = 1.5;
              } else if (isActive) {
                bg = scheme.primary.withOpacity(0.14);
                borderColor = scheme.primary;
                borderWidth = 2;
              } else {
                // Pending / not-yet-filled: always visible vs active & filled
                bg = scheme.surfaceContainerHighest.withOpacity(0.85);
                borderColor = scheme.outlineVariant;
                borderWidth = 1;
              }

              return Container(
                width: 45,
                height: 55,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: borderWidth,
                  ),
                ),
                child: Center(
                  child: Text(
                    hasDigit ? text[index] : '',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasDigit
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withOpacity(0.35),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Hidden text field to capture input
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 0,
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: !widget.isLoading,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                if (value.length == 6 && widget.onSubmitted != null) {
                  widget.onSubmitted!();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UsernameField extends StatefulWidget {
  const _UsernameField({required this.controller});

  final TextEditingController controller;

  @override
  State<_UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<_UsernameField> {
  Timer? _debounceTimer;
  String? _validationError;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAvailability(String username) async {
    if (username.trim().isEmpty) {
      setState(() {
        _validationError = null;
      });
      return;
    }

    // Backend regex: ^[a-z0-9_]{3,30}$ - lowercase only, 3-30 chars
    final trimmedUsername = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(trimmedUsername)) {
      setState(() {
        if (trimmedUsername.length < 3) {
          _validationError = 'Username must be at least 3 characters.';
        } else if (trimmedUsername.length > 30) {
          _validationError = 'Username must be 30 characters or less.';
        } else {
          _validationError =
              'Username can only contain lowercase letters, numbers, and underscores.';
        }
      });
      return;
    }

    final userViewModel = context.read<UserViewModel>();
    // Backend requires lowercase usernames
    final available = await userViewModel.checkUsernameAvailability(
      username.toLowerCase(),
    );

    if (mounted) {
      setState(() {
        _validationError = available ? null : 'Username is already taken';
      });
    }
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _validationError = null;
    });

    if (value.trim().isEmpty) {
      // Clear availability message if field is empty
      context.read<UserViewModel>().clearUsernameAvailability();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkAvailability(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userViewModel = context.watch<UserViewModel>();
    final isChecking = userViewModel.isCheckingAvailability;
    final availabilityMessage = userViewModel.usernameAvailabilityMessage;
    final isAvailable = userViewModel.isUsernameAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          decoration: authInputDecoration(
            label: 'Username *',
            hint: 'Choose a username',
            helperText:
                '3-30 characters, lowercase letters, numbers, and underscores only.',
            suffixIcon: isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: InlineShimmer(width: 20, height: 20),
                    ),
                  )
                : isAvailable == true
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : isAvailable == false
                ? Icon(Icons.cancel, color: Theme.of(context).colorScheme.error)
                : null,
            helperMaxLines: 2,
          ),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          inputFormatters: [
            // Convert to lowercase and allow only valid characters (backend requires lowercase)
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              // Convert to lowercase
              final lowercaseText = newValue.text.toLowerCase();
              return TextEditingValue(
                text: lowercaseText,
                selection: newValue.selection,
              );
            }),
            LengthLimitingTextInputFormatter(30),
          ],
          onChanged: _onUsernameChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Please choose a username.';
            }
            // Backend regex: ^[a-z0-9_]{3,30}$ - lowercase only, 3-30 chars
            final lowercaseTrimmed = trimmed.toLowerCase();
            if (lowercaseTrimmed.length < 3) {
              return 'Username must be at least 3 characters.';
            }
            if (lowercaseTrimmed.length > 30) {
              return 'Username must be 30 characters or less.';
            }
            if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(lowercaseTrimmed)) {
              return 'Username can only contain lowercase letters, numbers, and underscores.';
            }
            if (_validationError != null) {
              return _validationError;
            }
            return null;
          },
        ),
        if (availabilityMessage != null &&
            !isChecking &&
            isAvailable == true) ...[
          const SizedBox(height: 4),
          Text(
            availabilityMessage,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
