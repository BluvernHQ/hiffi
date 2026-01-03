import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppSidebar extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();

  static _AppSidebarState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AppSidebarState>();
  }
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false; // Start collapsed
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    // Start with sidebar collapsed
    _animationController.value = 0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleSidebar() => toggleSidebar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content - takes full width
        widget.child,
        // Backdrop overlay when sidebar is expanded
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (!_isExpanded || _animation.value == 0) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.3 * _animation.value),
                ),
              ),
            );
          },
        ),
        // Sidebar overlay
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              left: _isExpanded ? 0 : -240 * (1 - _animation.value),
              top: 0,
              bottom: 0,
              child: Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15 * _animation.value),
                      blurRadius: 12,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_isExpanded)
                            Text(
                              'Menu',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          IconButton(
                            icon: Icon(
                              _isExpanded ? Icons.close : Icons.menu,
                              size: 24,
                            ),
                            onPressed: _toggleSidebar,
                            tooltip: _isExpanded ? 'Close menu' : 'Open menu',
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(40, 40),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    // Navigation items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        children: [
                          _SidebarItem(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            isActive: widget.currentRoute == '/home',
                            isExpanded: _isExpanded,
                            onTap: () {
                              if (widget.currentRoute != '/home') {
                                context.go('/home');
                              }
                              // Auto-close sidebar after navigation
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted && _isExpanded) {
                                    toggleSidebar();
                                  }
                                },
                              );
                            },
                          ),
                          _SidebarItem(
                            icon: Icons.favorite_rounded,
                            label: 'Following',
                            isActive: widget.currentRoute == '/following',
                            isExpanded: _isExpanded,
                            onTap: () {
                              if (widget.currentRoute != '/following') {
                                context.go('/following');
                              }
                              // Auto-close sidebar after navigation
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted && _isExpanded) {
                                    toggleSidebar();
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Toggle button when collapsed - always visible on left edge
        if (!_isExpanded)
          Positioned(
            left: 0,
            top: MediaQuery.of(context).padding.top ,
            child: Material(
              // color: Theme.of(context).colorScheme.surfaceContainerLowest,
              // borderRadius: const BorderRadius.only(
              //   topRight: Radius.circular(12),
              //   bottomRight: Radius.circular(12),
              // ),
              // elevation: 3,
              // shadowColor: Colors.black.withOpacity(0.2),
              child: InkWell(
                onTap: _toggleSidebar,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.menu_rounded,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                  : _isHovered
                  ? theme.colorScheme.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style:
                          theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ) ??
                          const TextStyle(),
                      child: Text(widget.label),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
