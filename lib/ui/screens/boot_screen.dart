import 'dart:async';

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
///
/// Being unreachable is not being signed out — the token is still there, and the
/// only thing missing is the server. So this keeps trying on its own rather than
/// waiting to be tapped: a phone that opened the app while the site had no
/// signal, or during a deploy, should let itself in the moment the API answers.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// Backs off so a long outage is not a tight loop against a dead server, but
  /// stays frequent enough that a short one clears itself before anybody has
  /// reached for the button.
  void _scheduleRetry(int attempt) {
    _retry?.cancel();
    final seconds = [3, 5, 10, 20, 30][attempt.clamp(0, 4)];
    _retry = Timer(Duration(seconds: seconds), () {
      if (mounted) ref.read(sessionProvider.notifier).restore();
    });
  }

  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session.status == SessionStatus.unreachable) {
      _attempt += 1;
      _scheduleRetry(_attempt);

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
                    'there and that this device can reach it.\n\n'
                    'You are still signed in. Trying again automatically…',
                action: Btn(
                  label: 'Try now',
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    _retry?.cancel();
                    ref.read(sessionProvider.notifier).restore();
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    _retry?.cancel();
    _attempt = 0;

    // The native splash has just handed over; this draws the same mark on the
    // same white, so the seam does not show.
    return const BunyadLoadingPage();
  }
}
