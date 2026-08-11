import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// The design system's small parts — buttons, tags, avatars, chips, meters.
/// Each one is the CSS class of the same name, drawn in Flutter.

// ═══════════════════════════════════════════════════════════════════════════
//  Buttons
// ═══════════════════════════════════════════════════════════════════════════

enum BtnKind { primary, secondary, ghost, danger }

/// `.btn` and its variants. [busy] swaps the label for the spinner the web
/// app's `submitButton` shows while a save is in flight.
class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.icon,
    this.busy = false,
    this.busyLabel = 'Saving…',
    this.block = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final bool busy;
  final String busyLabel;

  /// `.btn-block` — full width, and the label sits left, as on the login form.
  final bool block;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    final (Color fg, Color? bg, Color border, List<BoxShadow> shadow) = switch (kind) {
      BtnKind.primary => (T.bg, T.accent, Colors.transparent, T.shadowAccent),
      BtnKind.secondary => (T.text, T.raised, T.hairlineStrong, T.shadowXs),
      BtnKind.ghost => (T.accent, null, Colors.transparent, const <BoxShadow>[]),
      BtnKind.danger => (T.accent700, T.raised, T.hairlineStrong, T.shadowXs),
    };

    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: block ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        if (busy)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Spinner(size: 14, color: fg),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(icon, size: 16, color: fg),
          ),
        Flexible(
          child: Text(
            busy ? busyLabel : label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: T.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.2,
              color: fg,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: T.brMd,
          border: Border.all(color: border),
          boxShadow: enabled && bg != null ? shadow : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: T.brMd,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: T.brMd,
            splashColor: (kind == BtnKind.primary ? T.bg : T.accent).withValues(alpha: 0.12),
            highlightColor: (kind == BtnKind.primary ? T.bg : T.accent).withValues(alpha: 0.06),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kind == BtnKind.ghost ? 8 : (compact ? 12 : 15),
                vertical: compact ? 8 : 11,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-icon` — the 36px square that carries a pencil or a bin.
class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 36,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: T.raised,
        borderRadius: T.brMd,
        border: Border.all(color: T.hairlineStrong),
        boxShadow: T.shadowXs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: T.brMd,
        child: InkWell(
          onTap: onPressed,
          borderRadius: T.brMd,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 16, color: color ?? T.text),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// `.spinner` — 2px ring, accent by default.
class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color ?? T.accent,
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tags, chips and avatars
// ═══════════════════════════════════════════════════════════════════════════

enum TagKind { accent, accent2, neutral, outline }

/// `.tag` — the small status and access labels.
class BunyadTag extends StatelessWidget {
  const BunyadTag(this.label, {super.key, this.kind = TagKind.neutral});

  /// The status ladder the web app uses: in progress is loud, complete is
  /// quiet, not started is only an outline.
  factory BunyadTag.status(String label, {required bool inProgress, required bool complete}) {
    if (inProgress) return BunyadTag(label, kind: TagKind.accent);
    if (complete) return BunyadTag(label, kind: TagKind.neutral);
    return BunyadTag(label, kind: TagKind.outline);
  }

  final String label;
  final TagKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (kind) {
      TagKind.accent => (T.accent100, T.accent800, Colors.transparent),
      TagKind.accent2 => (T.accent100, T.accent800, Colors.transparent),
      TagKind.neutral => (T.neutral100, T.neutral800, Colors.transparent),
      TagKind.outline => (Colors.transparent, T.accent, T.accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: T.brSm,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: T.fontFamily,
          fontSize: 11,
          height: 1.5,
          letterSpacing: 0.02 * 11,
          color: fg,
        ),
      ),
    );
  }
}

/// `.avatar` in its three sizes. The large one inverts — ink ground, pale text.
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 22});

  const Avatar.md(this.initials, {super.key}) : size = 28;
  const Avatar.lg(this.initials, {super.key}) : size = 34;

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final large = size >= 34;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: large ? T.text : T.neutral200,
        borderRadius: size <= 22 ? T.brXs : T.brSm,
        boxShadow: large ? T.shadowXs : const [],
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: T.fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: size <= 22 ? 9 : (size <= 28 ? 11 : 12),
          height: 1,
          color: large ? T.bg : T.neutral800,
        ),
      ),
    );
  }
}

/// `.chip` — the head suggestions and the stage ladder editor. [pressed] is the
/// `aria-pressed` state: filled accent instead of outlined.
class BunyadChip extends StatelessWidget {
  const BunyadChip({
    super.key,
    required this.label,
    this.onTap,
    this.pressed = false,
    this.neutral = false,
    this.icon,
    this.onRemove,
    this.removeTooltip,
  });

  final String label;
  final VoidCallback? onTap;
  final bool pressed;
  final bool neutral;
  final IconData? icon;

  /// Shows the small × that deletes a head or a stage from the ladder.
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Color border;

    if (pressed) {
      fg = T.bg;
      bg = T.accent;
      border = T.accent;
    } else if (neutral) {
      fg = T.neutral800;
      bg = T.neutral100;
      border = T.hairline;
    } else {
      fg = T.accent700;
      bg = T.raised;
      border = T.accent.withValues(alpha: 0.45);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: T.brPill,
        border: Border.all(color: border),
        boxShadow: pressed ? T.shadowAccent : T.shadowXs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: T.brPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: T.brPill,
          child: Padding(
            padding: EdgeInsets.only(
              left: 13,
              right: onRemove == null ? 13 : 6,
              top: 7,
              bottom: 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, height: 1.3, color: fg),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: removeTooltip ?? 'Remove $label',
                    child: InkResponse(
                      onTap: onRemove,
                      radius: 14,
                      child: Icon(Icons.close_rounded, size: 14, color: fg),
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

// ═══════════════════════════════════════════════════════════════════════════
//  Surfaces and meters
// ═══════════════════════════════════════════════════════════════════════════

/// A raised panel: white ground, hairline edge, the resting shadow.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(T.s4),
    this.radius,
    this.onTap,
    this.shadow,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? T.brCard;
    final body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.raised,
        borderRadius: r,
        border: Border.all(color: borderColor ?? T.hairline),
        boxShadow: shadow ?? T.shadowXs,
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              borderRadius: r,
              child: InkWell(
                onTap: onTap,
                borderRadius: r,
                splashColor: T.accent.withValues(alpha: 0.06),
                highlightColor: T.accent.withValues(alpha: 0.03),
                child: body,
              ),
            ),
    );
  }
}

/// `.meter` — a stage's share of the project total.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.percent, this.height = 6});

  final int percent;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: T.brPill,
        child: SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: (percent.clamp(0, 100)) / 100,
            backgroundColor: T.neutral200,
            valueColor: const AlwaysStoppedAnimation<Color>(T.accent),
          ),
        ),
      );
}

/// `.dots` — the stage strip on a dashboard row. One bar per stage: filled for
/// complete, pale accent for in progress, grey for not started.
class StageDots extends StatelessWidget {
  const StageDots({super.key, required this.states});

  /// 2 = complete, 1 = in progress, 0 = not started.
  final List<int> states;

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(color: T.neutral200, borderRadius: T.brPill),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < states.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: switch (states[i]) {
                  2 => T.accent,
                  1 => T.accent300,
                  _ => T.neutral200,
                },
                borderRadius: T.brPill,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The all-caps micro label above a figure.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: accent ? T.kicker : T.eyebrow,
      );
}

/// `.stat` — one figure in the strip across the top of the dashboard.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.accent = false, this.valueSize = 26});

  final String label;
  final String value;
  final bool accent;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow(label),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: T.amount(valueSize, color: accent ? T.accent : T.text)),
            ),
          ],
        ),
      );
}
