import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';
import '../viewmodels/user_view_model.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});

  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isEditingUsername = false;
  bool _isEditingName = false;
  UserModel? _currentLoggedInUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<UserViewModel>();
      final userRepository = context.read<UserRepository>();
      // Load current logged-in user first and store it
      try {
        final currentUser = await userRepository.getCurrentUser();
        setState(() {
          _currentLoggedInUser = currentUser;
        });
      } catch (e) {
        // Ignore error, might not be logged in
        debugPrint('Failed to load current user: $e');
      }
      // Load the profile user
      await viewModel.loadUser(widget.username);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final user = viewModel.currentUser;
    final isOwnProfile = _currentLoggedInUser?.username == widget.username;

    // Update controllers when user data changes and not editing
    if (user != null &&
        _usernameController.text != user.username &&
        !_isEditingUsername) {
      _usernameController.text = user.username;
    }
    if (user != null && _nameController.text != user.name && !_isEditingName) {
      _nameController.text = user.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.username ?? 'Profile'),
        actions: [
          // Only show delete menu for own profile
          if (isOwnProfile)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Account'),
                    ],
                  ),
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) {
                      _showDeleteConfirmation(context, viewModel);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      body: viewModel.isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null && user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage ?? 'Failed to load profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.loadUser(widget.username);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : user == null
          ? const Center(child: Text('User not found'))
          : RefreshIndicator(
              onRefresh: () async {
                await viewModel.loadUser(widget.username);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  backgroundImage:
                                      (user.profilePicture != null &&
                                          user.profilePicture!.isNotEmpty)
                                      ? NetworkImage(user.profilePicture!)
                                      : (user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty)
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child:
                                      (user.profilePicture == null ||
                                              user.profilePicture!.isEmpty) &&
                                          (user.avatarUrl == null ||
                                              user.avatarUrl!.isEmpty)
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : 'U',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                        )
                                      : null,
                                ),
                                if (user.status?.isLive == true)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (user.status?.isLive == true) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatItem(
                                label: 'Followers',
                                value: user.followers.toString(),
                              ),
                              _StatItem(
                                label: 'Following',
                                value: user.following.toString(),
                              ),
                              _StatItem(
                                label: 'Streams',
                                value: user.totalStreams.toString(),
                              ),
                              _StatItem(
                                label: 'Videos',
                                value: user.totalVideos.toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Follow/Unfollow button for other users
                          if (!isOwnProfile && _currentLoggedInUser != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: viewModel.isLoading
                                      ? null
                                      : () async {
                                          try {
                                            if (user.isFollowing == true) {
                                              await viewModel.unfollowUser(
                                                widget.username,
                                              );
                                            } else {
                                              await viewModel.followUser(
                                                widget.username,
                                              );
                                            }
                                            // Reload user to update follow status
                                            await viewModel.loadUser(
                                              widget.username,
                                            );
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to ${user.isFollowing == true ? 'unfollow' : 'follow'}: ${e.toString()}',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: user.isFollowing == true
                                        ? Colors.grey[300]
                                        : Theme.of(context).colorScheme.primary,
                                    foregroundColor: user.isFollowing == true
                                        ? Colors.black87
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: viewModel.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          user.isFollowing == true
                                              ? 'Unfollow'
                                              : 'Follow',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          // Editable fields only for own profile
                          if (isOwnProfile) ...[
                            _EditableField(
                              label: 'Username',
                              value: user.username,
                              controller: _usernameController,
                              isEditing: _isEditingUsername,
                              isLoading: viewModel.isLoading,
                              onTap: () {
                                setState(() {
                                  _isEditingUsername = true;
                                });
                              },
                              onSave: () async {
                                await _saveUsername(viewModel, user);
                              },
                              onCancel: () {
                                setState(() {
                                  _isEditingUsername = false;
                                  _usernameController.text = user.username;
                                  viewModel.clearUsernameAvailability();
                                });
                              },
                              isUsername: true,
                              currentUsername: user.username,
                            ),
                            const SizedBox(height: 16),
                            _EditableField(
                              label: 'Name',
                              value: user.name,
                              controller: _nameController,
                              isEditing: _isEditingName,
                              isLoading: viewModel.isLoading,
                              onTap: () {
                                setState(() {
                                  _isEditingName = true;
                                });
                              },
                              onSave: () async {
                                await _saveName(viewModel, user);
                              },
                              onCancel: () {
                                setState(() {
                                  _isEditingName = false;
                                  _nameController.text = user.name;
                                });
                              },
                            ),
                          ]
                          // Read-only fields for other users
                          else ...[
                            _ReadOnlyField(
                              label: 'Username',
                              value: user.username,
                            ),
                            const SizedBox(height: 16),
                            _ReadOnlyField(label: 'Name', value: user.name),
                          ],
                          if (user.email != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Email',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.email!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                          if (user.bio != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Bio',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.bio!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                          if (user.role != null && user.role!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Role',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.role!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                          if (user.createdAt != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Member since',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDate(user.createdAt!),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                          // Add extra space at bottom to ensure scrollability
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, UserViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: viewModel.isLoading
                ? null
                : () async {
                    Navigator.of(context).pop();
                    try {
                      await viewModel.deleteUser(widget.username);
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete: $error'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUsername(UserViewModel viewModel, UserModel user) async {
    final newUsername = _usernameController.text.trim();

    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newUsername == user.username) {
      setState(() {
        _isEditingUsername = false;
      });
      return;
    }

    try {
      await viewModel.updateUser(
        currentUsername: user.username,
        newUsername: newUsername,
      );
      if (mounted) {
        setState(() {
          _isEditingUsername = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated successfully')),
        );
        // Reload user to get updated username
        await viewModel.loadUser(newUsername);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveName(UserViewModel viewModel, UserModel user) async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newName == user.name) {
      setState(() {
        _isEditingName = false;
      });
      return;
    }

    try {
      await viewModel.updateUser(currentUsername: user.username, name: newName);
      if (mounted) {
        setState(() {
          _isEditingName = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EditableField extends StatefulWidget {
  const _EditableField({
    required this.label,
    required this.value,
    required this.controller,
    required this.isEditing,
    required this.isLoading,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
    this.isUsername = false,
    this.currentUsername,
  });

  final String label;
  final String value;
  final TextEditingController controller;
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool isUsername;
  final String? currentUsername;

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAvailability(String username) async {
    if (username.trim().isEmpty) {
      context.read<UserViewModel>().clearUsernameAvailability();
      return;
    }

    if (widget.currentUsername != null &&
        username.trim() == widget.currentUsername) {
      context.read<UserViewModel>().clearUsernameAvailability();
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username.trim())) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<UserViewModel>().checkUsernameAvailability(username.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final userViewModel = context.watch<UserViewModel>();
    final isChecking =
        widget.isUsername && userViewModel.isCheckingAvailability;
    final availabilityMessage = widget.isUsername
        ? userViewModel.usernameAvailabilityMessage
        : null;
    final isAvailable = widget.isUsername
        ? userViewModel.isUsernameAvailable
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.isEditing
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: widget.controller,
                    autofocus: true,
                    enabled: !widget.isLoading,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      hintText: 'Enter ${widget.label.toLowerCase()}',
                      helperText: widget.isUsername
                          ? 'Letters, numbers, or underscores only.'
                          : null,
                      suffixIcon: widget.isUsername
                          ? (isChecking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : isAvailable == true &&
                                      widget.controller.text.trim() !=
                                          widget.currentUsername
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : isAvailable == false
                                ? Icon(
                                    Icons.cancel,
                                    color: Theme.of(context).colorScheme.error,
                                  )
                                : null)
                          : null,
                      helperMaxLines: 2,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: widget.isUsername ? _checkAvailability : null,
                    onFieldSubmitted: (_) {
                      if (widget.isUsername) {
                        if (isAvailable != false &&
                            widget.controller.text.trim().isNotEmpty &&
                            widget.controller.text.trim() !=
                                widget.currentUsername) {
                          widget.onSave();
                        }
                      } else {
                        if (widget.controller.text.trim().isNotEmpty) {
                          widget.onSave();
                        }
                      }
                    },
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      if (widget.isUsername) {
                        if (isAvailable != false &&
                            widget.controller.text.trim().isNotEmpty &&
                            widget.controller.text.trim() !=
                                widget.currentUsername) {
                          widget.onSave();
                        } else {
                          widget.onCancel();
                        }
                      } else {
                        if (widget.controller.text.trim().isNotEmpty &&
                            widget.controller.text.trim() != widget.value) {
                          widget.onSave();
                        } else {
                          widget.onCancel();
                        }
                      }
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
              )
            : InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
