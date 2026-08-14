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
    // A 401 on any call anywhere *may* mean the token died — confirm it before
    // acting on it.
    _ref.read(apiClientProvider).onUnauthorized.listen((_) {
      if (state.status == SessionStatus.signedIn ||
          state.status == SessionStatus.mustChangePassword) {
        _signOutIfReallyUnauthorized();
      }
    });
  }

  final Ref _ref;

  /// Guards the confirming call below from its own 401 re-entering this.
  bool _confirming = false;

  /// Checks a 401 against the server before ending a session over it.
  ///
  /// A phone token is good for two years, so it is worth one extra call to be
  /// sure before discarding it. A single 401 is not proof on its own: a server
  /// restarting behind a proxy, a gateway with no healthy backend yet, or a
  /// half-connected network can all produce one while the token is perfectly
  /// good. Only a second, deliberate 401 from `/auth/me` ends the session.
  ///
  /// Anything else — the call succeeding, the network failing, a 5xx — leaves
  /// the session exactly as it was. The cost of being wrong here is asymmetric:
  /// a stale session self-corrects on the next real 401, while a wrongly
  /// dropped one makes somebody log in again on a building site.
  Future<void> _signOutIfReallyUnauthorized() async {
    if (_confirming) return;
    _confirming = true;
    try {
      _apply(await _repo.me());
    } on ApiException catch (failure) {
      if (failure.isUnauthorized) {
        await signOutLocally();
      }
      // Offline, timeout, 5xx, a proxy answering for the server: keep the
      // session. The token outlives all of these.
    } finally {
      _confirming = false;
    }
  }

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
