import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../global.dart';
import '../../state/session.dart';
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
            const LoginPoster(
              title: 'Every rupee your building costs, in one book.',
              body: 'Plot to plaster. Log the bricks, the cement, the mistri and the maps — '
                  'stage by stage, with the bill attached.',
              points: [
                'Stages you name yourself — plot, foundations, each floor.',
                'Every expense stamped with who logged it.',
                'Share a project as an editor or a viewer.',
              ],
            ),
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
                    Text('Sign in', style: T.h2),
                    const SizedBox(height: 6),
                    Text(
                      'Accounts are issued by your administrator.',
                      style: T.body.copyWith(fontSize: 14, color: T.ink(0.6)),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: T.s4),
                      _LoginError(_error!),
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
                      label: 'Sign in',
                      block: true,
                      busy: _busy,
                      busyLabel: 'Signing in…',
                      onPressed: _submit,
                    ),

                    const SizedBox(height: T.s4),
                    // Which server this build talks to is not obvious on a phone
                    // the way a browser's address bar makes it obvious.
                    Text(
                      kServerUrl,
                      textAlign: TextAlign.center,
                      style: T.body.copyWith(fontSize: 11, color: T.ink(0.4)),
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

/// `.login-poster` — the accent panel that carries the app's promise.
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
        padding: const EdgeInsets.symmetric(horizontal: T.s6, vertical: T.s8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [T.accent, T.accent800],
          ),
          borderRadius: T.brLg,
          boxShadow: T.shadowLg,
        ),
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
            const SizedBox(height: T.s6),
            Text(title, style: T.heading(30, color: T.bg)),
            const SizedBox(height: T.s3),
            Text(
              body,
              style: T.body.copyWith(fontSize: 15, color: T.bg.withValues(alpha: 0.94)),
            ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: T.s6),
              for (final point in points)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: T.s3),
                  padding: const EdgeInsets.only(top: T.s3),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x59FFFFFF))),
                  ),
                  child: Text(
                    point,
                    style: T.body.copyWith(fontSize: 14, color: T.bg.withValues(alpha: 0.94)),
                  ),
                ),
            ],
          ],
        ),
      );
}

/// `.login-error` — a tinted panel with the accent bar down its left edge.
class _LoginError extends StatelessWidget {
  const _LoginError(this.message);

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
