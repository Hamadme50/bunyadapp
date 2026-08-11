import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import 'login_screen.dart';

/// The first screen the app opens on: create your own account.
///
/// The server signs the new account in as it creates it, so there is no second
/// step — the dashboard is next. Anyone who already has an account takes the
/// link at the bottom instead.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    setState(() {
      _error = null;
      _fieldErrors = {};
    });

    // Caught here rather than at the server, which only ever sees one password.
    if (_password.text != _confirm.text) {
      setState(() => _fieldErrors = {'confirm': 'Those two do not match.'});
      _confirmFocus.requestFocus();
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      // Signed in already — the router's redirect takes it from here.
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = failure.fields ?? {};
        // A field-level message is shown under its box; anything else goes up top.
        _error = _fieldErrors.isEmpty ? failure.message : null;
      });
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
                    Text('Create your account', style: T.h2),
                    const SizedBox(height: 6),
                    Text(
                      'Your projects are yours. Start a build, log what it costs, and share '
                      'it with whoever you choose.',
                      style: T.body.copyWith(fontSize: 14, color: T.ink(0.6)),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: T.s4),
                      LoginError(_error!),
                    ],

                    const SizedBox(height: T.s4),
                    Field(
                      label: 'Full name',
                      error: _fieldErrors['name'],
                      child: BunyadInput(
                        controller: _name,
                        hintText: 'Bilal Ahmed',
                        maxLength: 120,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        invalid: _fieldErrors.containsKey('name'),
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: T.s4),

                    Field(
                      label: 'Email',
                      error: _fieldErrors['email'],
                      child: BunyadInput(
                        controller: _email,
                        focusNode: _emailFocus,
                        hintText: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        invalid: _fieldErrors.containsKey('email'),
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: T.s4),

                    Field(
                      label: 'Password',
                      error: _fieldErrors['password'],
                      child: BunyadInput(
                        controller: _password,
                        focusNode: _passwordFocus,
                        obscureText: _obscure,
                        hintText: 'At least 8 characters',
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        invalid: _fieldErrors.containsKey('password'),
                        onSubmitted: (_) => _confirmFocus.requestFocus(),
                        suffix: IconButton(
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
                    const SizedBox(height: T.s4),

                    Field(
                      label: 'Confirm password',
                      error: _fieldErrors['confirm'],
                      child: BunyadInput(
                        controller: _confirm,
                        focusNode: _confirmFocus,
                        obscureText: _obscure,
                        hintText: 'Type it again',
                        textInputAction: TextInputAction.go,
                        invalid: _fieldErrors.containsKey('confirm'),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),

                    const SizedBox(height: T.s6),
                    Btn(
                      label: 'Create account',
                      block: true,
                      busy: _busy,
                      busyLabel: 'Creating…',
                      onPressed: _submit,
                    ),

                    // The way through for anyone who already has an account.
                    const SizedBox(height: T.s6),
                    const Divider(color: T.hairline, height: 1),
                    const SizedBox(height: T.s4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: T.body.copyWith(fontSize: 13, color: T.ink(0.6)),
                        ),
                        const SizedBox(width: 4),
                        Btn(
                          label: 'Sign in',
                          kind: BtnKind.ghost,
                          onPressed: _busy ? null : () => context.goLogin(),
                        ),
                      ],
                    ),

                    const SizedBox(height: T.s3),
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
