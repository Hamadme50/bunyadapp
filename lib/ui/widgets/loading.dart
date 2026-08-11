import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'primitives.dart';

/// Nothing but the logo and a quiet progress bar, filling whatever it is given.
///
/// This is what every screen shows while its first request is in flight, so
/// moving between pages always lands on the same centred mark instead of a
/// spinner in the corner. White rather than the app's usual ground, because it
/// stands in for the splash.
class BunyadLoadingView extends StatelessWidget {
  const BunyadLoadingView({super.key, this.message});

  /// Shown under the bar. Left off, the page is just the mark.
  final String? message;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BreathingLogo(),
                const SizedBox(height: 28),

                // A sliver rather than a spinning ring: it sits better under a
                // square mark, and matches the meters used throughout the app.
                SizedBox(
                  width: 132,
                  child: ClipRRect(
                    borderRadius: T.brPill,
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: T.neutral200,
                      valueColor: AlwaysStoppedAnimation<Color>(T.accent),
                    ),
                  ),
                ),

                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: T.body.copyWith(fontSize: 13, color: T.ink(0.55)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The same thing as a whole screen, for the places that replace the page
/// entirely rather than fill a body.
class BunyadLoadingPage extends StatelessWidget {
  const BunyadLoadingPage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: BunyadLoadingView(message: message),
      );
}

/// The mark breathing gently, so a slow connection still looks alive.
class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo();

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1, end: 1.05)
      .animate(CurvedAnimation(parent: _controller, curve: T.ease));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: const BunyadLogo(),
      );
}

