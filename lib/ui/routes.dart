import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/session.dart';
import 'screens/account_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/boot_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/gate_screen.dart';
import 'screens/join_screen.dart';
import 'screens/login_screen.dart';
import 'screens/password_screen.dart';
import 'screens/project_screen.dart';
import 'screens/stage_screen.dart';

/// The same addresses the web app routes on, minus the hash.
class Routes {
  const Routes._();

  static const String boot = '/boot';
  static const String gate = '/gate';
  static const String join = '/join';
  static const String login = '/login';
  static const String password = '/password';
  static const String dashboard = '/';
  static const String people = '/people';
  static const String account = '/account';

  static String project(String projectId) => '/projects/$projectId';
  static String stage(String projectId, String stageId) =>
      '/projects/$projectId/stages/$stageId';
}

/// Short names for the navigation the screens actually do.
extension BunyadNavigation on BuildContext {
  void goGate() => go(Routes.gate);
  void goJoin() => go(Routes.join);
  void goLogin() => go(Routes.login);
  void goDashboard() => go(Routes.dashboard);
  void goProject(String projectId) => go(Routes.project(projectId));
  void goStage(String projectId, String stageId) => go(Routes.stage(projectId, stageId));
  void goAdmin() => go(Routes.people);
  void goAccount() => go(Routes.account);
}

/// Rebuilds the router's redirect whenever the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(this._ref) {
    _ref.listen<SessionState>(sessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: Routes.boot,
    refreshListenable: listenable,

    // One gate for the whole app: where you may be depends only on the session.
    redirect: (context, state) {
      final status = ref.read(sessionProvider).status;
      final at = state.matchedLocation;

      final atSignedOutScreen = at == Routes.boot ||
          at == Routes.gate ||
          at == Routes.join ||
          at == Routes.login ||
          at == Routes.password;

      return switch (status) {
        SessionStatus.checking => at == Routes.boot ? null : Routes.boot,
        SessionStatus.unreachable => at == Routes.boot ? null : Routes.boot,
        // The gate is the way in by default; joining and signing in are each
        // one tap from there, so all three addresses are allowed to stand.
        SessionStatus.signedOut =>
          (at == Routes.gate || at == Routes.join || at == Routes.login) ? null : Routes.gate,
        // An issued password has to be replaced before anything else opens.
        SessionStatus.mustChangePassword => at == Routes.password ? null : Routes.password,
        SessionStatus.signedIn => atSignedOutScreen ? Routes.dashboard : null,
      };
    },

    routes: [
      GoRoute(path: Routes.boot, builder: (context, state) => const BootScreen()),
      GoRoute(path: Routes.gate, builder: (context, state) => const GateScreen()),
      GoRoute(path: Routes.join, builder: (context, state) => const JoinScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.password, builder: (context, state) => const PasswordScreen()),
      GoRoute(path: Routes.dashboard, builder: (context, state) => const DashboardScreen()),
      GoRoute(path: Routes.people, builder: (context, state) => const AdminScreen()),
      GoRoute(path: Routes.account, builder: (context, state) => const AccountScreen()),
      GoRoute(
        path: '/projects/:projectId',
        builder: (context, state) =>
            ProjectScreen(projectId: state.pathParameters['projectId']!),
        routes: [
          GoRoute(
            path: 'stages/:stageId',
            builder: (context, state) => StageScreen(
              projectId: state.pathParameters['projectId']!,
              stageId: state.pathParameters['stageId']!,
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing at that address.', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('The link may be old, or the project may have been deleted.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.goDashboard(),
                    child: const Text('Back to projects'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
