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

/// Create your own account — one tap from the gate, or the link at the
/// bottom of the login screen.
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

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = {};

  /// Permissive on purpose — the server has the final say. This only has to
  /// catch the obvious typo before a round trip.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// The server's own rules for a new account, checked here first so a blank
  /// box or a typo costs no round trip.
  ///
  /// Everything wrong is reported at once rather than one box at a time, and
  /// the first box that needs attention takes the cursor.
  bool _validate() {
    final errors = <String, String>{};

    if (_name.text.trim().isEmpty) {
      errors['name'] = 'Enter your name';
    }

    final email = _email.text.trim();
    if (email.isEmpty) {
      errors['email'] = 'Enter your email';
    } else if (!_emailPattern.hasMatch(email)) {
      errors['email'] = 'That does not look like an email';
    }

    if (_password.text.isEmpty) {
      errors['password'] = 'Choose a password';
    } else if (_password.text.length < 8) {
      // The server checks this too, but only as a whole-form message — under
      // the box it belongs to is the more useful place for it.
      errors['password'] = 'Passwords must be at least 8 characters.';
    }

    if (_confirm.text.isEmpty) {
      errors['confirm'] = 'Type your password again';
    } else if (_password.text != _confirm.text) {
      // Caught here rather than at the server, which only ever sees one password.
      errors['confirm'] = 'Those two do not match.';
    }

    setState(() {
      _error = null;
      _fieldErrors = errors;
    });

    if (errors.isEmpty) return true;

    for (final (field, focus) in [
      ('name', _nameFocus),
      ('email', _emailFocus),
      ('password', _passwordFocus),
      ('confirm', _confirmFocus),
    ]) {
      if (errors.containsKey(field)) {
        focus.requestFocus();
        break;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_validate()) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
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
                        focusNode: _nameFocus,
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
                      label: 'Create Account',
                      block: true,
                      busy: _busy,
                      busyLabel: 'Creating…',
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        // Not block: a full-width button inside a Row gets
                        // unbounded width and lays out to infinity.
                        Btn(
                          label: 'Log in',
                          onPressed: _busy ? null : () => context.goLogin(),
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
