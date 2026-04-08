import 'package:flutter/material.dart';
// import 'package:forgetmenot/theme/app_theme.dart';
import 'package:forgetmenot/theme/app_theme.dart';


// ── Gradient Card ──────────────────────────────────────────────────────────
class GradientCard extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  const GradientCard({
    super.key, required this.gradient, required this.child,
    this.padding, this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius ?? 24),
      boxShadow: AppTheme.cardShadow,
    ),
    child: child,
  );
}

// ── Info Card ──────────────────────────────────────────────────────────────
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const InfoCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppTheme.softShadow,
    ),
    child: child,
  );
}

// ── Stat Tile ─────────────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const StatTile({
    super.key, required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: color,
        )),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          fontSize: 11, color: AppTheme.textMid, fontWeight: FontWeight.w500,
        )),
      ],
    ),
  );
}

// ── Section Header ────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      )),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(
            color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13,
          )),
        ),
    ],
  );
}

// ── Reminder Chip ─────────────────────────────────────────────────────────
class ReminderStatusChip extends StatelessWidget {
  final String status;
  const ReminderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'completed': color = AppTheme.success;  label = 'Done';    break;
      case 'missed':    color = AppTheme.danger;   label = 'Missed';  break;
      case 'snoozed':   color = AppTheme.warning;  label = 'Snoozed'; break;
      default:          color = AppTheme.primary;  label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w700,
      )),
    );
  }
}

// ── Avatar Placeholder ────────────────────────────────────────────────────
class AvatarPlaceholder extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const AvatarPlaceholder({super.key, required this.name, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    final initials = name.trim().split(' ')
      .take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(
        color: c, fontSize: size * 0.35, fontWeight: FontWeight.w800,
      )),
    );
  }
}

// ── Loading Widget ─────────────────────────────────────────────────────────
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, style: const TextStyle(color: AppTheme.textMid)),
        ],
      ],
    ),
  );
}

// ── Empty State ────────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;
  const EmptyStateWidget({
    super.key, required this.icon, required this.title,
    required this.subtitle, this.buttonLabel, this.onButton,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
            textAlign: TextAlign.center),
          if (buttonLabel != null && onButton != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onButton, child: Text(buttonLabel!)),
          ],
        ],
      ),
    ),
  );
}