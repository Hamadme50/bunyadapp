import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import 'login_screen.dart' show LoginError;

/// Asking for a reset link.
///
/// The reset itself happens in a browser, from the link in the email — a
/// one-shot secret arriving by mail is what proves the person asking owns the
/// address, and putting the form behind that link means it works the same for
/// somebody on the phone and somebody on the web app.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  /// Carried over from the login screen, so a failed sign-in does not make
  /// anyone type their address a second time.
  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.email ?? '');

  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final address = _email.text.trim();
    if (address.isEmpty || !address.contains('@')) {
      setState(() => _error = 'Enter the email address on your account.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).forgotPassword(address);
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (failure) {
      if (!mounted) return;
      // Only the network can fail here — the server answers the same way for a
      // real account and a stranger's address.
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(T.s3),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconBtn(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => context.goBack(Routes.login),
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
                child: _sent ? _confirmation() : _form(),
              ),
            ],
          ),
        ),
      );

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow(kAppTagline, accent: true),
          const SizedBox(height: T.s2),
          Text('Forgot your password?', style: T.h2),
          const SizedBox(height: 6),
          Text(
            'Give us the email on your account and we will send a link to choose '
            'a new password.',
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
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.go,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: T.s4),
          Btn(
            label: 'Send the link',
            block: true,
            busy: _busy,
            busyLabel: 'Sending…',
            onPressed: _submit,
          ),
          const SizedBox(height: T.s6),
          const Divider(color: T.hairline, height: 1),
          const SizedBox(height: T.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remembered it?',
                style: T.body.copyWith(fontSize: 13, color: T.ink(0.6)),
              ),
              const SizedBox(width: 4),
              Btn(
                label: 'Log in',
                kind: BtnKind.ghost,
                onPressed: _busy ? null : () => context.goBack(Routes.login),
              ),
            ],
          ),
        ],
      );

  /// Deliberately says "if". The server will not tell the app whether the
  /// address is registered, and neither should this screen.
  Widget _confirmation() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Check your email', accent: true),
          const SizedBox(height: T.s2),
          Text('On its way', style: T.h2),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'If '),
                TextSpan(
                  text: _email.text.trim(),
                  style: T.body.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text: ' has a Bunyad account, a link to choose a new password is in '
                      'that inbox now. It works once, and stops working after an hour.',
                ),
              ],
            ),
            style: T.body.copyWith(fontSize: 14, color: T.ink(0.7)),
          ),
          const SizedBox(height: T.s4),
          Text(
            'Nothing there? Look in spam, and check the address above for typos.',
            style: T.body.copyWith(fontSize: 13, color: T.ink(0.5)),
          ),
          const SizedBox(height: T.s6),
          Btn(
            label: 'Back to log in',
            block: true,
            onPressed: () => context.goBack(Routes.login),
          ),
          const SizedBox(height: T.s3),
          Btn(
            label: 'Send it again',
            kind: BtnKind.ghost,
            onPressed: () => setState(() => _sent = false),
          ),
        ],
      );
}
