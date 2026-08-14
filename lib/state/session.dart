import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Wiring
// ═══════════════════════════════════════════════════════════════════════════

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokenStore: TokenStore());
  ref.onDispose(client.dispose);
  return client;
});

final repositoryProvider = Provider<BunyadRepository>(
  (ref) => BunyadRepository(ref.watch(apiClientProvider)),
);

// ═══════════════════════════════════════════════════════════════════════════
//  Session
// ═══════════════════════════════════════════════════════════════════════════

/// Where the shell is: still checking the stored token, signed out, held at the
/// password screen, or in.
enum SessionStatus { checking, signedOut, mustChangePassword, signedIn, unreachable }

class SessionState {
  const SessionState({required this.status, this.user, this.message, this.expired = false});

  final SessionStatus status;
  final UserView? user;

  /// Why the app could not start, when [status] is [SessionStatus.unreachable].
  final String? message;

  /// True when this sign-out was the token dying rather than the user asking.
  /// The app root reads it to say so, instead of dropping somebody at the gate
  /// mid-task with no explanation.
  final bool expired;

  const SessionState.checking() : this._(SessionStatus.checking);
  const SessionState.signedOut() : this._(SessionStatus.signedOut);

  const SessionState._(SessionStatus status) : this(status: status);

  bool get isAdmin => user?.isAdmin ?? false;
}

/// Owns "who is signed in", and nothing else. Every screen that needs the user
/// reads it from here rather than passing it down.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState.checking()) {
    // A 401 on any call anywhere means the token died — bounce to sign-in.
    _ref.read(apiClientProvider).onUnauthorized.listen((_) {
      if (state.status == SessionStatus.signedIn ||
          state.status == SessionStatus.mustChangePassword) {
        signOutLocally();
      }
    });
  }

  final Ref _ref;

  BunyadRepository get _repo => _ref.read(repositoryProvider);

  /// At launch: if there is a stored token, find out whether it still works.
  Future<void> restore() async {
    final client = _ref.read(apiClientProvider);
    if (!await client.restore()) {
      state = const SessionState.signedOut();
      return;
    }
    try {
      _apply(await _repo.me());
    } on ApiException catch (failure) {
      if (failure.isUnauthorized) {
        await client.clearToken();
        state = const SessionState.signedOut();
      } else {
        // The server is down or the address in global.dart is wrong. Say so
        // rather than pretending the account is the problem.
        state = SessionState(status: SessionStatus.unreachable, message: failure.message);
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    _apply(await _repo.signIn(email, password));
  }

  /// Signing yourself up leaves you signed in — the server hands back a token
  /// with the new account.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _apply(await _repo.register(name: name, email: email, password: password));
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const SessionState.signedOut();
  }

  /// Drop the token without asking the server — either because it is already
  /// void, or because the account behind it no longer exists.
  ///
  /// [expired] separates the two: a token that died under someone deserves the
  /// notice on the way out, a deliberately deleted account does not.
  Future<void> signOutLocally({bool expired = true}) async {
    await _ref.read(apiClientProvider).clearToken();
    state = SessionState(status: SessionStatus.signedOut, expired: expired);
  }

  /// Called when the app comes back to the foreground.
  ///
  /// A token that expires while the app sits in the background goes unnoticed
  /// until something is asked of the server — which could be the next morning,
  /// with a screenful of stale figures in between. This asks straight away;
  /// the 401 listener in the constructor turns the answer into a sign-out.
  Future<void> revalidate() async {
    if (state.status != SessionStatus.signedIn &&
        state.status != SessionStatus.mustChangePassword) {
      return;
    }
    try {
      _apply(await _repo.me());
    } on ApiException catch (failure) {
      // A 401 has already signed out through onUnauthorized. Anything else is
      // the network, and a dropped signal is no reason to end a session.
      if (failure.isUnauthorized) return;
    }
  }

  void applySession(SessionView session) => _apply(session);

  void _apply(SessionView session) {
    state = SessionState(
      status: session.mustChangePassword
          ? SessionStatus.mustChangePassword
          : SessionStatus.signedIn,
      user: session.user,
    );
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The signed-in user, for the many screens that just want their name.
final currentUserProvider = Provider<UserView?>((ref) => ref.watch(sessionProvider).user);
