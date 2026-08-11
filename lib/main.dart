import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'global.dart';
import 'state/session.dart';
import 'ui/routes.dart';

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

class _BunyadAppState extends ConsumerState<BunyadApp> {
  @override
  void initState() {
    super.initState();
    // Find out straight away whether the stored token is still good. The boot
    // screen is what the user sees while this runs.
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
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
