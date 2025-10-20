import 'package:flutter/material.dart';

/// App logo widget that handles both asset and fallback scenarios
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final bool showFallback;

  const AppLogo({super.key, this.width, this.height, this.showFallback = true});

  @override
  Widget build(BuildContext context) {
    // Try to load the logo from assets
    return SizedBox(width: width, height: height, child: _buildLogo(context));
  }

  Widget _buildLogo(BuildContext context) {
    // First try to load the company logo
    try {
      return Image.asset(
        'assets/logo/logo.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackLogo(context);
        },
      );
    } catch (e) {
      return _buildFallbackLogo(context);
    }
  }

  Widget _buildFallbackLogo(BuildContext context) {
    if (!showFallback) {
      return const SizedBox.shrink();
    }

    // Fallback to app name styling when no logo is available
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.build_circle,
            size: width != null ? width! * 0.3 : 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'VERSFELD',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          Text(
            'Tool Manager',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Splash screen logo - larger variant
class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLogo(width: 200, height: 200);
  }
}

/// Header logo - smaller variant for app bars
class HeaderLogo extends StatelessWidget {
  const HeaderLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLogo(width: 120, height: 40);
  }
}

/// Login screen logo - medium variant
class LoginLogo extends StatelessWidget {
  const LoginLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLogo(width: 150, height: 150);
  }
}
