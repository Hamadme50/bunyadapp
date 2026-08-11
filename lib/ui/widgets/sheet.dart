import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'primitives.dart';

/// `.sheet` — the frame every form lives in.
///
/// On a narrow screen the web app already gives these the whole viewport
/// (`min-height:100vh; border-radius:0`), so on a phone they are a full page:
/// a head with the title and the close button, a scrolling body, and a footer
/// pinned above the keyboard.
///
/// Each sheet pushes itself with a `MaterialPageRoute(fullscreenDialog: true)`
/// and builds this directly, because they all hold form state of their own.
class BunyadSheetScaffold extends StatelessWidget {
  const BunyadSheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.footNote,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final String? footNote;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: T.bg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // ── head ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: T.raised,
              border: Border(bottom: BorderSide(color: T.hairline)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s3, T.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: T.heading(22)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: T.body.copyWith(fontSize: 13, color: T.ink(0.55)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: T.s2),
                    IconBtn(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── body ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(T.s4),
              child: body,
            ),
          ),

          // ── foot ──────────────────────────────────────────────────────
          if (actions != null && actions!.isNotEmpty)
            AnimatedPadding(
              duration: T.tFast,
              padding: EdgeInsets.only(bottom: insets),
              child: Container(
                decoration: const BoxDecoration(
                  color: T.raised,
                  border: Border(top: BorderSide(color: T.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (footNote != null) ...[
                          Text(
                            footNote!,
                            style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                          ),
                          const SizedBox(height: T.s3),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (var i = 0; i < actions!.length; i++) ...[
                              if (i > 0) const SizedBox(width: T.s2),
                              actions![i],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A grid of fields that becomes one column when there is no room — the
/// Flutter answer to `.field-grid`'s `auto-fit, minmax(200px, 1fr)`.
class FieldGrid extends StatelessWidget {
  const FieldGrid({super.key, required this.children, this.minWidth = 190});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 3);
          if (columns == 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 18),
                  children[i],
                ],
              ],
            );
          }
          final width = (constraints.maxWidth - (columns - 1) * 18) / columns;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final child in children) SizedBox(width: width, child: child),
            ],
          );
        },
      );
}

/// The confirmation the web app puts in a small sheet before anything is
/// deleted. Returns true only when the user actually confirms.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: T.neutral900.withValues(alpha: 0.42),
    builder: (context) => Dialog(
      backgroundColor: T.bg,
      insetPadding: const EdgeInsets.all(T.s4),
      shape: RoundedRectangleBorder(borderRadius: T.brLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: T.raised,
            padding: const EdgeInsets.all(T.s4),
            child: Text(title, style: T.heading(20)),
          ),
          Padding(
            padding: const EdgeInsets.all(T.s4),
            child: Text(body, style: T.body.copyWith(fontSize: 14, color: T.ink(0.85))),
          ),
          Container(
            color: T.raised,
            padding: const EdgeInsets.all(T.s3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Btn(
                  label: 'Cancel',
                  kind: BtnKind.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: T.s2),
                Btn(
                  label: confirmLabel,
                  kind: danger ? BtnKind.danger : BtnKind.primary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
