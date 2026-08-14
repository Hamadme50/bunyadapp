import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../global.dart';
import '../routes.dart';
import '../widgets/shell.dart';

/// The first screen a signed-out visitor sees: the site photo, the promise,
/// and the only two doors in.
///
/// Join and sign-in are one tap away and carry a back arrow to return here,
/// rather than folding this straight into [JoinScreen] — the photo needs the
/// full screen to read, which a form sitting underneath it would crowd.
class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/site-supervisor.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.36, -0.56),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.60, 0.84, 1.0],
                  colors: [
                    T.accent800.withValues(alpha: 0.05),
                    T.accent800.withValues(alpha: 0.28),
                    T.accent900.withValues(alpha: 0.80),
                    T.accent900.withValues(alpha: 0.95),
                    T.accent900.withValues(alpha: 0.97),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(T.s6, T.s4, T.s6, T.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(color: T.bg, shadow: false),
                        const SizedBox(width: 10),
                        Text(
                          kAppName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: T.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.02 * 18,
                            color: T.bg,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 19),
                    Text(
                      'Every rupee your building costs, in one book.',
                      style: T.heading(33, color: T.bg, height: 1.14),
                    ),
                    const SizedBox(height: T.s3),
                    Text(
                      'From the plot walk to the punch list — every rupee logged on '
                      'site, stage by stage.',
                      style: T.body.copyWith(fontSize: 15, color: T.bg.withValues(alpha: 0.88)),
                    ),
                    const SizedBox(height: T.s6),
                    _GateButton(label: 'Create Account', onTap: () => context.goJoin()),
                    const SizedBox(height: T.s3),
                    _GateButton(label: 'Log in', onTap: () => context.goLogin()),
                    const Spacer(flex: 7),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// The gate's two doors — the same accent button, one under the other.
///
/// Not [Btn]: the design gives these a taller box and a bigger label than the
/// app's standard button.
class _GateButton extends StatelessWidget {
  const _GateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: T.accent,
            borderRadius: T.brMd,
            // Heavier than T.shadowAccent — the accent has to lift off a dark photo.
            boxShadow: [
              BoxShadow(
                color: T.accent.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: T.brMd,
            child: InkWell(
              borderRadius: T.brMd,
              onTap: onTap,
              splashColor: T.bg.withValues(alpha: 0.12),
              highlightColor: T.bg.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: T.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.2,
                    color: T.bg,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
