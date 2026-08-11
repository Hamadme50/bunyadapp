import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/shell.dart';

/// The launch screen: the logo while the stored token is checked, and the place
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

    // The native splash has just handed over; this draws the same mark on the
    // same white, so the seam does not show.
    return const BunyadLoadingPage();
  }
}

