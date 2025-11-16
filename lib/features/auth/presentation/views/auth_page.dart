import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Create form keys locally to avoid GlobalKey conflicts
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Set mode after build to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().setMode(widget.initialMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final isSignIn =
        viewModel.mode == AuthMode.signIn ||
        widget.initialMode == AuthMode.signIn;

    return Scaffold(
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
                    Text(
                      'hiffi',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSignIn
                          ? 'Sign in with your email or username.'
                          : 'Create an account to start using hiffi.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (viewModel.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          viewModel.errorMessage ?? '',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: isSignIn ? _signInFormKey : _signUpFormKey,
                      child: Column(
                        children: [
                          if (isSignIn) ...[
                            TextFormField(
                              controller: viewModel.identifierController,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Please enter your email.';
                                }
                                if (!email.contains('@')) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.signInPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(formKey: _signInFormKey);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password.';
                                }
                                return null;
                              },
                            ),
                          ] else ...[
                            TextFormField(
                              controller: viewModel.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                              ),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _UsernameField(
                              controller: viewModel.usernameController,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Please enter your email.';
                                }
                                if (!email.contains('@')) {
                                  return 'Enter a valid email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.signUpPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) {
                                if (!viewModel.isLoading) {
                                  viewModel.submit(formKey: _signUpFormKey);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please set a password.';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
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
                                final formKey = isSignIn
                                    ? _signInFormKey
                                    : _signUpFormKey;
                                viewModel.submit(formKey: formKey);
                              },
                        child: viewModel.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isSignIn ? 'Sign in' : 'Create account'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                if (isSignIn) {
                                  context.go('/signup');
                                } else {
                                  context.go('/login');
                                }
                              },
                        child: Text(
                          isSignIn
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

    if (!RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username.trim())) {
      setState(() {
        _validationError = 'Use at least 3 letters, numbers, or underscores.';
      });
      return;
    }

    final userViewModel = context.read<UserViewModel>();
    final available = await userViewModel.checkUsernameAvailability(username);

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
          decoration: InputDecoration(
            labelText: 'Username',
            helperText: 'Letters, numbers, or underscores only.',
            suffixIcon: isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
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
          onChanged: _onUsernameChanged,
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Please choose a username.';
            }
            if (!RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(trimmed)) {
              return 'Use at least 3 letters, numbers, or underscores.';
            }
            if (_validationError != null) {
              return _validationError;
            }
            return null;
          },
        ),
        if (availabilityMessage != null && !isChecking) ...[
          const SizedBox(height: 4),
          Text(
            availabilityMessage,
            style: TextStyle(
              fontSize: 12,
              color: isAvailable == true
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
