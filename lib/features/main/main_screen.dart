import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../app/app.dart';

class MainScreen extends StatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isProjectDetail = path.startsWith('/projects/') && path.split('/').length > 2;
    final isOrgDetail = path == '/organization';

    if (isMobile) {
      return _MobileLayout(currentPath: path, child: widget.child, hideNav: isProjectDetail || isOrgDetail, notifService: _notifService);
    }

    return _DesktopLayout(currentPath: path, child: widget.child, notifService: _notifService);
  }
}

// ==================== MOBILE LAYOUT ====================
class _MobileLayout extends StatelessWidget {
  final String currentPath;
  final Widget child;
  final bool hideNav;
  final NotificationService notifService;
  const _MobileLayout({required this.currentPath, required this.child, this.hideNav = false, required this.notifService});

  int _currentIndex(String path) {
    if (path == '/' || path.startsWith('/organizations')) return 0;
    if (path.startsWith('/projects')) return 1;
    if (path.startsWith('/profile')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(currentPath);
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDark = ThemeHelper.isDark(context);
    final bgColor = isDark ? const Color(0xCC1E1E1E) : const Color(0xCCFFFFFF);

    return Scaffold(
      backgroundColor: ThemeHelper.bg(context),
      body: SafeArea(child: child),
      extendBody: true,
      bottomNavigationBar: hideNav ? null : Container(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ThemeHelper.borderLight(context)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MobileNavItem(
                    icon: 'assets/icons/orgs.svg',
                    label: 'Orgs',
                    isActive: index == 0,
                    badge: notifService.totalUnread,
                    onTap: () => context.go('/'),
                  ),
                  _MobileNavItem(
                    icon: 'assets/icons/projects.svg',
                    label: 'Projects',
                    isActive: index == 1,
                    badge: notifService.totalUnread,
                    onTap: () => context.go('/projects'),
                  ),
                  _MobileNavItem(
                    icon: 'assets/icons/profile.svg',
                    label: 'Profile',
                    isActive: index == 2,
                    onTap: () => context.go('/profile'),
                  ),
                  _MobileNavItem(
                    icon: 'assets/icons/settings.svg',
                    label: 'Settings',
                    isActive: index == 3,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.white.withOpacity(0.5) : AppColors.lightTextDim;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(icon, width: 24, height: 24, colorFilter: ColorFilter.mode(isActive ? activeColor : inactiveColor, BlendMode.srcIn)),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: activeColor)),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== DESKTOP LAYOUT ====================
class _DesktopLayout extends StatelessWidget {
  final String currentPath;
  final Widget child;
  final NotificationService notifService;
  const _DesktopLayout({required this.currentPath, required this.child, required this.notifService});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.lightBgDark,
      body: Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x901E1E1E) : const Color(0x90FFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ThemeHelper.borderLight(context)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Row(
              children: [
                _NavigationRail(currentPath: currentPath, notifService: notifService),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationRail extends StatefulWidget {
  final String currentPath;
  final NotificationService notifService;
  const _NavigationRail({required this.currentPath, required this.notifService});

  @override
  State<_NavigationRail> createState() => _NavigationRailState();
}

class _NavigationRailState extends State<_NavigationRail> {
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    return Container(
      width: 56,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const _AnimatedLogo(),
          const SizedBox(height: 16),
          _AnimatedNavButton(
            icon: 'assets/icons/orgs.svg',
            isActive: widget.currentPath == '/' || widget.currentPath.startsWith('/organizations'),
            badge: widget.notifService.totalUnread,
            onTap: () => context.go('/'),
          ),
          const SizedBox(height: 4),
          _AnimatedNavButton(
            icon: 'assets/icons/projects.svg',
            isActive: widget.currentPath.startsWith('/projects'),
            badge: widget.notifService.totalUnread,
            onTap: () => context.go('/projects'),
          ),
          const SizedBox(height: 4),
          _AnimatedNavButton(
            icon: 'assets/icons/profile.svg',
            isActive: widget.currentPath.startsWith('/profile'),
            onTap: () => context.go('/profile'),
          ),
          const Spacer(),
          _AnimatedNavButton(
            icon: 'assets/icons/settings.svg',
            isActive: widget.currentPath.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 12),
          const _AnimatedAvatar(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Center(child: SvgPicture.asset('assets/icons/logo.svg', width: 20, height: 20)),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedNavButton extends StatefulWidget {
  final String icon;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _AnimatedNavButton({required this.icon, required this.isActive, this.badge = 0, required this.onTap});

  @override
  State<_AnimatedNavButton> createState() => _AnimatedNavButtonState();
}

class _AnimatedNavButtonState extends State<_AnimatedNavButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final inactiveColor = isDark ? Colors.white.withOpacity(0.7) : AppColors.lightText;

    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: widget.isActive ? AppColors.primary.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: widget.isActive ? AppColors.primary.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08))),
                  boxShadow: widget.isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.2 * _glowAnimation.value), blurRadius: 12)] : null,
                ),
                child: SvgPicture.asset(widget.icon, width: 18, height: 18, colorFilter: ColorFilter.mode(widget.isActive ? AppColors.primary : inactiveColor, BlendMode.srcIn)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedAvatar extends StatefulWidget {
  const _AnimatedAvatar();
  @override
  State<_AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<_AnimatedAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(50), border: Border.all(color: ThemeHelper.bg(context), width: 2)),
              child: const Center(child: Text('JD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
            ),
          );
        },
      ),
    );
  }
}
