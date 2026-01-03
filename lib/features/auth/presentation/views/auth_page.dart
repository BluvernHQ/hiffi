import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';

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
  StreamSubscription? _authSubscription;

  // Password visibility toggles
  bool _signInPasswordVisible = false;
  bool _signUpPasswordVisible = false;

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
    final isSignIn =
        viewModel.mode == AuthMode.signIn ||
        widget.initialMode == AuthMode.signIn;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
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
                    Text(
                      'Hiffi',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSignIn
                          ? 'Sign in with your username.'
                          : 'Create an account to start using Hiffi.',
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
                              controller: viewModel.usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                              ),
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
                              keyboardType: TextInputType.text,
                              autofillHints: const [AutofillHints.username],
                              inputFormatters: [
                                // Convert to lowercase and allow only valid characters (backend requires lowercase)
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9_]'),
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
                                LengthLimitingTextInputFormatter(30),
                              ],
                              validator: (value) {
                                final username = value?.trim() ?? '';
                                if (username.isEmpty) {
                                  return 'Please enter your username.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: viewModel.signInPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _signInPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
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
                                labelText: 'Full name *',
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
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                hintText: 'Enter your email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email.';
                                }
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
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
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _signUpPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
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
                            ? const InlineShimmer(width: 20, height: 20)
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
                                // Preserve return route when switching between sign in and sign up
                                final returnRouteParam =
                                    widget.returnRoute != null
                                    ? '?returnTo=${Uri.encodeComponent(widget.returnRoute!)}'
                                    : '';
                                if (isSignIn) {
                                  context.go('/signup$returnRouteParam');
                                } else {
                                  context.go('/login$returnRouteParam');
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
          decoration: InputDecoration(
            labelText: 'Username',
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
