import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/settings/app_settings.dart';
import 'motion.dart';

/// Wraps [child] in a tooltip unless the user disabled tooltips.
class AppTooltip extends ConsumerWidget {
  const AppTooltip({
    required this.message,
    required this.child,
    this.verticalOffset = 24,
    super.key,
  });

  final String message;
  final Widget child;
  final double verticalOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var enabled = true;
    try {
      enabled = ref.watch(
        appSettingsProvider.select(
          (AppSettings settings) => settings.showTooltips,
        ),
      );
    } catch (_) {
      // Widgets reused outside the app's ProviderScope (previews, isolated
      // widget tests) keep the default tooltip behaviour.
    }
    if (!enabled || message.isEmpty) return child;
    return Tooltip(message: message, verticalOffset: verticalOffset, child: child);
  }
}

/// The primary expressive surface used for grouped content.
///
/// Cards use a soft squircle/rounded shape, a tonal container color and an
/// optional accent wash. Tapping triggers a spring press instead of a ripple.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.onTap,
    this.onLongPress,
    this.border = true,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final List<Color>? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final shape = tokens.surfaceShape();
    final outline = shape is OutlinedBorder
        ? shape.copyWith(
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          )
        : shape;
    final baseColor = color ?? scheme.surfaceContainerLow;
    final decorated = AnimatedContainer(
      duration: tokens.scaled(const Duration(milliseconds: 220)),
      curve: Curves.easeOutCubic,
      decoration: ShapeDecoration(
        shape: shape,
        color: gradient == null ? baseColor : null,
        gradient: gradient == null
            ? null
            : LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: clipBehavior,
        child: Stack(
          children: <Widget>[
            if (border)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: outline,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              // Material ancestors are required by ListTile, Chip and other
              // ink-aware children; the decoration above still owns the shape
              // and the colors, so a transparent sheet is enough here.
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return decorated;
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.985,
      child: decorated,
    );
  }
}

/// A section header with an optional leading icon, description and trailing
/// action, used across the settings and dashboard pages.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 10, top: 4),
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: ShapeDecoration(
                color: scheme.secondaryContainer,
                shape: const CircleBorder(),
              ),
              child: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A rounded status pill used for backend, bracket and hint status.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    this.icon,
    this.color,
    this.compact = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.secondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: ShapeDecoration(
        color: tone.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 13 : 15, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: (compact
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelMedium)
                ?.copyWith(color: tone, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A single settings row with a leading icon, title/subtitle and trailing
/// control. Rows animate their container tint when enabled.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = SuperCalcDesignTokens.of(context);
    final content = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 22,
              color: enabled ? scheme.onSurfaceVariant : scheme.outline,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? scheme.onSurface : scheme.outline,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? scheme.onSurfaceVariant
                            : scheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    return AnimatedContainer(
      duration: tokens.scaled(const Duration(milliseconds: 200)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: ShapeDecoration(
        shape: tokens.keyShape(),
        color: Colors.transparent,
      ),
      child: onTap == null
          ? content
          : PressableScale(
              onTap: onTap,
              pressedScale: 0.99,
              child: content,
            ),
    );
  }
}

/// A switch row bound to a settings record.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// A row of expressive choice chips. Selection animates the chip shape and
/// tint with the theme's spring-backed duration.
class SettingsChoice<T> extends StatelessWidget {
  const SettingsChoice({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = SuperCalcDesignTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          selected: isSelected,
          showCheckmark: false,
          avatar: iconOf == null
              ? null
              : Icon(
                  iconOf!(value),
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          label: AnimatedDefaultTextStyle(
            duration: tokens.scaled(const Duration(milliseconds: 180)),
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ) ??
                const TextStyle(),
            child: Text(labelOf(value)),
          ),
          onSelected: (_) => onSelected(value),
        );
      }).toList(growable: false),
    );
  }
}

/// A labelled slider row with a live value pill.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.divisions,
    this.valueLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value)? valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusPill(
                label: valueLabel?.call(value) ?? value.toStringAsFixed(1),
                compact: true,
                color: scheme.primary,
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 0, top: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A compact action row that opens a sub-page or dialog.
class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, size: 22),
    );
  }
}

/// A soft divider that respects the expressive shape language.
class SoftDivider extends StatelessWidget {
  const SoftDivider({this.indent = 0, this.endIndent = 0, super.key});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: Divider(
        height: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
