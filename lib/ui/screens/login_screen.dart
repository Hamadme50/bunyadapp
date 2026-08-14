import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import '../widgets/shell.dart';

/// The sign-in screen. Accounts are created by an administrator, never here.
///
/// The web app sets the poster beside the form on a wide screen; on a phone
/// they stack, poster first, with the same words on both.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).signIn(_email.text.trim(), _password.text);
      // The router's redirect takes it from here.
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
      _password.clear();
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(T.s3),
          children: [
            // The gate has already made the pitch — this screen only has to
            // take the details, and offer the way back.
            Align(
              alignment: Alignment.centerLeft,
              child: IconBtn(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => context.goGate(),
              ),
            ),
            const SizedBox(height: T.s3),

            const _LoginBanner(),
            const SizedBox(height: T.s3),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s8),
              decoration: BoxDecoration(
                color: T.raised,
                borderRadius: T.brLg,
                border: Border.all(color: T.hairline),
                boxShadow: T.shadowMd,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Eyebrow(kAppTagline, accent: true),
                    const SizedBox(height: T.s2),
                    Text('Log in', style: T.h2),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back. Pick up where your build left off.',
                      style: T.body.copyWith(fontSize: 14, color: T.ink(0.6)),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: T.s4),
                      LoginError(_error!),
                    ],

                    const SizedBox(height: T.s4),
                    Field(
                      label: 'Email',
                      child: BunyadInput(
                        controller: _email,
                        hintText: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: T.s4),
                    Field(
                      label: 'Password',
                      child: TextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _submit(),
                        style: T.body.copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: T.neutral600,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: T.s4),
                    Btn(
                      label: 'Log in',
                      block: true,
                      busy: _busy,
                      busyLabel: 'Signing in…',
                      onPressed: _submit,
                    ),

                    // Back to joining, for anyone who arrived here by mistake.
                    const SizedBox(height: T.s6),
                    const Divider(color: T.hairline, height: 1),
                    const SizedBox(height: T.s4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New to Bunyad?',
                          style: T.body.copyWith(fontSize: 13, color: T.ink(0.6)),
                        ),
                        const SizedBox(width: 4),
                        Btn(
                          label: 'Join',
                          kind: BtnKind.ghost,
                          onPressed: _busy ? null : () => context.goJoin(),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site photo heading the login page, under the brand's gradient wash.
///
/// Carries no words of its own — the gate said it all — so the wash is lighter
/// than [LoginPoster]'s: this one only has to tint the photo to the brand, not
/// darken it enough to read white type off.
class _LoginBanner extends StatelessWidget {
  const _LoginBanner();

  @override
  Widget build(BuildContext context) => Container(
        // Matches the form card below rather than floating over it — the two
        // read as one stack.
        decoration: BoxDecoration(borderRadius: T.brLg, boxShadow: T.shadowMd),
        child: ClipRRect(
          borderRadius: T.brLg,
          child: AspectRatio(
            // The source is 3:2; cropping to a wider band keeps it a header
            // rather than a half-screen poster.
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/login.jpg', fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        T.accent.withValues(alpha: 0.42),
                        T.accent800.withValues(alpha: 0.62),
                        T.accent900.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// `.login-poster` — the panel that carries the app's promise, the same site
/// photo as the gate behind it.
///
/// Only the password screen still raises one: join and login sit behind the
/// gate, which has already said all this.
class LoginPoster extends StatelessWidget {
  const LoginPoster({
    super.key,
    required this.title,
    required this.body,
    this.points = const [],
  });

  final String title;
  final String body;
  final List<String> points;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: T.brLg, boxShadow: T.shadowLg),
        child: ClipRRect(
          borderRadius: T.brLg,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/site-supervisor.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.2, -0.76),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        T.accent.withValues(alpha: 0.5),
                        T.accent800.withValues(alpha: 0.82),
                        T.accent900.withValues(alpha: 0.93),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(T.s6, 28, T.s6, T.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: T.s4),
                    Text(title, style: T.heading(26, color: T.bg)),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: T.body.copyWith(fontSize: 14, color: T.bg.withValues(alpha: 0.9)),
                    ),
                    if (points.isNotEmpty) ...[
                      const SizedBox(height: T.s4),
                      for (final point in points)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.only(top: 10),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0x52FFFFFF))),
                          ),
                          child: Text(
                            point,
                            style:
                                T.body.copyWith(fontSize: 13, color: T.bg.withValues(alpha: 0.9)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// `.login-error` — a tinted panel with the accent bar down its left edge.
class LoginError extends StatelessWidget {
  const LoginError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 11),
        decoration: BoxDecoration(
          color: T.accent100,
          borderRadius: T.brSm,
          border: Border.all(color: T.accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 18, color: T.accent),
            const SizedBox(width: T.s3),
            Expanded(child: Text(message, style: T.bodySm)),
          ],
        ),
      );
}
