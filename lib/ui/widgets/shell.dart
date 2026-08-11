import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../routes.dart';
import 'primitives.dart';

/// `.topbar` — the brand, the two nav destinations, the user chip and sign-out.
/// Sticky at the top of every signed-in screen, exactly as on the web.
class BunyadTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const BunyadTopBar({super.key, this.active = NavTab.projects});

  final NavTab active;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: T.bg,
        border: Border(bottom: BorderSide(color: T.hairline)),
        boxShadow: [BoxShadow(color: Color(0x0D2D2B2B), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 57,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.s4),
            child: Row(
              children: [
                _Brand(onTap: () => context.goDashboard()),
                const Spacer(),
                _NavButton(
                  label: 'Projects',
                  active: active == NavTab.projects,
                  onTap: () => context.goDashboard(),
                ),
                if (isAdmin)
                  _NavButton(
                    label: 'People',
                    active: active == NavTab.people,
                    onTap: () => context.goAdmin(),
                  ),
                const SizedBox(width: 4),
                if (user != null)
                  Semantics(
                    button: true,
                    label: 'Your account',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: T.brMd,
                      child: InkWell(
                        onTap: () => context.goAccount(),
                        borderRadius: T.brMd,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Avatar.lg(user.initials),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum NavTab { projects, people, account }

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: T.brMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: T.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The launcher icon itself, so the bar carries the same mark
                // the phone's home screen does. The wordmark stays beside it.
                const BunyadLogo(size: 30),
                const SizedBox(width: 8),
                Text(
                  kAppName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: T.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.02 * 18,
                    color: T.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// `.brand-mark` — the small accent square the whole identity rests on.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 16, this.color = T.accent, this.shadow = true});

  final double size;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: T.brXs,
          boxShadow: shadow ? T.shadowAccent : const [],
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? T.accent100 : Colors.transparent,
        borderRadius: T.brMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: T.brMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: T.fontFamily,
                fontSize: 14,
                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                color: active ? T.accent800 : T.text,
              ),
            ),
          ),
        ),
      );
}

/// `.page` — the standard gutter around a screen's content.
///
/// Named for the CSS class, prefixed because Flutter already has a `Page`.
class BunyadPage extends StatelessWidget {
  const BunyadPage({super.key, required this.children, this.controller, this.padding});

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ListView(
        controller: controller,
        padding: padding ?? const EdgeInsets.fromLTRB(T.s4, T.s6, T.s4, 80),
        children: children,
      );
}

/// `.section-head` — a heading with an optional note and trailing action.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.note,
    this.action,
    this.topPadding = 40,
  });

  final String title;
  final String? note;
  final Widget? action;
  final double topPadding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: T.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: T.h3),
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Text(note!, style: T.body.copyWith(fontSize: 12, color: T.ink(0.6), height: 1.4)),
                  ],
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: T.s3), action!],
          ],
        ),
      );
}

/// `.empty` — the panel that explains why there is nothing here.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: T.s4),
        padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s6),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brLg,
          border: Border.all(color: T.hairline),
          boxShadow: T.shadowXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: T.h4),
            const SizedBox(height: T.s2),
            Text(body, style: T.body.copyWith(color: T.ink(0.7))),
            if (action != null) ...[const SizedBox(height: T.s3), action!],
          ],
        ),
      );
}

/// `.notice` — the bar above a project you may only read.
class ViewerNotice extends StatelessWidget {
  const ViewerNotice({super.key, required this.isViewer, required this.oversight});

  final bool isViewer;
  final bool oversight;

  @override
  Widget build(BuildContext context) {
    if (!isViewer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(T.s4, T.s3, T.s4, 0),
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
      decoration: BoxDecoration(
        color: T.accent100,
        borderRadius: T.brCard,
        border: Border.all(color: T.accent.withValues(alpha: 0.22)),
        boxShadow: T.shadowXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: T.s3),
            decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: oversight
                    ? [
                        TextSpan(
                          text: 'Administrator view. ',
                          style: T.bodySm.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(
                          text: 'This project belongs to somebody else. You can follow every '
                              'rupee on it — adding, editing and sharing are switched off.',
                        ),
                      ]
                    : [
                        TextSpan(
                          text: 'Viewer access. ',
                          style: T.bodySm.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(
                          text: 'You can follow every rupee on this project — adding and '
                              'editing is switched off.',
                        ),
                      ],
              ),
              style: T.bodySm,
            ),
          ),
        ],
      ),
    );
  }
}

/// The screen when a request failed. Mirrors the web shell's `errorState`.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.gone = false,
    this.onBack,
  });

  final String message;
  final VoidCallback onRetry;

  /// A 404 or 403 is not a failure to retry away — say so differently.
  final bool gone;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: T.s4),
        child: EmptyState(
          title: gone ? 'Not available.' : 'That did not load.',
          body: message,
          action: Wrap(
            spacing: T.s2,
            runSpacing: T.s2,
            children: [
              Btn(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
              if (onBack != null)
                Btn(label: 'Back to projects', kind: BtnKind.secondary, onPressed: onBack),
            ],
          ),
        ),
      );
}

/// `.back-link` — the accent breadcrumb above a detail screen.
class BackLink extends StatelessWidget {
  const BackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          borderRadius: T.brMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: T.brMd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 16, color: T.accent),
                  const SizedBox(width: T.s2),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: T.fontFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: T.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
