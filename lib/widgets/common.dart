import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/time.dart';

/// Centres content and caps its width on large screens.
class CenteredColumn extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CenteredColumn({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// White rounded card with a hairline border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: card,
    );
  }
}

/// Small uppercase status pill (ACTIVE, SCHEDULED, …).
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = pillColorsFor(status, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: colors.fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Circular avatar with initials fallback (and photo when available).
class Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const Avatar({super.key, required this.name, this.photoUrl, this.radius = 20});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.green,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (Object error, StackTrace? stackTrace) {},
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: radius * 0.7,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.green,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Live countdown to [target], corrected by the server clock [skew].
///
/// [skew] is `serverTime - deviceNow` measured when the feed was fetched;
/// the effective "now" is therefore `DateTime.now() + skew`.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final Duration skew;
  final TextStyle? style;

  const CountdownText(this.target, {super.key, this.skew = Duration.zero, this.style});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now().add(widget.skew);
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _now = DateTime.now().add(widget.skew));
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(_now);
    return Text(
      formatCountdown(remaining),
      style: widget.style ??
          const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
    );
  }
}

/// Inline error banner.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3D1B1B) : const Color(0xFFF4DEDE),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: dark ? const Color(0xFFF2A3A3) : AppColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Full-area loading spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Empty / informational state with an icon, headline and body.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String body;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 16),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section heading used across screens.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
