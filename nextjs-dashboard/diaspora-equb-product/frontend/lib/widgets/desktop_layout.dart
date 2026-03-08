import 'package:flutter/material.dart';

import '../config/theme.dart';

class DesktopContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;
  final double? maxWidth;

  const DesktopContent({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? AppTheme.pagePaddingFor(context);
    final width = maxWidth ?? AppTheme.contentMaxWidthFor(context);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: resolvedPadding,
          child: child,
        ),
      ),
    );
  }
}

class DesktopCardSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;

  const DesktopCardSection({
    super.key,
    required this.child,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(
          radius ?? AppTheme.cardRadius,
        ),
        boxShadow: AppTheme.cardShadowFor(context),
        border: AppTheme.borderFor(context, opacity: 0.05),
      ),
      child: child,
    );
  }
}

class DesktopSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const DesktopSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}
