import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../widgets/primitives.dart';
import '../widgets/shell.dart';

/// `.boot` — the pulsing mark while the stored token is checked, and the place
/// the app lands when the server cannot be reached at all.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (session.status == SessionStatus.unreachable) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(T.s4),
              child: EmptyState(
                title: 'Bunyad could not start.',
                // The address is nearly always the reason, so name it.
                body: '${session.message ?? 'The server did not answer.'}\n\n'
                    'The app is pointed at $kServerUrl — check that Bunyad is running '
                    'there and that this device can reach it.',
                action: Btn(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.read(sessionProvider.notifier).restore(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(body: Center(child: _BootMark()));
  }
}

class _BootMark extends StatefulWidget {
  const _BootMark();

  @override
  State<_BootMark> createState() => _BootMarkState();
}

class _BootMarkState extends State<_BootMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
            child: const BrandMark(shadow: false),
          ),
          const SizedBox(width: T.s3),
          Text(
            kAppName.toUpperCase(),
            style: TextStyle(
              fontFamily: T.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.02 * 18,
              color: T.ink(0.5),
            ),
          ),
        ],
      );
}
