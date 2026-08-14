import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'global.dart';
import 'state/session.dart';
import 'ui/routes.dart';
import 'ui/widgets/toast.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(bunyadOverlayStyle);
  runApp(const ProviderScope(child: BunyadApp()));
}

class BunyadApp extends ConsumerStatefulWidget {
  const BunyadApp({super.key});

  @override
  ConsumerState<BunyadApp> createState() => _BunyadAppState();
}

class _BunyadAppState extends ConsumerState<BunyadApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Find out straight away whether the stored token is still good. The boot
    // screen is what the user sees while this runs.
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Returning to the app is the moment an expired token surfaces — nothing
  /// has been asked of the server since it died.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).revalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Being thrown back to the gate needs a reason, or it reads as the app
    // losing the work rather than the session running out.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next.expired && previous?.expired != true) {
        Toast.global('Your session has ended. Please sign in again.', error: true);
      }
    });

    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Toast.messengerKey,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Bunyad's type scale is fixed by the design; let the system scale it
        // for readability, but not so far that the money figures wrap.
        final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
